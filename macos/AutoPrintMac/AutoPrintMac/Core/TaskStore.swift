import Foundation

enum DestinationMover {
    static func move(_ source: URL, into directory: URL, now: Date = Date()) throws -> URL {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)

        let originalDestination = directory.appendingPathComponent(source.lastPathComponent)
        let destination: URL

        if manager.fileExists(atPath: originalDestination.path) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            let timestamp = formatter.string(from: now)
            let baseName = source.deletingPathExtension().lastPathComponent
            let pathExtension = source.pathExtension
            let fileName = pathExtension.isEmpty
                ? "\(baseName)-\(timestamp)"
                : "\(baseName)-\(timestamp).\(pathExtension)"
            destination = directory.appendingPathComponent(fileName)
        } else {
            destination = originalDestination
        }

        try manager.moveItem(at: source, to: destination)
        return destination
    }
}
