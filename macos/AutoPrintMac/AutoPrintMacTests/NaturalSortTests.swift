import XCTest
@testable import AutoPrintMac

final class NaturalSortTests: XCTestCase {
    func testSortsNumberedNamesNaturally() {
        let names = ["10.pdf", "2.pdf", "1.pdf"]
        XCTAssertEqual(names.sorted(by: naturalLessThan), ["1.pdf", "2.pdf", "10.pdf"])
    }
}
