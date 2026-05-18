import Foundation

struct WatchFolder: Codable, Equatable, Identifiable {
    var id: String { path }
    var path: String
    var enabled: Bool
}

struct AppConfig: Codable, Equatable {
    var watchFolders: [WatchFolder]
    var printerName: String
    var scanIntervalSeconds: Int
    var fileStableSeconds: Int
    var maxRetries: Int
    var printedFolderName: String
    var failedFolderName: String
    var launchAtLogin: Bool
    var autoPrintEnabled: Bool

    static let defaultValue = AppConfig(
        watchFolders: [],
        printerName: "",
        scanIntervalSeconds: 30,
        fileStableSeconds: 10,
        maxRetries: 3,
        printedFolderName: "printed",
        failedFolderName: "failed",
        launchAtLogin: false,
        autoPrintEnabled: true
    )
}
