import Foundation

@main
struct PrintLogStoreManualTests {
    static func main() {
        let suiteName = "PrintLogStoreManualTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let logDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

        let logStore = PrintLogStore(defaults: defaults, logDirectory: logDirectory, maxLogFileBytes: 1024)
        let now = Date()

        logStore.append("old", createdAt: now.addingTimeInterval(-4 * 24 * 60 * 60))
        logStore.append("recent", createdAt: now)

        expect(logStore.entries.map(\.message) == ["recent"], "logs older than three days are pruned")
        let detailedLog = (try? String(contentsOf: logStore.logFileURL, encoding: .utf8)) ?? ""
        expect(!detailedLog.contains("old"), "detailed log prunes entries older than 24 hours")
        expect(detailedLog.contains("recent"), "detailed log keeps recent entries")

        let reloadedStore = PrintLogStore(defaults: defaults, logDirectory: logDirectory, maxLogFileBytes: 1024)
        expect(reloadedStore.entries.map(\.message) == ["recent"], "logs are persisted across store reloads")

        logStore.removeAll()
        expect(logStore.entries.isEmpty, "logs can be cleared manually")
        expect(PrintLogStore(defaults: defaults).entries.isEmpty, "cleared logs are removed from persistence")

        let limitedDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let limitedStore = PrintLogStore(defaults: defaults, storageKey: "limited", logDirectory: limitedDirectory, maxLogFileBytes: 180)
        limitedStore.append("first-" + String(repeating: "a", count: 120), createdAt: now)
        limitedStore.append("second", createdAt: now)
        let limitedData = (try? Data(contentsOf: limitedStore.logFileURL)) ?? Data()
        let limitedText = String(data: limitedData, encoding: .utf8) ?? ""
        expect(limitedData.count <= 180, "detailed log stays under size cap")
        expect(limitedText.contains("second"), "detailed log keeps newest entries when size capped")

        print("PrintLogStoreManualTests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
