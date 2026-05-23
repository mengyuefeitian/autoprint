import Foundation

@main
struct MacPrintAdapterDiagnosticsManualTests {
    static func main() async {
        let missingFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        let printer = MacPrintAdapter()
        let resolved = MacPrinterNameResolver.resolve(
            "HP Ink Tank Wireless 410 series [EB156E]",
            availableQueues: ["HP_Ink_Tank_Wireless_410_series__EB156E_"]
        )
        expect(resolved == "HP_Ink_Tank_Wireless_410_series__EB156E_", "display printer name resolves to CUPS queue name")
        expect(MacPrinterNameResolver.cupsPrinterQueues().contains("HP_Ink_Tank_Wireless_410_series__EB156E_"), "localized lpstat output exposes CUPS queue names")

        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("中文路径-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        let sourceFile = sourceDirectory.appendingPathComponent("知识点总结.pdf")
        try? Data("pdf".utf8).write(to: sourceFile)
        if FileManager.default.fileExists(atPath: sourceFile.path) {
            do {
                let spool = try MacPrintSpooler.copyToLocalSpool(sourceFile)
                defer { try? FileManager.default.removeItem(at: spool.directory) }
                expect(FileManager.default.fileExists(atPath: spool.file.path), "spooled print file exists")
                expect(spool.file.lastPathComponent == "document.pdf", "spooled print file uses a simple local filename")
                expect(spool.file.path.hasPrefix(FileManager.default.temporaryDirectory.path), "spooled print file is local temp")
            } catch {
                fail("spooling source file should work: \(error.localizedDescription)")
            }
        }

        do {
            try await printer.print(
                file: missingFile,
                printerName: "Any Printer",
                printSettings: .defaultValue,
                timeoutSeconds: 5
            )
            fail("missing file should not be submitted to lp")
        } catch {
            let message = error.localizedDescription
            expect(message.contains("Print source file does not exist"), "missing source file is explained")
            expect(message.contains(missingFile.path), "missing source path is included")
        }

        print("MacPrintAdapterDiagnosticsManualTests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}
