import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }
}

enum L10nKey {
    case status
    case settings
    case logs
    case capabilities
    case running
    case paused
    case automaticPrintingEnabled
    case automaticPrintingPaused
    case printer
    case defaultPrinter
    case watchFolders
    case scanInterval
    case automaticPrinting
    case stableWait
    case retries
    case language
    case version
    case openSettings
    case pausePrinting
    case resumePrinting
    case quit
    case addWatchFolder
    case chooseFolder
    case manualWatchFolderPath
    case addPath
    case remove
    case noWatchFolders
    case selectedPrinter
    case noPrintersFound
    case refresh
    case printSettings
    case colorMode
    case color
    case grayscale
    case printerDefault
    case paperSize
    case a4
    case scaleMode
    case fitToPage
    case actualSize
    case printSettingsHint
    case noPrintLogsYet
    case copyLogs
    case clearLogs
    case printers
    case printerCapabilityMessage
    case pdfFiles
    case pdfCapabilityMessage
    case images
    case imagesCapabilityMessage
    case officeDocuments
    case officeCapabilityMessage
    case seconds
    case scanTimeRange
    case limitScanTimeRange
    case scanStartTime
    case scanEndTime
    case scanTimeRangeHint
    case unrestricted
    case officePrintSettings
    case useLibreOfficeHeadless
    case libreOfficeHeadlessHint
    case downloadLibreOffice
    case useMicrosoftWord
    case microsoftWordHint
    case usePages
    case pagesHint
}

