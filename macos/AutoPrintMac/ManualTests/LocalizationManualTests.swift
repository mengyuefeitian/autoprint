import Foundation

@main
struct LocalizationManualTests {
    static func main() {
        expect(AppLanguage.chinese.displayName == "简体中文", "Chinese display name")
        expect(AppLanguage.english.displayName == "English", "English display name")
        expect(AppLanguage(rawValue: "zh-Hans") == .chinese, "Chinese raw value")
        expect(AppLanguage(rawValue: "en") == .english, "English raw value")

        expect(L10n.text(.settings, language: .chinese) == "设置", "Chinese settings label")
        expect(L10n.text(.settings, language: .english) == "Settings", "English settings label")
        expect(L10n.text(.language, language: .chinese) == "语言", "Chinese language label")
        expect(L10n.text(.version, language: .english) == "Version", "English version label")

        expect(AppVersion.display(shortVersion: "0.1.1", build: "2") == "0.1.1 (2)", "Version display")
        expect(AppVersion.display(shortVersion: "0.1.1", build: "") == "0.1.1", "Version display without build")

        print("LocalizationManualTests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
