import XCTest
@testable import AutoPrintMac

final class DestinationMoveTests: XCTestCase {
    func testMoveCreatesDestinationDirectoryAndMovesFile() throws {
        let root = temporaryDirectory()
        let source = root.appendingPathComponent("source.pdf")
        let destination = root.appendingPathComponent("printed")
        try Data("pdf".utf8).write(to: source)

        let moved = try DestinationMover.move(source, into: destination)

        XCTAssertEqual(moved, destination.appendingPathComponent("source.pdf"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
    }

    func testMoveAppendsUTCTimestampBeforeExtensionWhenDestinationExists() throws {
        let root = temporaryDirectory()
        let source = root.appendingPathComponent("report.final.pdf")
        let destination = root.appendingPathComponent("printed")
        let existing = destination.appendingPathComponent("report.final.pdf")
        let now = Date(timeIntervalSince1970: 1_704_154_845)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("existing".utf8).write(to: existing)
        try Data("new".utf8).write(to: source)

        let moved = try DestinationMover.move(source, into: destination, now: now)

        XCTAssertEqual(moved.lastPathComponent, "report.final-20240102-030405.pdf")
        XCTAssertEqual(try Data(contentsOf: moved), Data("new".utf8))
        XCTAssertEqual(try Data(contentsOf: existing), Data("existing".utf8))
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoPrintMacTests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
