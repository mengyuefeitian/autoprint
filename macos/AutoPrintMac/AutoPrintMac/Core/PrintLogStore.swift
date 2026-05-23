import Combine
import Foundation

struct PrintLogEntry: Identifiable, Equatable, Codable {
    let id: UUID
    let createdAt: Date
    let message: String
}

final class PrintLogStore: ObservableObject {
    static let shared = PrintLogStore()

    @Published private(set) var entries: [PrintLogEntry] = []

    private let limit = 200
    private let retentionInterval: TimeInterval = 3 * 24 * 60 * 60
    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = "AutoPrintMac.printLogs") {
        self.defaults = defaults
        self.storageKey = storageKey
        entries = Self.loadEntries(defaults: defaults, storageKey: storageKey)
        pruneLogs(now: Date())
        saveEntries()
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
            return
        }

        DispatchQueue.main.sync {
            self.entries.removeAll()
            self.saveEntries()
        }
    }

    private func appendOnMain(_ message: String, createdAt: Date) {
        entries.append(PrintLogEntry(id: UUID(), createdAt: createdAt, message: message))
        pruneLogs(now: createdAt)
        saveEntries()
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

    private static func loadEntries(defaults: UserDefaults, storageKey: String) -> [PrintLogEntry] {
        guard let data = defaults.data(forKey: storageKey),
              let entries = try? JSONDecoder().decode([PrintLogEntry].self, from: data) else {
            return []
        }
        return entries
    }
}
