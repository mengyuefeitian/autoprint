import Foundation

@main
struct PrintLogStoreManualTests {
    static func main() {
        let suiteName = "PrintLogStoreManualTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let logStore = PrintLogStore(defaults: defaults)
        let now = Date()

        logStore.append("old", createdAt: now.addingTimeInterval(-4 * 24 * 60 * 60))
        logStore.append("recent", createdAt: now)

        expect(logStore.entries.map(\.message) == ["recent"], "logs older than three days are pruned")

        let reloadedStore = PrintLogStore(defaults: defaults)
        expect(reloadedStore.entries.map(\.message) == ["recent"], "logs are persisted across store reloads")

        logStore.removeAll()
        expect(logStore.entries.isEmpty, "logs can be cleared manually")
        expect(PrintLogStore(defaults: defaults).entries.isEmpty, "cleared logs are removed from persistence")

        print("PrintLogStoreManualTests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
