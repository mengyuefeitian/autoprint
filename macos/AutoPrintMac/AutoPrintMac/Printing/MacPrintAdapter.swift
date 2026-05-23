import Foundation

final class MacPrintAdapter: PrintAdapter {
    func print(file: URL, printerName: String, timeoutSeconds: Int = 120) async throws {
        try await print(file: file, printerName: printerName, printSettings: .defaultValue, timeoutSeconds: timeoutSeconds)
    }

    func print(file: URL, printerName: String, printSettings: PrintSettings, timeoutSeconds: Int = 120) async throws {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw PrintAdapterError.commandFailed("Print source file does not exist: \(file.path)")
        }

        let cupsPrinterName = MacPrinterNameResolver.resolve(printerName)
        let fileExtension = file.pathExtension.lowercased()

        switch fileExtension {
        case "pdf", "png", "jpg", "jpeg", "tif", "tiff", "heic":
            try await printPDFOrImage(file: file, printerName: cupsPrinterName, printSettings: printSettings, timeoutSeconds: timeoutSeconds)
        case "doc", "docx", "xls", "xlsx", "ppt", "pptx":
            try await printOfficeDocument(file: file, printerName: cupsPrinterName, printSettings: printSettings, timeoutSeconds: timeoutSeconds)
        default:
            throw PrintAdapterError.unsupportedType(fileExtension)
        }
    }

    private func printPDFOrImage(file: URL, printerName: String, printSettings: PrintSettings, timeoutSeconds: Int) async throws {
        let spool = try MacPrintSpooler.copyToLocalSpool(file)
        defer { try? FileManager.default.removeItem(at: spool.directory) }
        try await run(
            "/usr/bin/lp",
            arguments: ["-d", printerName] + MacPrintOptions.lpOptions(for: printSettings) + [spool.file.path],
            sourceFile: file,
            submittedFile: spool.file,
            timeoutSeconds: timeoutSeconds
        )
    }

    private func printOfficeDocument(file: URL, printerName: String, printSettings: PrintSettings, timeoutSeconds: Int) async throws {
        guard let app = MacOfficePrintAppDetector.selectApp(forExtension: file.pathExtension.lowercased()) else {
            throw PrintAdapterError.commandFailed("No supported Office print app found. Install Microsoft Word, Pages, or LibreOffice.")
        }

        let converted = try MacPrintSpooler.pdfDestination(for: file)
        defer { try? FileManager.default.removeItem(at: converted.directory) }

        switch app {
        case .microsoftWord:
            try await runAppleScript(
                MacOfficePrintScripts.microsoftWordExportPDF(filePath: file.path, outputPath: converted.file.path),
                sourceFile: file,
                timeoutSeconds: timeoutSeconds
            )
        case .pages:
            try await runAppleScript(
                MacOfficePrintScripts.pagesExportPDF(filePath: file.path, outputPath: converted.file.path),
                sourceFile: file,
                timeoutSeconds: timeoutSeconds
            )
        case .libreOffice(let command):
            try await run(
                command,
                arguments: ["--headless", "--convert-to", "pdf", "--outdir", converted.directory.path, file.path],
                sourceFile: file,
                submittedFile: file,
                timeoutSeconds: timeoutSeconds
            )
        }

        guard FileManager.default.fileExists(atPath: converted.file.path) else {
            throw PrintAdapterError.commandFailed("Office document conversion did not create PDF: \(converted.file.path)")
        }

        try await printPDFOrImage(file: converted.file, printerName: printerName, printSettings: printSettings, timeoutSeconds: timeoutSeconds)
    }

    private func runAppleScript(_ script: String, sourceFile: URL, timeoutSeconds: Int) async throws {
        try await run(
            "/usr/bin/osascript",
            arguments: ["-e", script],
            sourceFile: sourceFile,
            submittedFile: sourceFile,
            timeoutSeconds: timeoutSeconds
        )
    }

    private func run(_ launchPath: String, arguments: [String], sourceFile: URL?, submittedFile: URL?, timeoutSeconds: Int) async throws {
        if let sourceFile, !FileManager.default.fileExists(atPath: sourceFile.path) {
            throw PrintAdapterError.commandFailed("Print source file does not exist: \(sourceFile.path)")
        }
        if let submittedFile, !FileManager.default.fileExists(atPath: submittedFile.path) {
            throw PrintAdapterError.commandFailed("Print submitted file does not exist: \(submittedFile.path)")
        }

        let process = Process()
        let errorPipe = Pipe()
        let outputPipe = Pipe()
        let errorOutput = ProcessOutputBuffer()
        let standardOutput = ProcessOutputBuffer()

        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardError = errorPipe
        process.standardOutput = outputPipe

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                errorOutput.append(data)
            }
        }
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                standardOutput.append(data)
            }
        }
        defer {
            errorPipe.fileHandleForReading.readabilityHandler = nil
            outputPipe.fileHandleForReading.readabilityHandler = nil
            try? errorPipe.fileHandleForReading.close()
            try? outputPipe.fileHandleForReading.close()
        }

        do {
            try process.run()
        } catch {
            throw PrintAdapterError.commandFailed("Failed to start print command \(launchPath): \(error.localizedDescription)")
        }
        try await waitForExit(process, timeoutSeconds: timeoutSeconds)

        guard process.terminationStatus == 0 else {
            let errorMessage = String(data: errorOutput.data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let outputMessage = String(data: standardOutput.data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let sourceDetail = sourceFile.map { " source=\($0.path) exists=\(FileManager.default.fileExists(atPath: $0.path))" } ?? ""
            let submittedDetail = submittedFile.map { " submitted=\($0.path) exists=\(FileManager.default.fileExists(atPath: $0.path))" } ?? ""
            let stderrDetail = errorMessage.flatMap { $0.isEmpty ? nil : " stderr=\($0)" } ?? ""
            let stdoutDetail = outputMessage.flatMap { $0.isEmpty ? nil : " stdout=\($0)" } ?? ""
            let command = ([launchPath] + arguments).joined(separator: " ")
            throw PrintAdapterError.commandFailed(
                "\(launchPath) exited with status \(process.terminationStatus).\(sourceDetail)\(submittedDetail) command=\(command)\(stderrDetail)\(stdoutDetail)"
            )
        }
    }

    private func waitForExit(_ process: Process, timeoutSeconds: Int) async throws {
        let timeout = max(timeoutSeconds, 0)

        try await withCheckedThrowingContinuation { continuation in
            let completion = ProcessCompletion(continuation: continuation)
            let timeoutWork = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
                completion.finish(.failure(PrintAdapterError.timedOut))
            }

            process.terminationHandler = { _ in
                timeoutWork.cancel()
                completion.finish(.success(()))
            }
            if !process.isRunning {
                timeoutWork.cancel()
                completion.finish(.success(()))
            }

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .seconds(timeout), execute: timeoutWork)
        }
    }
}

