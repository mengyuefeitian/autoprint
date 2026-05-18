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
            destination = uniqueDestination(
                in: directory,
                baseName: "\(baseName)-\(timestamp)",
                pathExtension: pathExtension,
                fileManager: manager
            )
        } else {
            destination = originalDestination
        }

        try manager.moveItem(at: source, to: destination)
        return destination
    }

    private static func uniqueDestination(
        in directory: URL,
        baseName: String,
        pathExtension: String,
        fileManager: FileManager
    ) -> URL {
        var suffix: Int?

        while true {
            let fileName: String
            if let suffix {
                fileName = pathExtension.isEmpty
                    ? "\(baseName)-\(suffix)"
                    : "\(baseName)-\(suffix).\(pathExtension)"
            } else {
                fileName = pathExtension.isEmpty
                    ? baseName
                    : "\(baseName).\(pathExtension)"
            }

            let destination = directory.appendingPathComponent(fileName)
            if !fileManager.fileExists(atPath: destination.path) {
                return destination
            }

            suffix = (suffix ?? 1) + 1
        }
    }
}
