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
    case noPrintLogsYet
    case printers
    case printerCapabilityMessage
    case pdfFiles
    case pdfCapabilityMessage
    case images
    case imagesCapabilityMessage
    case officeDocuments
    case officeCapabilityMessage
    case seconds
}

enum L10n {
    static func text(_ key: L10nKey, language: AppLanguage) -> String {
        switch (key, language) {
        case (.status, .chinese): return "状态"
        case (.status, .english): return "Status"
        case (.settings, .chinese): return "设置"
        case (.settings, .english): return "Settings"
        case (.logs, .chinese): return "日志"
        case (.logs, .english): return "Logs"
        case (.capabilities, .chinese): return "能力检测"
        case (.capabilities, .english): return "Capabilities"
        case (.running, .chinese): return "运行中"
        case (.running, .english): return "Running"
        case (.paused, .chinese): return "已暂停"
        case (.paused, .english): return "Paused"
        case (.automaticPrintingEnabled, .chinese): return "自动打印已启用。"
        case (.automaticPrintingEnabled, .english): return "Automatic printing is enabled."
        case (.automaticPrintingPaused, .chinese): return "自动打印已暂停。"
        case (.automaticPrintingPaused, .english): return "Automatic printing is paused."
        case (.printer, .chinese): return "打印机"
        case (.printer, .english): return "Printer"
        case (.defaultPrinter, .chinese): return "默认打印机"
        case (.defaultPrinter, .english): return "Default printer"
        case (.watchFolders, .chinese): return "监听目录"
        case (.watchFolders, .english): return "Watch folders"
        case (.scanInterval, .chinese): return "扫描间隔"
        case (.scanInterval, .english): return "Scan interval"
        case (.automaticPrinting, .chinese): return "自动打印"
        case (.automaticPrinting, .english): return "Automatic printing"
        case (.stableWait, .chinese): return "文件稳定等待"
        case (.stableWait, .english): return "Stable wait"
        case (.retries, .chinese): return "重试次数"
        case (.retries, .english): return "Retries"
        case (.language, .chinese): return "语言"
        case (.language, .english): return "Language"
        case (.version, .chinese): return "版本"
        case (.version, .english): return "Version"
        case (.noPrintLogsYet, .chinese): return "暂无打印日志。"
        case (.noPrintLogsYet, .english): return "No print logs yet."
        case (.printers, .chinese): return "打印机"
        case (.printers, .english): return "Printers"
        case (.printerCapabilityMessage, .chinese): return "选择打印机后，应用会使用配置的打印机名称提交任务。"
        case (.printerCapabilityMessage, .english): return "Uses macOS printer selection and the configured printer name when available."
        case (.pdfFiles, .chinese): return "PDF 文件"
        case (.pdfFiles, .english): return "PDF files"
        case (.pdfCapabilityMessage, .chinese): return "PDF 通过 macOS 打印适配器提交。"
        case (.pdfCapabilityMessage, .english): return "PDF printing is supported through the macOS print adapter."
        case (.images, .chinese): return "图片"
        case (.images, .english): return "Images"
        case (.imagesCapabilityMessage, .chinese): return "常见图片文件可以提交到 macOS 打印系统。"
        case (.imagesCapabilityMessage, .english): return "Common image files can be sent to the macOS print system."
        case (.officeDocuments, .chinese): return "Office 文档"
        case (.officeDocuments, .english): return "Office documents"
        case (.officeCapabilityMessage, .chinese): return "Office 格式需要本机安装可打印对应文件的应用。"
        case (.officeCapabilityMessage, .english): return "Office formats may require an installed app that can print them on this Mac."
        case (.seconds, .chinese): return "秒"
        case (.seconds, .english): return "seconds"
        }
    }
}
