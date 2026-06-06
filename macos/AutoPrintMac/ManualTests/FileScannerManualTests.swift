import Foundation

@main
struct FileScannerManualTests {
    static func main() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let valid = root.appendingPathComponent("valid", isDirectory: true)
        let missing = root.appendingPathComponent("missing", isDirectory: true)
        try manager.createDirectory(at: valid, withIntermediateDirectories: true)

        let file = valid.appendingPathComponent("print-me.pdf")
        try Data("pdf".utf8).write(to: file)

        let config = AppConfig(
            watchFolders: [
                WatchFolder(path: missing.path, enabled: true),
                WatchFolder(path: valid.path, enabled: true)
            ],
            printerName: "Office Printer",
            printSettings: .defaultValue,
            scanIntervalSeconds: 30,
            fileStableSeconds: 10,
            maxRetries: 3,
            printedFolderName: "printed",
            failedFolderName: "failed",
            launchAtLogin: false,
            autoPrintEnabled: true
        )

        let defaults = UserDefaults(suiteName: "FileScannerManualTests.\(UUID().uuidString)")!
        let logStore = PrintLogStore(defaults: defaults)

        let files = try FileScanner(logStore: logStore).scan(config: config)
        expect(files.map(\.fileName) == ["print-me.pdf"], "bad watch folders do not block valid folders")
        expect(
            logStore.entries.contains { $0.message.contains("Watch folder skipped:") && $0.message.contains(missing.path) },
            "bad watch folders are logged"
        )

        print("FileScannerManualTests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
