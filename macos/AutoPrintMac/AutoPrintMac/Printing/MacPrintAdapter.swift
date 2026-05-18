import Foundation

final class MacPrintAdapter: PrintAdapter {
    func print(file: URL, printerName: String, timeoutSeconds _: Int = 120) async throws {
        let fileExtension = file.pathExtension.lowercased()

        switch fileExtension {
        case "pdf", "png", "jpg", "jpeg", "tif", "tiff", "heic":
            try await run("/usr/bin/lp", arguments: ["-d", printerName, file.path])
        case "doc", "docx", "xls", "xlsx", "ppt", "pptx":
            try await printWithLibreOffice(file: file, printerName: printerName)
        default:
            throw PrintAdapterError.unsupportedType(fileExtension)
        }
    }

    private func printWithLibreOffice(file: URL, printerName: String) async throws {
        let candidates = [
            "/Applications/LibreOffice.app/Contents/MacOS/soffice",
            "/opt/homebrew/bin/libreoffice",
            "/usr/local/bin/libreoffice"
        ]

        guard let command = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw PrintAdapterError.commandFailed("LibreOffice is not installed or not executable")
        }

        try await run(command, arguments: ["--headless", "--pt", printerName, file.path])
    }

    private func run(_ launchPath: String, arguments: [String]) async throws {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let detail: String
            if let errorMessage, !errorMessage.isEmpty {
                detail = ": \(errorMessage)"
            } else {
                detail = ""
            }
            throw PrintAdapterError.commandFailed("\(launchPath) exited with status \(process.terminationStatus)\(detail)")
        }
    }
}
