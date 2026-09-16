import XCTest
@testable import AutoPrintMac

final class CUPSJobIDParserTests: XCTestCase {
    func testParsesJobIDFromStandardLPOutput() {
        let output = "request id is Office_Printer-42 (1 file(s))\n"
        XCTAssertEqual(CUPSJobIDParser.parse(output), "Office_Printer-42")
    }

    func testParsesJobIDWhenOutputHasSurroundingWhitespace() {
        let output = "  request id is Office_Printer-7 (1 file(s))  "
        XCTAssertEqual(CUPSJobIDParser.parse(output), "Office_Printer-7")
    }

    func testReturnsNilForUnrecognizedOutput() {
        XCTAssertNil(CUPSJobIDParser.parse("lp: unable to print file"))
    }

    func testReturnsNilForEmptyOutput() {
        XCTAssertNil(CUPSJobIDParser.parse(""))
    }
}
