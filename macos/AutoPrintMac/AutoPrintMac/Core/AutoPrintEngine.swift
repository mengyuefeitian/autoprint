import Foundation

final class AutoPrintEngine {
    static let shared = AutoPrintEngine()

    private let scanner: FileScanning
    private let printer: PrintAdapter
    private let stabilityTracker: FileStabilityTracker
    private let logStore: PrintLogStore
    private var timer: DispatchSourceTimer?
    private var isProcessing = false

    init(
        scanner: FileScanning = FileScanner(),
        printer: PrintAdapter = MacPrintAdapter(),
        stabilityTracker: FileStabilityTracker = FileStabilityTracker(stableSeconds: AppConfig.defaultValue.fileStableSeconds),
        logStore: PrintLogStore = .shared
    ) {
        self.scanner = scanner
        self.printer = printer
        self.stabilityTracker = stabilityTracker
        self.logStore = logStore
    }

    func start() {
        stop()
        logStore.append("AutoPrint engine started")
        scheduleTimer()
        Task { await runCurrentConfiguration() }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        logStore.append("AutoPrint engine stopped")
    }

    func processOnce(config: AppConfig, now: Date = Date()) async throws {
        guard config.autoPrintEnabled else {
            logStore.append("Auto print skipped: automatic printing is paused", createdAt: now)
            return
        }

        guard !config.printerName.isEmpty else {
            logStore.append("Auto print skipped: no printer selected", createdAt: now)
            return
        }

        guard config.watchFolders.contains(where: \.enabled) else {
            logStore.append("Auto print skipped: no enabled watch folders", createdAt: now)
            return
        }

        try recoverLegacyFailedFiles(config: config, now: now)

        let files = try scanner.scan(config: config)
        logStore.append("Scanned \(config.watchFolders.filter(\.enabled).count) folder(s), found \(files.count) file(s)", createdAt: now)

        for file in files {
            guard stabilityTracker.isStable(
                url: file.url,
                size: file.size,
                modifiedAt: file.modifiedAt,
                now: now
            ) else {
                logStore.append("Waiting for file to become stable: \(file.fileName)", createdAt: now)
                continue
            }

            try await printAndMove(file: file, config: config, now: now)
        }
    }

    private func scheduleTimer() {
        let interval = max(TimeInterval(AppConfigStore.shared.config.scanIntervalSeconds), 5)
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            Task { await self?.runCurrentConfiguration() }
        }
        timer.resume()
        self.timer = timer
        logStore.append("AutoPrint scan interval: \(Int(interval)) seconds")
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

    private func printAndMove(file: DiscoveredFile, config: AppConfig, now: Date) async throws {
        let root = watchRoot(for: file.url, config: config)
        let printedDirectory = root.appendingPathComponent(config.printedFolderName)

        var lastError: Error?
        let attempts = max(config.maxRetries, 0) + 1

        for attemptIndex in 0..<attempts {
            do {
                try await printer.print(
                    file: file.url,
                    printerName: config.printerName,
                    printSettings: config.printSettings,
                    timeoutSeconds: 120
                )
                let moved = try DestinationMover.move(file.url, into: printedDirectory)
                logStore.append("Printed \(file.fileName) -> \(moved.path)", createdAt: now)
                return
            } catch {
                lastError = error
                logStore.append(
                    "Print attempt \(attemptIndex + 1)/\(attempts) failed for \(file.fileName): \(error.localizedDescription)",
                    createdAt: now
                )
            }
        }

        logStore.append(
            "Print failed; kept \(file.fileName) in the watch folder for retry. Last error: \(lastError?.localizedDescription ?? "Unknown error")",
            createdAt: now
        )
    }

    private func recoverLegacyFailedFiles(config: AppConfig, now: Date) throws {
        let manager = FileManager.default

        for folder in config.watchFolders where folder.enabled {
            let root = URL(fileURLWithPath: folder.path).standardizedFileURL
            let failedDirectory = root.appendingPathComponent(config.failedFolderName).standardizedFileURL
            var isDirectory: ObjCBool = false

            guard manager.fileExists(atPath: failedDirectory.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            let files = try manager.contentsOfDirectory(
                at: failedDirectory,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey]
            )

            for file in files {
                let values = try file.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
                if values.isDirectory == true || values.isHidden == true { continue }
                if file.lastPathComponent.hasPrefix("~$") { continue }

                let moved = try DestinationMover.move(file, into: root)
                logStore.append("Recovered legacy failed file for retry: \(moved.lastPathComponent)", createdAt: now)
            }
        }
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
