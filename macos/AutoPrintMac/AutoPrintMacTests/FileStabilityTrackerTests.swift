import XCTest
@testable import AutoPrintMac

final class FileStabilityTrackerTests: XCTestCase {
    func testFileBecomesStableOnlyAfterUnchangedWindow() {
        let tracker = FileStabilityTracker(stableSeconds: 10)
        let url = URL(fileURLWithPath: "/tmp/a.pdf")

        tracker.observe(
            url: url,
            size: 100,
            modifiedAt: Date(timeIntervalSince1970: 10),
            now: Date(timeIntervalSince1970: 20)
        )

        XCTAssertFalse(tracker.isStable(
            url: url,
            size: 100,
            modifiedAt: Date(timeIntervalSince1970: 10),
            now: Date(timeIntervalSince1970: 29)
        ))
        XCTAssertTrue(tracker.isStable(
            url: url,
            size: 100,
            modifiedAt: Date(timeIntervalSince1970: 10),
            now: Date(timeIntervalSince1970: 30)
        ))
    }

    func testChangedFileResetsStableWindow() {
        let tracker = FileStabilityTracker(stableSeconds: 10)
        let url = URL(fileURLWithPath: "/tmp/a.pdf")

        XCTAssertFalse(tracker.isStable(
            url: url,
            size: 100,
            modifiedAt: Date(timeIntervalSince1970: 10),
            now: Date(timeIntervalSince1970: 20)
        ))
        XCTAssertFalse(tracker.isStable(
            url: url,
            size: 200,
            modifiedAt: Date(timeIntervalSince1970: 15),
            now: Date(timeIntervalSince1970: 25)
        ))
        XCTAssertFalse(tracker.isStable(
            url: url,
            size: 200,
            modifiedAt: Date(timeIntervalSince1970: 15),
            now: Date(timeIntervalSince1970: 34)
        ))
        XCTAssertTrue(tracker.isStable(
            url: url,
            size: 200,
            modifiedAt: Date(timeIntervalSince1970: 15),
            now: Date(timeIntervalSince1970: 35)
        ))
    }
}
