import XCTest
@testable import DesignSystem

final class ThemeTests: XCTestCase {
    func testBundledThemesHaveStableIDs() {
        let ids = Theme.bundled.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(ids.contains("aurora"))
    }

    func testThemeJSONRoundTrip() throws {
        let original = Theme.aurora
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Theme.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
