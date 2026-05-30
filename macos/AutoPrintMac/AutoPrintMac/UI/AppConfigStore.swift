import Foundation

extension Notification.Name {
    static let appConfigDidChange = Notification.Name("AutoPrintMac.appConfigDidChange")
}

final class AppConfigStore: ObservableObject {
    static let shared = AppConfigStore()

    @Published var config: AppConfig {
        didSet {
            save(config)
            NotificationCenter.default.post(name: .appConfigDidChange, object: self)
        }
    }

    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: languageKey)
        }
    }

    private let defaults: UserDefaults
    private let key = "AutoPrintMac.appConfig"
    private let languageKey = "AutoPrintMac.language"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.config = Self.load(from: defaults, key: key)
        self.language = Self.loadLanguage(from: defaults, key: languageKey)
    }

    func toggleAutoPrintEnabled() {
        config.autoPrintEnabled.toggle()
    }

    func selectPrinter(named printerName: String) {
        config.printerName = printerName
    }

    func addWatchFolder(path: String) {
        let normalizedPath = (path as NSString).standardizingPath
        guard !normalizedPath.isEmpty,
              !config.watchFolders.contains(where: { $0.path == normalizedPath }) else {
            return
        }

        config.watchFolders.append(WatchFolder(path: normalizedPath, enabled: true))
    }

    func removeWatchFolder(path: String) {
        config.watchFolders.removeAll { $0.path == path }
    }

    func setWatchFolder(path: String, enabled: Bool) {
        guard let index = config.watchFolders.firstIndex(where: { $0.path == path }) else {
            return
        }

        config.watchFolders[index].enabled = enabled
    }

    private static func load(from defaults: UserDefaults, key: String) -> AppConfig {
        guard let data = defaults.data(forKey: key) else {
            return .defaultValue
        }

        do {
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            if let migrated = try? JSONDecoder().decode(LegacyAppConfig.self, from: data) {
                return migrated.currentConfig
            }
            return .defaultValue
        }
    }

    private static func loadLanguage(from defaults: UserDefaults, key: String) -> AppLanguage {
        guard let rawValue = defaults.string(forKey: key),
              let language = AppLanguage(rawValue: rawValue) else {
            return .chinese
        }

        return language
    }

    private func save(_ config: AppConfig) {
        guard let data = try? JSONEncoder().encode(config) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}

private struct LegacyAppConfig: Codable {
    var watchFolders: [WatchFolder]
    var printerName: String
    var scanIntervalSeconds: Int
    var fileStableSeconds: Int
    var maxRetries: Int
    var printedFolderName: String
    var failedFolderName: String
    var launchAtLogin: Bool
    var autoPrintEnabled: Bool

    var currentConfig: AppConfig {
        AppConfig(
            watchFolders: watchFolders,
            printerName: printerName,
            printSettings: .defaultValue,
            scanIntervalSeconds: scanIntervalSeconds,
            fileStableSeconds: fileStableSeconds,
            maxRetries: maxRetries,
            printedFolderName: printedFolderName,
            failedFolderName: failedFolderName,
            launchAtLogin: launchAtLogin,
            autoPrintEnabled: autoPrintEnabled,
            scanSchedule: .defaultValue
        )
    }
}
