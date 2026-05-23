import Combine
import Foundation

struct PrintLogEntry: Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let message: String
}

final class PrintLogStore: ObservableObject {
    static let shared = PrintLogStore()

    @Published private(set) var entries: [PrintLogEntry] = []

    private let limit = 200

    func append(_ message: String, createdAt: Date = Date()) {
        DispatchQueue.main.async {
            self.appendOnMain(message, createdAt: createdAt)
        }
    }

    func removeAll() {
        DispatchQueue.main.async {
            self.entries.removeAll()
        }
    }

    private func appendOnMain(_ message: String, createdAt: Date) {
        entries.append(PrintLogEntry(id: UUID(), createdAt: createdAt, message: message))
        if entries.count > limit {
            entries.removeFirst(entries.count - limit)
        }
    }
}
