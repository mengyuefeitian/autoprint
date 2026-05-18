import Foundation

struct DiscoveredFile: Equatable {
    let url: URL
    let fileName: String
    let createdAt: Date
    let modifiedAt: Date
    let size: UInt64
}

final class FileScanner {
    func scan(config: AppConfig) throws -> [DiscoveredFile] {
        let manager = FileManager.default
        var files: [DiscoveredFile] = []

        for folder in config.watchFolders where folder.enabled {
            let root = URL(fileURLWithPath: folder.path)
            let printed = root.appendingPathComponent(config.printedFolderName).standardizedFileURL
            let failed = root.appendingPathComponent(config.failedFolderName).standardizedFileURL
            let children = try manager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [
                    .creationDateKey,
                    .contentModificationDateKey,
                    .fileSizeKey,
                    .isDirectoryKey,
                    .isHiddenKey
                ]
            )

            for url in children {
                let values = try url.resourceValues(forKeys: [
                    .creationDateKey,
                    .contentModificationDateKey,
                    .fileSizeKey,
                    .isDirectoryKey,
                    .isHiddenKey
                ])

                if values.isDirectory == true || values.isHidden == true { continue }
                if isInDirectory(url, directory: printed) || isInDirectory(url, directory: failed) { continue }
                if url.lastPathComponent.hasPrefix("~$") { continue }

                files.append(DiscoveredFile(
                    url: url,
                    fileName: url.lastPathComponent,
                    createdAt: values.creationDate ?? Date.distantPast,
                    modifiedAt: values.contentModificationDate ?? Date.distantPast,
                    size: UInt64(values.fileSize ?? 0)
                ))
            }
        }

        return files.sorted {
            if $0.createdAt == $1.createdAt {
                return naturalLessThan($0.fileName, $1.fileName)
            }
            return $0.createdAt < $1.createdAt
        }
    }

    private func isInDirectory(_ url: URL, directory: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let directoryPath = directory.standardizedFileURL.path
        return path.hasPrefix(directoryPath + "/")
    }
}