struct MacPrintSpoolFile {
    let directory: URL
    let file: URL
}

enum MacPrintSpooler {
    static func copyToLocalSpool(_ source: URL) throws -> MacPrintSpoolFile {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory
            .appendingPathComponent("AutoPrintSpool", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)

        let extensionPart = source.pathExtension.isEmpty ? "" : ".\(source.pathExtension)"
        let destination = directory.appendingPathComponent("document\(extensionPart)")
        try manager.copyItem(at: source, to: destination)
        return MacPrintSpoolFile(directory: directory, file: destination)
    }

    static func pdfDestination(for source: URL) throws -> MacPrintSpoolFile {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory
            .appendingPathComponent("AutoPrintConvertedPDF", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        return MacPrintSpoolFile(directory: directory, file: directory.appendingPathComponent("document.pdf"))
    }
}

enum MacOfficePrintApp: Equatable {
    case microsoftWord
    case pages
    case libreOffice(String)
}

enum MacOfficePrintAppDetector {
    static func selectApp(forExtension fileExtension: String) -> MacOfficePrintApp? {
        selectApp(
            forExtension: fileExtension,
            fileExists: FileManager.default.fileExists(atPath:),
            executableExists: FileManager.default.isExecutableFile(atPath:)
        )
    }

    static func selectApp(
        forExtension fileExtension: String,
        fileExists: (String) -> Bool,
        executableExists: (String) -> Bool
    ) -> MacOfficePrintApp? {
        if ["doc", "docx"].contains(fileExtension), fileExists("/Applications/Microsoft Word.app") {
            return .microsoftWord
        }

        if ["doc", "docx"].contains(fileExtension), fileExists("/Applications/Pages.app") {
            return .pages
        }

        let libreOfficeCandidates = [
            "/Applications/LibreOffice.app/Contents/MacOS/soffice",
            "/opt/homebrew/bin/libreoffice",
            "/usr/local/bin/libreoffice"
        ]

        if let command = libreOfficeCandidates.first(where: executableExists) {
            return .libreOffice(command)
        }

        return nil
    }
}

enum MacOfficePrintScripts {
    static func microsoftWordExportPDF(filePath: String, outputPath: String) -> String {
        """
        set docPath to "\(appleScriptEscaped(filePath))"
        set pdfPath to "\(appleScriptEscaped(outputPath))"
        tell application "Microsoft Word"
            open POSIX file docPath
            set printedDocument to active document
            save as printedDocument file format format PDF file name pdfPath
            close printedDocument saving no
        end tell
        """
    }

