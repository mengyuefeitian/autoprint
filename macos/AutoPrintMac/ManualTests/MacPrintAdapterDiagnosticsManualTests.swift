import Foundation

@main
struct MacPrintAdapterDiagnosticsManualTests {
    static func main() async {
        let missingFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        let printer = MacPrintAdapter()

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
