import Combine
import Foundation

struct PrintLogEntry: Identifiable, Equatable, Codable {
    let id: UUID
    let createdAt: Date
    let message: String
}

final class PrintLogStore: ObservableObject {
    static let shared = PrintLogStore()
    static let defaultLogFileName = "autoprint.log"

    @Published private(set) var entries: [PrintLogEntry] = []

    private let limit = 200
    private let retentionInterval: TimeInterval = 3 * 24 * 60 * 60
    private let fileRetentionInterval: TimeInterval
    private let maxLogFileBytes: Int
    private let defaults: UserDefaults
    private let storageKey: String
    let logDirectory: URL
    let logFileURL: URL

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "AutoPrintMac.printLogs",
        logDirectory: URL = PrintLogStore.defaultLogDirectory(),
        fileRetentionInterval: TimeInterval = 24 * 60 * 60,
        maxLogFileBytes: Int = 10 * 1024 * 1024
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.logDirectory = logDirectory
        self.logFileURL = logDirectory.appendingPathComponent(Self.defaultLogFileName)
        self.fileRetentionInterval = fileRetentionInterval
        self.maxLogFileBytes = maxLogFileBytes
        entries = Self.loadEntries(defaults: defaults, storageKey: storageKey)
        pruneLogs(now: Date())
        saveEntries()
        pruneDetailedLogFile(now: Date())
    }

    func append(_ message: String, createdAt: Date = Date()) {
        if Thread.isMainThread {
            appendOnMain(message, createdAt: createdAt)
            return
        }

        DispatchQueue.main.sync {
            self.appendOnMain(message, createdAt: createdAt)
        }
    }

    func removeAll() {
        if Thread.isMainThread {
            entries.removeAll()
            saveEntries()
            removeDetailedLogFile()
            return
        }

        DispatchQueue.main.sync {
            self.entries.removeAll()
            self.saveEntries()
            self.removeDetailedLogFile()
        }
    }

    private func appendOnMain(_ message: String, createdAt: Date) {
        entries.append(PrintLogEntry(id: UUID(), createdAt: createdAt, message: message))
        pruneLogs(now: createdAt)
        saveEntries()
        appendDetailedLog(message, createdAt: createdAt)
    }

    private func pruneLogs(now: Date) {
        let cutoff = now.addingTimeInterval(-retentionInterval)
        entries.removeAll { $0.createdAt < cutoff }
        if entries.count > limit {
            entries.removeFirst(entries.count - limit)
        }
    }

    private func saveEntries() {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }
        defaults.set(data, forKey: storageKey)
        defaults.synchronize()
    }

    private func appendDetailedLog(_ message: String, createdAt: Date) {
        do {
            try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
            var lines = try loadDetailedLogLines(now: createdAt)
            lines.append("\(Self.fileDateFormatter.string(from: createdAt))\t\(message)")
            let data = trimmedDetailedLogData(from: lines)
            try data.write(to: logFileURL, options: [.atomic])
        } catch {
            // The in-app log is still persisted through UserDefaults; avoid recursive logging here.
        }
    }

    private func pruneDetailedLogFile(now: Date) {
        do {
            let lines = try loadDetailedLogLines(now: now)
            guard !lines.isEmpty else {
                try? FileManager.default.removeItem(at: logFileURL)
                return
            }
            try trimmedDetailedLogData(from: lines).write(to: logFileURL, options: [.atomic])
        } catch {
            return
        }
    }

    private func removeDetailedLogFile() {
        try? FileManager.default.removeItem(at: logFileURL)
    }

    private func loadDetailedLogLines(now: Date) throws -> [String] {
        guard FileManager.default.fileExists(atPath: logFileURL.path) else {
            return []
        }

        let text = try String(contentsOf: logFileURL, encoding: .utf8)
        let cutoff = now.addingTimeInterval(-fileRetentionInterval)
        return text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { line in
                guard let timestamp = line.split(separator: "\t", maxSplits: 1).first,
                      let date = Self.fileDateFormatter.date(from: String(timestamp)) else {
                    return false
                }
                return date >= cutoff
            }
    }

    private func trimmedDetailedLogData(from lines: [String]) -> Data {
        var remainingLines = lines
        var data = Data(remainingLines.joined(separator: "\n").utf8)
        if !data.isEmpty {
            data.append(0x0A)
        }

        while data.count > maxLogFileBytes && remainingLines.count > 1 {
            remainingLines.removeFirst()
            data = Data(remainingLines.joined(separator: "\n").utf8)
            data.append(0x0A)
        }

        if data.count > maxLogFileBytes {
            return data.suffix(maxLogFileBytes)
        }

        return data
    }

    private static func loadEntries(defaults: UserDefaults, storageKey: String) -> [PrintLogEntry] {
        guard let data = defaults.data(forKey: storageKey),
              let entries = try? JSONDecoder().decode([PrintLogEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private static var fileDateFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static func defaultLogDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("AutoPrint", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
    }
}
