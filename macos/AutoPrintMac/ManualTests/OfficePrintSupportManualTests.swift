import Foundation

@main
struct OfficePrintSupportManualTests {
    static func main() throws {
        let bundledLibreOfficeApp = MacOfficePrintAppDetector.selectApp(
            forExtension: "docx",
            settings: OfficePrintSettings(useLibreOfficeHeadless: true, useMicrosoftWord: false, usePages: false),
            bundledExecutable: "/Applications/AutoPrint.app/Contents/Resources/LibreOffice.app/Contents/MacOS/soffice",
            fileExists: { _ in false },
            executableExists: { $0 == "/Applications/AutoPrint.app/Contents/Resources/LibreOffice.app/Contents/MacOS/soffice" }
        )
        expect(bundledLibreOfficeApp == .libreOffice("/Applications/AutoPrint.app/Contents/Resources/LibreOffice.app/Contents/MacOS/soffice"), "bundled LibreOffice is preferred")

        let installedLibreOfficeApp = MacOfficePrintAppDetector.selectApp(
            forExtension: "docx",
            settings: OfficePrintSettings(useLibreOfficeHeadless: true, useMicrosoftWord: false, usePages: false),
            bundledExecutable: nil,
            fileExists: { _ in false },
            executableExists: { $0 == "/Applications/LibreOffice.app/Contents/MacOS/soffice" }
        )
        expect(installedLibreOfficeApp == .libreOffice("/Applications/LibreOffice.app/Contents/MacOS/soffice"), "installed LibreOffice is used when bundled LibreOffice is absent")

        let wordOnlyApp = MacOfficePrintAppDetector.selectApp(
            forExtension: "docx",
            settings: OfficePrintSettings(useLibreOfficeHeadless: false, useMicrosoftWord: false, usePages: false),
            bundledExecutable: nil,
            fileExists: { $0 == "/Applications/Microsoft Word.app" },
            executableExists: { _ in false }
        )
        expect(wordOnlyApp == nil, "Word is disabled by default")

        let enabledWordApp = MacOfficePrintAppDetector.selectApp(
            forExtension: "docx",
            settings: OfficePrintSettings(useLibreOfficeHeadless: false, useMicrosoftWord: true, usePages: false),
            bundledExecutable: nil,
            fileExists: { $0 == "/Applications/Microsoft Word.app" },
            executableExists: { _ in false }
        )
        expect(enabledWordApp == .microsoftWord, "Word can be explicitly enabled")

        let pagesApp = MacOfficePrintAppDetector.selectApp(
            forExtension: "docx",
            settings: OfficePrintSettings(useLibreOfficeHeadless: false, useMicrosoftWord: false, usePages: false),
            bundledExecutable: nil,
            fileExists: { $0 == "/Applications/Pages.app" },
            executableExists: { _ in false }
        )
        expect(pagesApp == nil, "Pages is disabled by default")

        let libreOfficeApp = MacOfficePrintAppDetector.selectApp(
            forExtension: "docx",
            settings: OfficePrintSettings(useLibreOfficeHeadless: true, useMicrosoftWord: false, usePages: false),
            bundledExecutable: nil,
            fileExists: { _ in false },
            executableExists: { $0 == "/Applications/LibreOffice.app/Contents/MacOS/soffice" }
        )
        expect(libreOfficeApp == .libreOffice("/Applications/LibreOffice.app/Contents/MacOS/soffice"), "docx falls back to LibreOffice")

        let localVendorLibreOffice = "macos/AutoPrintMac/Resources/Vendor/LibreOffice.app/Contents/MacOS/soffice"
        if FileManager.default.isExecutableFile(atPath: localVendorLibreOffice) {
            let vendorApp = MacOfficePrintAppDetector.selectApp(
                forExtension: "docx",
                settings: OfficePrintSettings(useLibreOfficeHeadless: true, useMicrosoftWord: false, usePages: false),
                bundledExecutable: localVendorLibreOffice,
                fileExists: { _ in false },
                executableExists: FileManager.default.isExecutableFile(atPath:)
            )
            expect(vendorApp == .libreOffice(localVendorLibreOffice), "local bundled LibreOffice executable is usable")
        }

        let wordPDF = try MacPrintSpooler.pdfDestination(for: URL(fileURLWithPath: "/tmp/source.docx"), app: .microsoftWord)
        expect(wordPDF.file.path == "/tmp/source.pdf", "Word conversion writes PDF next to source document")

        let libreOfficePDF = try MacPrintSpooler.pdfDestination(for: URL(fileURLWithPath: "/tmp/source.docx"), app: .libreOffice("/tmp/soffice"))
        expect(libreOfficePDF.file.lastPathComponent == "document.pdf", "LibreOffice conversion uses temporary PDF destination")

        print("OfficePrintSupportManualTests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
