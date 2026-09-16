import XCTest
@testable import AutoPrintMac

final class SparkleLocalizationFolderTests: XCTestCase {
    func testChineseMapsToSparkleZhCNFolder() {
        XCTAssertEqual(SparkleLocalizationFolder.folderName(for: .chinese), "zh_CN")
    }

    func testEnglishHasNoOverrideFolder() {
        XCTAssertNil(SparkleLocalizationFolder.folderName(for: .english), "English uses Sparkle's own base/English localization directly")
    }
}
