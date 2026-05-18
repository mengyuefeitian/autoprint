import Foundation

enum AppVersion {
    static var current: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return display(shortVersion: shortVersion, build: build)
    }

    static func display(shortVersion: String, build: String) -> String {
        if build.isEmpty {
            return shortVersion
        }

        return "\(shortVersion) (\(build))"
    }
}
