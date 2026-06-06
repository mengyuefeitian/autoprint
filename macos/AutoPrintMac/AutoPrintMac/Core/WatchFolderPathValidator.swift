import Foundation

enum WatchFolderPathValidator {
    static func acceptsDirectory(url: URL, fileManager: FileManager = .default) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
           values.isDirectory == true {
            return true
        }

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return true
        }

        let standardizedURL = url.standardizedFileURL
        if standardizedURL.path != url.path {
            return acceptsDirectory(url: standardizedURL, fileManager: fileManager)
        }

        return false
    }
}
