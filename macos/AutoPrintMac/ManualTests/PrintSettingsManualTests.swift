import Foundation

@main
struct PrintSettingsManualTests {
    static func main() {
        let settings = PrintSettings.defaultValue
        expect(settings.colorMode == .color, "default color mode is color")
        expect(settings.paperSize == .a4, "default paper size is A4")
        expect(settings.scaleMode == .fitToPage, "default scale mode fits to page")

        let options = MacPrintOptions.lpOptions(for: settings)
        expect(options.contains("-o") && options.contains("media=A4"), "A4 media option")
        expect(options.contains("fit-to-page"), "fit-to-page option")
        expect(options.contains("print-color-mode=color"), "color option")

        let grayscale = PrintSettings(colorMode: .grayscale, paperSize: .printerDefault, scaleMode: .actualSize)
        let grayscaleOptions = MacPrintOptions.lpOptions(for: grayscale)
        expect(!grayscaleOptions.contains("media=A4"), "printer default omits A4 media")
        expect(!grayscaleOptions.contains("fit-to-page"), "actual size omits fit-to-page")
        expect(grayscaleOptions.contains("print-color-mode=monochrome"), "grayscale maps to monochrome")

        print("PrintSettingsManualTests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
