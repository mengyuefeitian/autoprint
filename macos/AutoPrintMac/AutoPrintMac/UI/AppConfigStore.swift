import Foundation

final class AppConfigStore: ObservableObject {
    static let shared = AppConfigStore()

    @Published var config: AppConfig {
        didSet {
            save(config)
        }
    }

    private let defaults: UserDefaults
    private let key = "AutoPrintMac.appConfig"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.config = Self.load(from: defaults, key: key)
    }

    func toggleAutoPrintEnabled() {
        config.autoPrintEnabled.toggle()
    }

    private static func load(from defaults: UserDefaults, key: String) -> AppConfig {
        guard let data = defaults.data(forKey: key) else {
            return .defaultValue
        }

        do {
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            return .defaultValue
        }
    }

    private func save(_ config: AppConfig) {
        guard let data = try? JSONEncoder().encode(config) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
