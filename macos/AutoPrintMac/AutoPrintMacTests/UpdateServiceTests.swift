import XCTest
@testable import AutoPrintMac

@MainActor
private final class FakeUpdater: UpdaterConfigurable {
    var automaticallyChecksForUpdates = false
    var updateCheckInterval: TimeInterval = 0
}

final class UpdateServiceTests: XCTestCase {
    func testDesiredConfigurationChecksAutomaticallyOnceDaily() {
        let config = UpdateService.desiredConfiguration
        XCTAssertTrue(config.automaticallyChecksForUpdates, "auto-update must be on by default")
        XCTAssertEqual(config.updateCheckInterval, 86400, "check interval must be once a day")
    }

    @MainActor
    func testConfigureAppliesDesiredConfigurationToAnyUpdater() {
        let fake = FakeUpdater()
        UpdateService.configure(fake)
        XCTAssertTrue(fake.automaticallyChecksForUpdates)
        XCTAssertEqual(fake.updateCheckInterval, 86400)
    }
}
