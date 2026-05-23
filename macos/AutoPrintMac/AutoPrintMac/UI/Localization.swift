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
        case (.openSettings, .chinese): return "打开设置"
        case (.openSettings, .english): return "Open Settings"
        case (.pausePrinting, .chinese): return "暂停打印"
        case (.pausePrinting, .english): return "Pause Printing"
        case (.resumePrinting, .chinese): return "恢复打印"
        case (.resumePrinting, .english): return "Resume Printing"
        case (.quit, .chinese): return "退出"
        case (.quit, .english): return "Quit"
        case (.addWatchFolder, .chinese): return "添加监听目录"
        case (.addWatchFolder, .english): return "Add watch folder"
        case (.chooseFolder, .chinese): return "选择目录"
        case (.chooseFolder, .english): return "Choose folder"
        case (.manualWatchFolderPath, .chinese): return "手动输入目录路径"
        case (.manualWatchFolderPath, .english): return "Manual folder path"
        case (.addPath, .chinese): return "添加路径"
        case (.addPath, .english): return "Add path"
        case (.remove, .chinese): return "移除"
        case (.remove, .english): return "Remove"
        case (.noWatchFolders, .chinese): return "还没有监听目录。"
        case (.noWatchFolders, .english): return "No watch folders yet."
        case (.selectedPrinter, .chinese): return "选择打印机"
        case (.selectedPrinter, .english): return "Select printer"
        case (.noPrintersFound, .chinese): return "未找到系统打印机"
        case (.noPrintersFound, .english): return "No system printers found"
        case (.refresh, .chinese): return "刷新"
        case (.refresh, .english): return "Refresh"
        case (.printSettings, .chinese): return "打印设置"
        case (.printSettings, .english): return "Print settings"
        case (.colorMode, .chinese): return "颜色模式"
        case (.colorMode, .english): return "Color mode"
        case (.color, .chinese): return "彩色"
        case (.color, .english): return "Color"
        case (.grayscale, .chinese): return "黑白/灰度"
        case (.grayscale, .english): return "Black and white"
        case (.printerDefault, .chinese): return "跟随打印机默认"
        case (.printerDefault, .english): return "Printer default"
        case (.paperSize, .chinese): return "纸张大小"
        case (.paperSize, .english): return "Paper size"
        case (.a4, .chinese): return "A4"
        case (.a4, .english): return "A4"
        case (.scaleMode, .chinese): return "页面适配"
        case (.scaleMode, .english): return "Page scaling"
        case (.fitToPage, .chinese): return "适应纸张大小"
        case (.fitToPage, .english): return "Fit to page"
        case (.actualSize, .chinese): return "实际大小"
        case (.actualSize, .english): return "Actual size"
        case (.printSettingsHint, .chinese): return "PDF 和图片会优先使用这些设置；Office 文档需要 LibreOffice headless 转成临时 PDF 后打印。"
        case (.printSettingsHint, .english): return "PDF and images use these settings first; Office documents require LibreOffice headless conversion before printing."
        case (.noPrintLogsYet, .chinese): return "暂无打印日志。"
        case (.noPrintLogsYet, .english): return "No print logs yet."
        case (.copyLogs, .chinese): return "复制日志"
        case (.copyLogs, .english): return "Copy logs"
        case (.clearLogs, .chinese): return "清除日志"
        case (.clearLogs, .english): return "Clear logs"
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
        case (.officeCapabilityMessage, .chinese): return "Office 文档通过 LibreOffice headless 无界面转 PDF 后打印，不调用 Word/Pages，避免权限弹窗卡住队列。"
        case (.officeCapabilityMessage, .english): return "Office documents are converted to PDF with LibreOffice headless, without calling Word or Pages."
        case (.seconds, .chinese): return "秒"
        case (.seconds, .english): return "seconds"
        }
    }
}
