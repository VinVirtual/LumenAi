import XCTest
@testable import Core

final class ReminderTests: XCTestCase {
    func testEntitySnapshotRoundTrip() {
        let entity = ReminderEntity(
            ownerID: UUID(),
            title: "Drink water",
            body: "Stay hydrated",
            dueAt: Date(timeIntervalSince1970: 1_700_000_000),
            priority: 1
        )
        let snap = entity.snapshot()
        XCTAssertEqual(snap.title, "Drink water")
        XCTAssertEqual(snap.body, "Stay hydrated")
        XCTAssertEqual(snap.priority, 1)
    }

    func testApplyHonorsUpdatedAt() {
        let userID = UUID()
        let entity = ReminderEntity(ownerID: userID, title: "Old")
        var snap = entity.snapshot()
        snap.title = "New"
        snap.updatedAt = entity.updatedAt.addingTimeInterval(60)
        entity.apply(snap)
        XCTAssertEqual(entity.title, "New")

        // Older updated_at should be ignored.
        snap.title = "Older"
        snap.updatedAt = entity.updatedAt.addingTimeInterval(-1)
        entity.apply(snap)
        XCTAssertEqual(entity.title, "New")
    }
}
