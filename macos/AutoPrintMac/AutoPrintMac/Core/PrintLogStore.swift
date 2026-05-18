import Foundation

struct PrintLogEntry: Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let message: String
}

final class PrintLogStore {
    private(set) var entries: [PrintLogEntry] = []

    func append(_ message: String, createdAt: Date = Date()) {
        entries.append(PrintLogEntry(id: UUID(), createdAt: createdAt, message: message))
    }

    func removeAll() {
        entries.removeAll()
    }
}
