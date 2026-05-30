import Foundation

@main
struct SettingsBehaviorManualTests {
    static func main() {
        let defaults = UserDefaults(suiteName: "AutoPrintSettingsBehaviorManualTests")!
        defaults.removePersistentDomain(forName: "AutoPrintSettingsBehaviorManualTests")

        let store = AppConfigStore(defaults: defaults)
        store.selectPrinter(named: "Office Printer")
        expect(store.config.printerName == "Office Printer", "selected printer is saved in config")

        store.addWatchFolder(path: "/tmp/PrintInbox")
        expect(store.config.watchFolders == [WatchFolder(path: "/tmp/PrintInbox", enabled: true)], "watch folder is added enabled")

        store.addWatchFolder(path: "/tmp/PrintInbox")
        expect(store.config.watchFolders.count == 1, "duplicate watch folder is ignored")

        store.setWatchFolder(path: "/tmp/PrintInbox", enabled: false)
        expect(store.config.watchFolders.first?.enabled == false, "watch folder enabled flag changes")

        store.removeWatchFolder(path: "/tmp/PrintInbox")
        expect(store.config.watchFolders.isEmpty, "watch folder is removed")
        expect(store.config.scanSchedule == .defaultValue, "scan schedule defaults to unrestricted scanning")

        store.config.scanSchedule = ScanSchedule(enabled: true, startMinuteOfDay: 8 * 60, endMinuteOfDay: 18 * 60)
        let reloaded = AppConfigStore(defaults: defaults)
        expect(reloaded.config.scanSchedule.enabled == true, "scan schedule enabled flag is persisted")
        expect(reloaded.config.scanSchedule.startMinuteOfDay == 8 * 60, "scan schedule start time is persisted")
        expect(reloaded.config.scanSchedule.endMinuteOfDay == 18 * 60, "scan schedule end time is persisted")

        expect(L10n.text(.openSettings, language: .chinese) == "打开设置", "Chinese menu settings title")
        expect(L10n.text(.pausePrinting, language: .english) == "Pause Printing", "English pause title")
        expect(L10n.text(.resumePrinting, language: .chinese) == "恢复打印", "Chinese resume title")
        expect(L10n.text(.quit, language: .chinese) == "退出", "Chinese quit title")

        print("SettingsBehaviorManualTests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
