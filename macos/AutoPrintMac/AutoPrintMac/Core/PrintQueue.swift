import Foundation

enum PrintTaskState: String, Codable {
    case pending = "Pending"
    case stabilizing = "Stabilizing"
    case queued = "Queued"
    case printing = "Printing"
    case submitted = "Submitted"
    case printed = "Printed"
    case retrying = "Retrying"
    case failed = "Failed"
}

struct PrintTask: Identifiable, Equatable {
    let id: UUID
    let file: DiscoveredFile
    var state: PrintTaskState
    var retryCount: Int
    var lastError: String?
}

final class PrintQueue {
    private(set) var tasks: [PrintTask] = []

    func replaceQueuedFiles(_ files: [DiscoveredFile]) {
        let existing = Set(tasks.map { $0.file.url })
        let newTasks = files
            .filter { !existing.contains($0.url) }
            .map { PrintTask(id: UUID(), file: $0, state: .queued, retryCount: 0, lastError: nil) }

        tasks.append(contentsOf: newTasks)
        tasks.sort {
            if $0.file.createdAt == $1.file.createdAt {
                return naturalLessThan($0.file.fileName, $1.file.fileName)
            }
            return $0.file.createdAt < $1.file.createdAt
        }
    }

    func nextTask() -> PrintTask? {
        tasks.first { $0.state == .queued }
    }
}
