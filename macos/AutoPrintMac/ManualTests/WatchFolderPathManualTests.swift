import Foundation

@main
struct WatchFolderPathManualTests {
    static func main() {
        let defaults = UserDefaults(suiteName: "AutoPrintWatchFolderPathManualTests")!
        defaults.removePersistentDomain(forName: "AutoPrintWatchFolderPathManualTests")

        let store = AppConfigStore(defaults: defaults)
        store.addWatchFolder(path: "/tmp/AutoPrint/Nested/Inbox/")
        expect(store.config.watchFolders.first?.path == "/tmp/AutoPrint/Nested/Inbox", "normalizes trailing slash in nested path")

        store.addWatchFolder(path: "~/Documents/AutoPrintInbox")
        expect(store.config.watchFolders.contains { $0.path.hasSuffix("/Documents/AutoPrintInbox") }, "expands home-relative nested path")

        expect(L10n.text(.manualWatchFolderPath, language: .chinese) == "手动输入目录路径", "Chinese manual path label")
        expect(L10n.text(.addPath, language: .english) == "Add path", "English add path label")
        expect(L10n.text(.chooseFolder, language: .chinese) == "选择目录", "Chinese choose folder label")

        print("WatchFolderPathManualTests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
