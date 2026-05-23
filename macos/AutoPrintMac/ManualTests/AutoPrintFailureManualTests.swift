import Foundation

private final class FailingScanner: FileScanning {
    var files: [DiscoveredFile] = []

    func scan(config: AppConfig) throws -> [DiscoveredFile] {
        files
    }
}

private final class FailingPrinter: PrintAdapter {
    struct PrintFailed: LocalizedError {
        var errorDescription: String? { "Simulated printer is offline" }
    }

    private(set) var printAttempts = 0

    func print(file: URL, printerName: String, printSettings: PrintSettings, timeoutSeconds: Int) async throws {
        printAttempts += 1
        throw PrintFailed()
    }
}

@main
struct AutoPrintFailureManualTests {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("retry-me.pdf")
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
            maxRetries: 1,
            printedFolderName: "printed",
            failedFolderName: "failed",
            launchAtLogin: false,
            autoPrintEnabled: true
        )

        let scanner = FailingScanner()
        scanner.files = [discovered]
        let printer = FailingPrinter()
        let logStore = PrintLogStore()
        logStore.removeAll()
        let engine = AutoPrintEngine(scanner: scanner, printer: printer, logStore: logStore)

        try await engine.processOnce(config: config, now: Date(timeIntervalSince1970: 25))
        expect(printer.printAttempts == 0, "first sight waits for stable window")

        try await engine.processOnce(config: config, now: Date(timeIntervalSince1970: 36))
        expect(printer.printAttempts == 2, "configured retry attempts are used")
        expect(FileManager.default.fileExists(atPath: source.path), "failed file stays in the watch folder")
        expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("failed/retry-me.pdf").path), "failed file is not moved to failed folder")

        let messages = logStore.entries.map(\.message).joined(separator: "\n")
        expect(messages.contains("Print attempt 1/2 failed for retry-me.pdf: Simulated printer is offline"), "first failure reason is logged")
        expect(messages.contains("Print failed; kept retry-me.pdf in the watch folder for retry. Last error: Simulated printer is offline"), "final retryable failure is logged")

        print("AutoPrintFailureManualTests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
