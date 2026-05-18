import XCTest
@testable import AutoPrintMac

final class PrintQueueTests: XCTestCase {
    func testReplaceQueuedFilesAddsNewFilesOnceInScanOrder() {
        let queue = PrintQueue()
        let createdAt = Date(timeIntervalSince1970: 10)
        let later = Date(timeIntervalSince1970: 20)
        let file10 = discoveredFile("10.pdf", createdAt: createdAt)
        let file2 = discoveredFile("2.pdf", createdAt: createdAt)
        let fileLater = discoveredFile("later.pdf", createdAt: later)

        queue.replaceQueuedFiles([file10, fileLater, file2])
        queue.replaceQueuedFiles([file2, file10])

        XCTAssertEqual(queue.tasks.map(\.file.fileName), ["2.pdf", "10.pdf", "later.pdf"])
        XCTAssertEqual(queue.tasks.map(\.state), [.queued, .queued, .queued])
    }

    func testReplaceQueuedFilesDeduplicatesDuplicateURLsInSingleScan() {
        let queue = PrintQueue()
        let createdAt = Date(timeIntervalSince1970: 10)
        let duplicate = discoveredFile("duplicate.pdf", createdAt: createdAt)

        queue.replaceQueuedFiles([duplicate, duplicate])

        XCTAssertEqual(queue.tasks.map(\.file.url), [duplicate.url])
    }

    func testNextTaskReturnsFirstQueuedTask() {
        let queue = PrintQueue()
        let first = discoveredFile("1.pdf", createdAt: Date(timeIntervalSince1970: 10))
        let second = discoveredFile("2.pdf", createdAt: Date(timeIntervalSince1970: 20))

        queue.replaceQueuedFiles([second, first])

        XCTAssertEqual(queue.nextTask()?.file.fileName, "1.pdf")
    }

    private func discoveredFile(_ name: String, createdAt: Date) -> DiscoveredFile {
        DiscoveredFile(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            fileName: name,
            createdAt: createdAt,
            modifiedAt: createdAt,
            size: 100
        )
    }
}
