import Foundation

final class AutoPrintEngine {
    static let shared = AutoPrintEngine()

    private let scanner: FileScanning
    private let printer: PrintAdapter
    private let stabilityTracker: FileStabilityTracker
    private let logStore: PrintLogStore
    private var timer: Timer?
    private var isProcessing = false

    init(
        scanner: FileScanning = FileScanner(),
        printer: PrintAdapter = MacPrintAdapter(),
        stabilityTracker: FileStabilityTracker = FileStabilityTracker(stableSeconds: AppConfig.defaultValue.fileStableSeconds),
        logStore: PrintLogStore = PrintLogStore()
    ) {
        self.scanner = scanner
        self.printer = printer
        self.stabilityTracker = stabilityTracker
        self.logStore = logStore
    }

    func start() {
        stop()
        scheduleTimer()
        Task { await runCurrentConfiguration() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func processOnce(config: AppConfig, now: Date = Date()) async throws {
        guard config.autoPrintEnabled, !config.printerName.isEmpty else {
            return
        }

        let files = try scanner.scan(config: config)
        for file in files {
            guard stabilityTracker.isStable(
                url: file.url,
                size: file.size,
                modifiedAt: file.modifiedAt,
                now: now
            ) else {
                continue
            }

            try await printAndMove(file: file, config: config)
        }
    }

    private func scheduleTimer() {
        let interval = max(TimeInterval(AppConfigStore.shared.config.scanIntervalSeconds), 5)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.runCurrentConfiguration() }
        }
    }

    private func runCurrentConfiguration() async {
        if isProcessing {
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await processOnce(config: AppConfigStore.shared.config)
        } catch {
            logStore.append("Auto print scan failed: \(error.localizedDescription)")
        }
    }

    private func printAndMove(file: DiscoveredFile, config: AppConfig) async throws {
        let root = watchRoot(for: file.url, config: config)
        let printedDirectory = root.appendingPathComponent(config.printedFolderName)
        let failedDirectory = root.appendingPathComponent(config.failedFolderName)

        var lastError: Error?
        let attempts = max(config.maxRetries, 0) + 1

        for _ in 0..<attempts {
            do {
                try await printer.print(
                    file: file.url,
                    printerName: config.printerName,
                    printSettings: config.printSettings,
                    timeoutSeconds: 120
                )
                let moved = try DestinationMover.move(file.url, into: printedDirectory)
                logStore.append("Printed \(file.fileName) -> \(moved.path)")
                return
            } catch {
                lastError = error
            }
        }

        let moved = try DestinationMover.move(file.url, into: failedDirectory)
        logStore.append("Failed \(file.fileName) -> \(moved.path): \(lastError?.localizedDescription ?? "Unknown error")")
    }

    private func watchRoot(for fileURL: URL, config: AppConfig) -> URL {
        let filePath = fileURL.standardizedFileURL.path
        let enabledRoots = config.watchFolders
            .filter(\.enabled)
            .map { URL(fileURLWithPath: $0.path).standardizedFileURL }
            .sorted { $0.path.count > $1.path.count }

        return enabledRoots.first { filePath.hasPrefix($0.path + "/") }
            ?? fileURL.deletingLastPathComponent()
    }
}
