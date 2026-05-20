import Foundation
import SwiftData

/// Habit / wellness models.
///
/// Public/offline edition: backed entirely by local SwiftData. The
/// `Habit` and `HabitLog` value types are the read-side DTOs the views
/// render; the `@Model` classes below are the writeable store rows.

public struct Habit: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let userID: UUID
    public var title: String
    public var icon: String?
    public var streak: Int
    public var longestStreak: Int
    public var lastDoneAt: Date?
    public let createdAt: Date

    public init(
        id: UUID,
        userID: UUID,
        title: String,
        icon: String?,
        streak: Int,
        longestStreak: Int,
        lastDoneAt: Date?,
        createdAt: Date
    ) {
        self.id = id
        self.userID = userID
        self.title = title
        self.icon = icon
        self.streak = streak
        self.longestStreak = longestStreak
        self.lastDoneAt = lastDoneAt
        self.createdAt = createdAt
    }
}

public struct HabitLog: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let habitID: UUID
    public let userID: UUID
    public let completedOn: Date
    public var note: String?
    public let createdAt: Date
}

public struct MoodEntry: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let userID: UUID
    public var valence: Int
    public var arousal: Int
    public var note: String?
    public let createdAt: Date
}

// MARK: - SwiftData entities

/// SwiftData backing for a single habit. The local-only edition stores
/// these directly; streak math is recomputed from `HabitLogEntity` rows
/// whenever the user toggles "done today" off or on (see
/// `WellnessService`).
@Model
public final class HabitEntity {
    @Attribute(.unique) public var id: UUID
    public var ownerID: UUID
    public var title: String
    public var icon: String?
    public var streak: Int
    public var longestStreak: Int
    public var lastDoneAt: Date?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        ownerID: UUID,
        title: String,
        icon: String? = nil,
        streak: Int = 0,
        longestStreak: Int = 0,
        lastDoneAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.ownerID = ownerID
        self.title = title
        self.icon = icon
        self.streak = streak
        self.longestStreak = longestStreak
        self.lastDoneAt = lastDoneAt
        self.createdAt = createdAt
    }
}

/// One row per "I did this habit on this calendar day". Day stored as
/// `Calendar.startOfDay(for:)` so a unique-per-day check is just a
/// straight equality test.
@Model
public final class HabitLogEntity {
    @Attribute(.unique) public var id: UUID
    public var habitID: UUID
    public var ownerID: UUID
    public var completedOn: Date
    public var note: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        habitID: UUID,
        ownerID: UUID,
        completedOn: Date,
        note: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.habitID = habitID
        self.ownerID = ownerID
        self.completedOn = completedOn
        self.note = note
        self.createdAt = createdAt
    }
}
