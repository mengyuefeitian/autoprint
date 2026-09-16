import XCTest
@testable import AutoPrintMac

final class CUPSJobQueueWaiterTests: XCTestCase {
    func testReturnsTrueAssoonAsJobLeavesTheQueue() async {
        var queuedCheckCount = 0
        var sleepCallCount = 0

        let completed = await CUPSJobQueueWaiter.waitForCompletion(
            jobID: "Office_Printer-1",
            pollInterval: 2,
            timeoutSeconds: 10,
            isJobQueued: { _ in
                queuedCheckCount += 1
                return queuedCheckCount < 3
            },
            sleep: { _ in sleepCallCount += 1 }
        )

        XCTAssertTrue(completed, "waiter reports completion once the job leaves the queue")
        XCTAssertEqual(queuedCheckCount, 3, "polls until the job is no longer queued")
        XCTAssertEqual(sleepCallCount, 2, "sleeps between polls but not after the final successful check")
    }

    func testReturnsFalseWhenJobIsStillQueuedAfterTimeout() async {
        var sleepCallCount = 0

        let completed = await CUPSJobQueueWaiter.waitForCompletion(
            jobID: "Office_Printer-2",
            pollInterval: 2,
            timeoutSeconds: 6,
            isJobQueued: { _ in true },
            sleep: { _ in sleepCallCount += 1 }
        )

        XCTAssertFalse(completed, "waiter reports timeout when the job never leaves the queue")
        XCTAssertEqual(sleepCallCount, 3, "polls exactly timeoutSeconds / pollInterval times before giving up")
    }

    func testReturnsTrueImmediatelyWhenJobIsAlreadyNotQueued() async {
        var sleepCallCount = 0

        let completed = await CUPSJobQueueWaiter.waitForCompletion(
            jobID: "Office_Printer-3",
            pollInterval: 2,
            timeoutSeconds: 10,
            isJobQueued: { _ in false },
            sleep: { _ in sleepCallCount += 1 }
        )

        XCTAssertTrue(completed)
        XCTAssertEqual(sleepCallCount, 0, "no need to sleep when the job is already gone from the queue")
    }
}
