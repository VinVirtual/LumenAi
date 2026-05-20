import XCTest
@testable import Reminders

final class NLParserTests: XCTestCase {
    private let parser = NLParser()

    func testParsesPriorityBangs() {
        let d = parser.parse("Pay rent !!")
        XCTAssertEqual(d.priority, 3)
        XCTAssertTrue(d.title.lowercased().contains("pay rent"))
    }

    func testParsesDailyRecurrence() {
        let d = parser.parse("drink water daily")
        XCTAssertEqual(d.recurrence?.freq, .daily)
        XCTAssertFalse(d.title.lowercased().contains("daily"))
    }

    func testParsesTomorrow() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2025-01-01T10:00:00Z"))
        let d = parser.parse("Call mom tomorrow", calendar: Calendar(identifier: .gregorian), now: now)
        XCTAssertNotNil(d.dueAt)
    }
}
