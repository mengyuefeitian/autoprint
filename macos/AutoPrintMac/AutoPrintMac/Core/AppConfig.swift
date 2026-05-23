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
    var officeSettings: OfficePrintSettings

    static let defaultValue = PrintSettings(
        colorMode: .color,
        paperSize: .a4,
        scaleMode: .fitToPage,
        officeSettings: .defaultValue
    )

    init(
        colorMode: PrintColorMode,
        paperSize: PrintPaperSize,
        scaleMode: PrintScaleMode,
        officeSettings: OfficePrintSettings = .defaultValue
    ) {
        self.colorMode = colorMode
        self.paperSize = paperSize
        self.scaleMode = scaleMode
        self.officeSettings = officeSettings
    }

    private enum CodingKeys: String, CodingKey {
        case colorMode
        case paperSize
        case scaleMode
        case officeSettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        colorMode = try container.decode(PrintColorMode.self, forKey: .colorMode)
        paperSize = try container.decode(PrintPaperSize.self, forKey: .paperSize)
        scaleMode = try container.decode(PrintScaleMode.self, forKey: .scaleMode)
        officeSettings = try container.decodeIfPresent(OfficePrintSettings.self, forKey: .officeSettings) ?? .defaultValue
    }
}

struct OfficePrintSettings: Codable, Equatable {
    var useLibreOfficeHeadless: Bool
    var useMicrosoftWord: Bool
    var usePages: Bool

    static let defaultValue = OfficePrintSettings(
        useLibreOfficeHeadless: false,
        useMicrosoftWord: false,
        usePages: false
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
