import AppKit

final class PrinterDetector {
    func printers() -> [PrinterInfo] {
        NSPrinter.printerNames.map {
            PrinterInfo(name: $0, isAvailable: true, reason: nil)
        }
    }

    func find(name: String) -> PrinterInfo {
        if NSPrinter.printerNames.contains(name) {
            return PrinterInfo(name: name, isAvailable: true, reason: nil)
        }

        return PrinterInfo(name: name, isAvailable: false, reason: "Printer was not found")
    }
}