    static func pagesExportPDF(filePath: String, outputPath: String) -> String {
        """
        set docPath to "\(appleScriptEscaped(filePath))"
        set pdfPath to "\(appleScriptEscaped(outputPath))"
        tell application "Pages"
            open POSIX file docPath
            set printedDocument to front document
            export printedDocument to POSIX file pdfPath as PDF
            close printedDocument saving no
        end tell
        """
    }

    private static func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

enum MacPrinterNameResolver {
    static func resolve(_ printerName: String) -> String {
        resolve(printerName, availableQueues: cupsPrinterQueues())
    }

    static func resolve(_ printerName: String, availableQueues: [String]) -> String {
        if availableQueues.contains(printerName) {
            return printerName
        }

        let normalizedPrinterName = normalized(printerName)
        return availableQueues.first { normalized($0) == normalizedPrinterName } ?? printerName
    }

    static func cupsPrinterQueues() -> [String] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lpstat")
        process.arguments = ["-p"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return []
        }

        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output
            .split(separator: "\n")
            .compactMap { line in
                let text = String(line)
                if text.hasPrefix("打印机") {
                    let queue = text
                        .dropFirst("打印机".count)
                        .prefix { isCUPSQueueCharacter($0) }
                    return queue.isEmpty ? nil : String(queue)
                }

                let parts = text.split(separator: " ", maxSplits: 2)
                guard parts.count >= 2, parts[0].lowercased() == "printer" else { return nil }
                return String(parts[1])
            }
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func isCUPSQueueCharacter(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first else {
            return false
        }

        return (65...90).contains(Int(scalar.value))
            || (97...122).contains(Int(scalar.value))
            || (48...57).contains(Int(scalar.value))
            || character == "_"
            || character == "-"
            || character == "."
    }
}

enum MacPrintOptions {
    static func lpOptions(for settings: PrintSettings) -> [String] {
        var options: [String] = []

        switch settings.paperSize {
        case .a4:
            options += ["-o", "media=A4"]
        case .printerDefault:
            break
        }

        switch settings.scaleMode {
        case .fitToPage:
            options += ["-o", "fit-to-page"]
        case .actualSize:
            break
        }

        switch settings.colorMode {
        case .color:
            options += ["-o", "print-color-mode=color"]
        case .grayscale:
            options += ["-o", "print-color-mode=monochrome"]
        case .printerDefault:
            break
        }

        return options
    }
}

private final class ProcessCompletion {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func finish(_ result: Result<Void, Error>) {
        let continuation: CheckedContinuation<Void, Error>?
        lock.lock()
        continuation = self.continuation
        self.continuation = nil
        lock.unlock()

        switch result {
        case .success:
            continuation?.resume()
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }
}

private final class ProcessOutputBuffer {
    private let lock = NSLock()
    private var storage = Data()
    private let limit = 64 * 1024

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }

        guard storage.count < limit else {
            return
        }

        storage.append(data.prefix(limit - storage.count))
    }
}
