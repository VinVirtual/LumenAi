import XCTest
@testable import Core

final class LumenSmokeTests: XCTestCase {
    func testAppConfigFallsBackGracefully() {
        // The default load will use the app bundle; we only verify the
        // singleton initializes without crashing in a unit test environment.
        let config = AppConfig.shared
        XCTAssertFalse(config.appGroup.isEmpty)
    }
}
