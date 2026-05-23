import Foundation

private final class AlwaysFailingPrinter: PrintAdapter {
    private(set) var printAttempts = 0

    func print(file: URL, printerName: String, printSettings: PrintSettings, timeoutSeconds: Int) async throws {
        printAttempts += 1
        throw PrintAdapterError.commandFailed("Simulated print failure")
    }
}

@main
struct FailedFolderRecoveryManualTests {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let failed = root.appendingPathComponent("failed")
        try FileManager.default.createDirectory(at: failed, withIntermediateDirectories: true)
        let legacyFailedFile = failed.appendingPathComponent("legacy.pdf")
        try Data("pdf".utf8).write(to: legacyFailedFile)

        let config = AppConfig(
            watchFolders: [WatchFolder(path: root.path, enabled: true)],
            printerName: "Office Printer",
            printSettings: .defaultValue,
            scanIntervalSeconds: 30,
            fileStableSeconds: 10,
            maxRetries: 0,
            printedFolderName: "printed",
            failedFolderName: "failed",
            launchAtLogin: false,
            autoPrintEnabled: true
        )

        let printer = AlwaysFailingPrinter()
        let logStore = PrintLogStore(defaults: UserDefaults(suiteName: "FailedFolderRecoveryManualTests.\(UUID().uuidString)")!)
        let engine = AutoPrintEngine(scanner: FileScanner(), printer: printer, logStore: logStore)
        let recoveredFile = root.appendingPathComponent("legacy.pdf")

        try await engine.processOnce(config: config, now: Date(timeIntervalSince1970: 25))
        expect(FileManager.default.fileExists(atPath: recoveredFile.path), "legacy failed file is moved back to the watch folder")
        expect(!FileManager.default.fileExists(atPath: legacyFailedFile.path), "legacy failed file is removed from failed folder")
        expect(printer.printAttempts == 0, "recovered file still waits for stability on first scan")

        try await engine.processOnce(config: config, now: Date(timeIntervalSince1970: 36))
        expect(printer.printAttempts == 1, "recovered file is retried after stability wait")
        expect(FileManager.default.fileExists(atPath: recoveredFile.path), "failed retry stays in the watch folder")
        expect(!FileManager.default.fileExists(atPath: failed.appendingPathComponent("legacy.pdf").path), "failed retry is not moved back into failed folder")

        let messages = logStore.entries.map(\.message).joined(separator: "\n")
        expect(messages.contains("Recovered legacy failed file for retry: legacy.pdf"), "recovery is logged")
        expect(messages.contains("Print failed; kept legacy.pdf in the watch folder for retry."), "retry failure is logged")

        print("FailedFolderRecoveryManualTests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
