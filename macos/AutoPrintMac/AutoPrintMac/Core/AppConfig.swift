import Foundation

struct WatchFolder: Codable, Equatable, Identifiable {
    var id: String { path }
    var path: String
    var enabled: Bool
}

enum PrintColorMode: String, Codable, CaseIterable, Identifiable {
    case color
    case grayscale
    case printerDefault

    var id: String { rawValue }
}

enum PrintPaperSize: String, Codable, CaseIterable, Identifiable {
    case a4
    case printerDefault

    var id: String { rawValue }
}

enum PrintScaleMode: String, Codable, CaseIterable, Identifiable {
    case fitToPage
    case actualSize

    var id: String { rawValue }
}

struct PrintSettings: Codable, Equatable {
    var colorMode: PrintColorMode
    var paperSize: PrintPaperSize
    var scaleMode: PrintScaleMode

    static let defaultValue = PrintSettings(
        colorMode: .color,
        paperSize: .a4,
        scaleMode: .fitToPage
    )
}

struct AppConfig: Codable, Equatable {
    var watchFolders: [WatchFolder]
    var printerName: String
    var printSettings: PrintSettings
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
        printSettings: .defaultValue,
        scanIntervalSeconds: 30,
        fileStableSeconds: 10,
        maxRetries: 3,
        printedFolderName: "printed",
        failedFolderName: "failed",
        launchAtLogin: false,
        autoPrintEnabled: true
    )
}
