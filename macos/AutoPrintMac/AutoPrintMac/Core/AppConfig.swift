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

struct ScanSchedule: Codable, Equatable {
    var enabled: Bool
    var startMinuteOfDay: Int
    var endMinuteOfDay: Int

    static let defaultValue = ScanSchedule(
        enabled: false,
        startMinuteOfDay: 8 * 60,
        endMinuteOfDay: 20 * 60
    )

    func allowsScanning(at date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled else { return true }

        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        let start = clampedMinute(startMinuteOfDay)
        let end = clampedMinute(endMinuteOfDay)

        if start == end {
            return true
        }

        if start < end {
            return minute >= start && minute < end
        }

        return minute >= start || minute < end
    }

    private func clampedMinute(_ minute: Int) -> Int {
        min(max(minute, 0), (24 * 60) - 1)
    }
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
    var scanSchedule: ScanSchedule

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
        autoPrintEnabled: true,
        scanSchedule: .defaultValue
    )

    init(
        watchFolders: [WatchFolder],
        printerName: String,
        printSettings: PrintSettings,
        scanIntervalSeconds: Int,
        fileStableSeconds: Int,
        maxRetries: Int,
        printedFolderName: String,
        failedFolderName: String,
        launchAtLogin: Bool,
        autoPrintEnabled: Bool,
        scanSchedule: ScanSchedule = .defaultValue
    ) {
        self.watchFolders = watchFolders
        self.printerName = printerName
        self.printSettings = printSettings
        self.scanIntervalSeconds = scanIntervalSeconds
        self.fileStableSeconds = fileStableSeconds
        self.maxRetries = maxRetries
        self.printedFolderName = printedFolderName
        self.failedFolderName = failedFolderName
        self.launchAtLogin = launchAtLogin
        self.autoPrintEnabled = autoPrintEnabled
        self.scanSchedule = scanSchedule
    }

    private enum CodingKeys: String, CodingKey {
        case watchFolders
        case printerName
        case printSettings
        case scanIntervalSeconds
        case fileStableSeconds
        case maxRetries
        case printedFolderName
        case failedFolderName
        case launchAtLogin
        case autoPrintEnabled
        case scanSchedule
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        watchFolders = try container.decode([WatchFolder].self, forKey: .watchFolders)
        printerName = try container.decode(String.self, forKey: .printerName)
        printSettings = try container.decode(PrintSettings.self, forKey: .printSettings)
        scanIntervalSeconds = try container.decode(Int.self, forKey: .scanIntervalSeconds)
        fileStableSeconds = try container.decode(Int.self, forKey: .fileStableSeconds)
        maxRetries = try container.decode(Int.self, forKey: .maxRetries)
        printedFolderName = try container.decode(String.self, forKey: .printedFolderName)
        failedFolderName = try container.decode(String.self, forKey: .failedFolderName)
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        autoPrintEnabled = try container.decode(Bool.self, forKey: .autoPrintEnabled)
        scanSchedule = try container.decodeIfPresent(ScanSchedule.self, forKey: .scanSchedule) ?? .defaultValue
    }
}
