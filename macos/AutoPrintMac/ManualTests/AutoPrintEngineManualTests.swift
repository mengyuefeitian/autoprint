import Foundation

private final class FakeScanner: FileScanning {
    var files: [DiscoveredFile] = []
    private(set) var scanCount = 0

    func scan(config: AppConfig) throws -> [DiscoveredFile] {
        scanCount += 1
        return files
    }
}

private final class FakePrinter: PrintAdapter {
    private(set) var printedFiles: [URL] = []

    func print(file: URL, printerName: String, timeoutSeconds: Int) async throws {
        try await print(file: file, printerName: printerName, printSettings: .defaultValue, timeoutSeconds: timeoutSeconds)
    }

    func print(file: URL, printerName: String, printSettings: PrintSettings, timeoutSeconds: Int) async throws {
        printedFiles.append(file)
    }
}

@main
struct AutoPrintEngineManualTests {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("invoice.pdf")
        try Data("pdf".utf8).write(to: source)

        let discovered = DiscoveredFile(
            url: source,
            fileName: source.lastPathComponent,
            createdAt: Date(timeIntervalSince1970: 10),
            modifiedAt: Date(timeIntervalSince1970: 20),
            size: 3
        )

        let config = AppConfig(
            watchFolders: [WatchFolder(path: root.path, enabled: true)],
            printerName: "Office Printer",
            printSettings: .defaultValue,
            scanIntervalSeconds: 30,
            fileStableSeconds: 10,
            maxRetries: 3,
            printedFolderName: "printed",
            failedFolderName: "failed",
            launchAtLogin: false,
            autoPrintEnabled: true,
            scanSchedule: .defaultValue
        )

        let scanner = FakeScanner()
        scanner.files = [discovered]
        let printer = FakePrinter()
        let engine = AutoPrintEngine(scanner: scanner, printer: printer)

        try await engine.processOnce(config: config, now: Date(timeIntervalSince1970: 25))
        expect(printer.printedFiles.isEmpty, "first sight waits for stable window")
        expect(FileManager.default.fileExists(atPath: source.path), "unstable file remains in watch folder")

        try await engine.processOnce(config: config, now: Date(timeIntervalSince1970: 36))
        expect(printer.printedFiles == [source], "stable file is printed")
        expect(!FileManager.default.fileExists(atPath: source.path), "printed source is moved")
        expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("printed/invoice.pdf").path), "printed file moves to printed folder")

        var scheduledConfig = config
        scheduledConfig.scanSchedule = ScanSchedule(
            enabled: true,
            startMinuteOfDay: 9 * 60,
            endMinuteOfDay: 17 * 60
        )

        let scheduledScanner = FakeScanner()
        let scheduledPrinter = FakePrinter()
        let scheduledEngine = AutoPrintEngine(scanner: scheduledScanner, printer: scheduledPrinter)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        try await scheduledEngine.processOnce(
            config: scheduledConfig,
            now: Date(timeIntervalSince1970: 20 * 60 * 60),
            calendar: calendar
        )
        expect(scheduledScanner.scanCount == 0, "outside scan schedule does not scan folders")
        expect(scheduledPrinter.printedFiles.isEmpty, "outside scan schedule does not print")

        try await scheduledEngine.processOnce(
            config: scheduledConfig,
            now: Date(timeIntervalSince1970: 10 * 60 * 60),
            calendar: calendar
        )
        expect(scheduledScanner.scanCount == 1, "inside scan schedule scans folders")

        print("AutoPrintEngineManualTests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
