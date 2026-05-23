import AppKit

final class PrinterDetector {
    func printers() -> [PrinterInfo] {
        let cupsPrinters = MacPrinterNameResolver.cupsPrinterQueues()
        let names = cupsPrinters.isEmpty ? NSPrinter.printerNames : cupsPrinters
        return names.map {
            PrinterInfo(name: $0, isAvailable: true, reason: nil)
        }
    }

    func find(name: String) -> PrinterInfo {
        if printers().contains(where: { $0.name == name }) {
            return PrinterInfo(name: name, isAvailable: true, reason: nil)
        }

        return PrinterInfo(name: name, isAvailable: false, reason: "Printer was not found")
    }
}
