import Foundation

final class MacPrintAdapter: PrintAdapter {
    func print(file: URL, printerName: String, timeoutSeconds: Int = 120) async throws {
        let fileExtension = file.pathExtension.lowercased()

        switch fileExtension {
        case "pdf", "png", "jpg", "jpeg", "tif", "tiff", "heic":
            try await run("/usr/bin/lp", arguments: ["-d", printerName, file.path], timeoutSeconds: timeoutSeconds)
        case "doc", "docx", "xls", "xlsx", "ppt", "pptx":
            try await printWithLibreOffice(file: file, printerName: printerName, timeoutSeconds: timeoutSeconds)
        default:
            throw PrintAdapterError.unsupportedType(fileExtension)
        }
    }

    private func printWithLibreOffice(file: URL, printerName: String, timeoutSeconds: Int) async throws {
        let candidates = [
            "/Applications/LibreOffice.app/Contents/MacOS/soffice",
            "/opt/homebrew/bin/libreoffice",
            "/usr/local/bin/libreoffice"
        ]

        guard let command = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw PrintAdapterError.commandFailed("LibreOffice is not installed or not executable")
        }

        try await run(command, arguments: ["--headless", "--pt", printerName, file.path], timeoutSeconds: timeoutSeconds)
    }

    private func run(_ launchPath: String, arguments: [String], timeoutSeconds: Int) async throws {
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

        try process.run()
        try await waitForExit(process, timeoutSeconds: timeoutSeconds)

        guard process.terminationStatus == 0 else {
            let errorMessage = String(data: errorOutput.data, encoding: .utf8)?
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
