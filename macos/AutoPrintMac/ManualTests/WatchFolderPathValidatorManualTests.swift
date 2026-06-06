import Foundation

@main
struct WatchFolderPathValidatorManualTests {
    static func main() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let mountedLikeDirectory = root.appendingPathComponent("Volumes/home/三年级/autoprint", isDirectory: true)
        let file = root.appendingPathComponent("not-a-folder.txt")

        try manager.createDirectory(at: mountedLikeDirectory, withIntermediateDirectories: true)
        try Data("file".utf8).write(to: file)

        expect(WatchFolderPathValidator.acceptsDirectory(url: mountedLikeDirectory), "mounted network-like directory is accepted")
        expect(!WatchFolderPathValidator.acceptsDirectory(url: file), "plain files are rejected")

        print("WatchFolderPathValidatorManualTests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
