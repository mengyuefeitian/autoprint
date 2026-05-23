import Foundation

@main
struct OfficePrintSupportManualTests {
    static func main() {
        let wordApp = MacOfficePrintAppDetector.selectApp(
            forExtension: "docx",
            fileExists: { $0 == "/Applications/Microsoft Word.app" },
            executableExists: { _ in false }
        )
        expect(wordApp == .microsoftWord, "docx uses Microsoft Word when it is installed")

        let pagesApp = MacOfficePrintAppDetector.selectApp(
            forExtension: "docx",
            fileExists: { $0 == "/Applications/Pages.app" },
            executableExists: { _ in false }
        )
        expect(pagesApp == .pages, "docx falls back to Pages when Word is not installed")

        let libreOfficeApp = MacOfficePrintAppDetector.selectApp(
            forExtension: "docx",
            fileExists: { _ in false },
            executableExists: { $0 == "/Applications/LibreOffice.app/Contents/MacOS/soffice" }
        )
        expect(libreOfficeApp == .libreOffice("/Applications/LibreOffice.app/Contents/MacOS/soffice"), "docx falls back to LibreOffice")

        let wordScript = MacOfficePrintScripts.microsoftWordExportPDF(filePath: "/tmp/test.docx", outputPath: "/tmp/test.pdf")
        expect(wordScript.contains("Microsoft Word"), "Word script targets Microsoft Word")
        expect(wordScript.contains("save as"), "Word script exports instead of direct printing")
        expect(wordScript.contains("format PDF"), "Word script exports PDF")
        expect(wordScript.contains("/tmp/test.docx"), "Word script includes source path")
        expect(wordScript.contains("/tmp/test.pdf"), "Word script includes output PDF path")

        let pagesScript = MacOfficePrintScripts.pagesExportPDF(filePath: "/tmp/test.docx", outputPath: "/tmp/test.pdf")
        expect(pagesScript.contains("Pages"), "Pages script targets Pages")
        expect(pagesScript.contains("export"), "Pages script exports instead of direct printing")
        expect(pagesScript.contains("as PDF"), "Pages script exports PDF")

        print("OfficePrintSupportManualTests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