enum L10n {
    static func text(_ key: L10nKey, language: AppLanguage) -> String {
        switch key {
        case .status: return choose("状态", "Status", language)
        case .settings: return choose("设置", "Settings", language)
        case .logs: return choose("日志", "Logs", language)
        case .capabilities: return choose("能力检测", "Capabilities", language)
        case .running: return choose("运行中", "Running", language)
        case .paused: return choose("已暂停", "Paused", language)
        case .automaticPrintingEnabled: return choose("自动打印已启用。", "Automatic printing is enabled.", language)
        case .automaticPrintingPaused: return choose("自动打印已暂停。", "Automatic printing is paused.", language)
        case .printer: return choose("打印机", "Printer", language)
        case .defaultPrinter: return choose("默认打印机", "Default printer", language)
        case .watchFolders: return choose("监听目录", "Watch folders", language)
        case .scanInterval: return choose("扫描间隔", "Scan interval", language)
        case .automaticPrinting: return choose("自动打印", "Automatic printing", language)
        case .stableWait: return choose("文件稳定等待", "Stable wait", language)
        case .retries: return choose("重试次数", "Retries", language)
        case .language: return choose("语言", "Language", language)
        case .version: return choose("版本", "Version", language)
        case .openSettings: return choose("打开设置", "Open Settings", language)
        case .pausePrinting: return choose("暂停打印", "Pause Printing", language)
        case .resumePrinting: return choose("恢复打印", "Resume Printing", language)
        case .quit: return choose("退出", "Quit", language)
        case .addWatchFolder: return choose("添加监听目录", "Add watch folder", language)
        case .chooseFolder: return choose("选择目录", "Choose folder", language)
        case .manualWatchFolderPath: return choose("手动输入目录路径", "Manual folder path", language)
        case .addPath: return choose("添加路径", "Add path", language)
        case .remove: return choose("移除", "Remove", language)
        case .noWatchFolders: return choose("还没有监听目录。", "No watch folders yet.", language)
        case .selectedPrinter: return choose("选择打印机", "Select printer", language)
        case .noPrintersFound: return choose("未找到系统打印机", "No system printers found", language)
        case .refresh: return choose("刷新", "Refresh", language)
        case .printSettings: return choose("打印设置", "Print settings", language)
        case .colorMode: return choose("颜色模式", "Color mode", language)
        case .color: return choose("彩色", "Color", language)
        case .grayscale: return choose("黑白/灰度", "Black and white", language)
        case .printerDefault: return choose("跟随打印机默认", "Printer default", language)
        case .paperSize: return choose("纸张大小", "Paper size", language)
        case .a4: return choose("A4", "A4", language)
        case .scaleMode: return choose("页面适配", "Page scaling", language)
        case .fitToPage: return choose("适应纸张大小", "Fit to page", language)
        case .actualSize: return choose("实际大小", "Actual size", language)
        case .printSettingsHint: return choose("PDF 和图片会优先使用这些设置；Office 文档需要在下方启用一种转换方式。", "PDF and images use these settings first; enable an Office conversion method below for Office documents.", language)
        case .noPrintLogsYet: return choose("暂无打印日志。", "No print logs yet.", language)
        case .copyLogs: return choose("复制日志", "Copy logs", language)
        case .clearLogs: return choose("清除日志", "Clear logs", language)
        case .printers: return choose("打印机", "Printers", language)
        case .printerCapabilityMessage: return choose("选择打印机后，应用会使用配置的打印机名称提交任务。", "Uses macOS printer selection and the configured printer name when available.", language)
        case .pdfFiles: return choose("PDF 文件", "PDF files", language)
        case .pdfCapabilityMessage: return choose("PDF 通过 macOS 打印适配器提交。", "PDF printing is supported through the macOS print adapter.", language)
        case .images: return choose("图片", "Images", language)
        case .imagesCapabilityMessage: return choose("常见图片文件可以提交到 macOS 打印系统。", "Common image files can be sent to the macOS print system.", language)
        case .officeDocuments: return choose("Office 文档", "Office documents", language)
        case .officeCapabilityMessage: return choose("Office 文档默认不打印；可在设置中选择 LibreOffice、Microsoft Word 或 Pages 转 PDF。", "Office documents do not print by default; choose LibreOffice, Microsoft Word, or Pages PDF conversion in settings.", language)
        case .seconds: return choose("秒", "seconds", language)
        case .scanTimeRange: return choose("扫描时间段", "Scan time range", language)
        case .limitScanTimeRange: return choose("仅在指定时间段扫描", "Only scan during the selected time range", language)
        case .scanStartTime: return choose("开始时间", "Start time", language)
        case .scanEndTime: return choose("结束时间", "End time", language)
        case .scanTimeRangeHint: return choose("启用后，应用只会在每天的起止时间段内按照扫描间隔运行；其他时间会跳过扫描。支持跨天时间段。", "When enabled, the app scans at the configured interval only during this daily time range and skips scans outside it. Overnight ranges are supported.", language)
        case .unrestricted: return choose("全天扫描", "All day", language)
        case .officePrintSettings: return choose("Office 文档转换", "Office document conversion", language)
        case .useLibreOfficeHeadless: return choose("使用 LibreOffice 无界面转 PDF", "Use LibreOffice headless PDF conversion", language)
        case .libreOfficeHeadlessHint: return choose("需要用户自行下载安装 LibreOffice；不会打开 Word/Pages，适合自动打印。", "Requires LibreOffice installed by the user; does not open Word or Pages and is best for automatic printing.", language)
        case .downloadLibreOffice: return choose("打开 LibreOffice 下载页面", "Open LibreOffice download page", language)
        case .useMicrosoftWord: return choose("使用本地 Microsoft Word 转 PDF", "Use local Microsoft Word PDF conversion", language)
        case .microsoftWordHint: return choose("首次使用需要允许 AutoPrint 控制 Word；后续通常无需再次授权。PDF 会写入原文档所在目录。", "First use requires allowing AutoPrint to control Word; later runs usually do not ask again. PDFs are written next to the source document.", language)
        case .usePages: return choose("使用 macOS Pages 转 PDF", "Use macOS Pages PDF conversion", language)
        case .pagesHint: return choose("macOS 专有；首次使用需要允许 AutoPrint 控制 Pages。PDF 会写入原文档所在目录。", "macOS only; first use requires allowing AutoPrint to control Pages. PDFs are written next to the source document.", language)
        }
    }

    private static func choose(_ chinese: String, _ english: String, _ language: AppLanguage) -> String {
        language == .chinese ? chinese : english
    }
}
