import Core
import Foundation
import SwiftData

/// Local-only habit tracking for the public/offline edition.
///
/// Backed entirely by SwiftData (`HabitEntity` + `HabitLogEntity`).
/// Mirrors the surface area the cloud-backed `WellnessService` used to
/// expose so `HabitsHomeView` continues to render without changes.
@MainActor
public final class WellnessService: ObservableObject {
    public static let shared = WellnessService()

    /// Cached value-type snapshot of all the user's habits, rebuilt by
    /// `refresh()` every time a mutation lands. Views observe this; the
    /// underlying `HabitEntity` rows are kept private to keep the
    /// persistence model swap (Supabase → SwiftData) opaque.
    @Published public private(set) var habits: [Habit] = []

    private let persistence: PersistenceController
    private let calendar = Calendar.current

    public init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Reads

    public func refresh() async {
        let context = persistence.mainContext
        let descriptor = FetchDescriptor<HabitEntity>(
            sortBy: [SortDescriptor(\HabitEntity.createdAt, order: .forward)]
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        habits = entities.map { entity in
            Habit(
                id: entity.id,
                userID: entity.ownerID,
                title: entity.title,
                icon: entity.icon,
                streak: entity.streak,
                longestStreak: entity.longestStreak,
                lastDoneAt: entity.lastDoneAt,
                createdAt: entity.createdAt
            )
        }
    }

    // MARK: - Mutations

    public func addHabit(title: String, icon: String? = nil) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entity = HabitEntity(
            ownerID: LocalIdentityService.shared.ownerID,
            title: trimmed,
            icon: icon
        )
        persistence.mainContext.insert(entity)
        try? persistence.mainContext.save()
        await refresh()
    }

    public func deleteHabit(_ habit: Habit) async throws {
        let context = persistence.mainContext
        let id = habit.id
        let logsDescriptor = FetchDescriptor<HabitLogEntity>(
            predicate: #Predicate { $0.habitID == id }
        )
        if let logs = try? context.fetch(logsDescriptor) {
            for log in logs { context.delete(log) }
        }
        let habitDescriptor = FetchDescriptor<HabitEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let entity = try? context.fetch(habitDescriptor).first {
            context.delete(entity)
        }
        try? context.save()
        await refresh()
    }

    /// Toggle the "done today" state. If already logged for today,
    /// removes the log and rolls the streak back by one day. Otherwise
    /// inserts a log and (if yesterday is also logged) extends the
    /// running streak.
    public func toggleHabit(_ habit: Habit, on date: Date = .now) async throws {
        let context = persistence.mainContext
        let habitID = habit.id
        let habitDescriptor = FetchDescriptor<HabitEntity>(
            predicate: #Predicate { $0.id == habitID }
        )
        guard let entity = try? context.fetch(habitDescriptor).first else { return }

        let day = calendar.startOfDay(for: date)
        let logsDescriptor = FetchDescriptor<HabitLogEntity>(
            predicate: #Predicate { $0.habitID == habitID }
        )
        let logs = (try? context.fetch(logsDescriptor)) ?? []
        let existingForToday = logs.first { calendar.isDate($0.completedOn, inSameDayAs: day) }

        if let existing = existingForToday {
            context.delete(existing)
        } else {
            let log = HabitLogEntity(
                habitID: habitID,
                ownerID: entity.ownerID,
                completedOn: day
            )
            context.insert(log)
        }
        try? context.save()
        recomputeStreak(entity: entity, in: context)
        try? context.save()
        await refresh()
    }

    // MARK: - Streak math

    /// Walks back from today counting consecutive days that have a log,
    /// updates `streak` / `longestStreak` / `lastDoneAt`. Cheap (O(N)
    /// in number of logs) and keeps the value-type DTOs honest.
    private func recomputeStreak(entity: HabitEntity, in context: ModelContext) {
        let habitID = entity.id
        let descriptor = FetchDescriptor<HabitLogEntity>(
            predicate: #Predicate { $0.habitID == habitID }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        let days = Set(logs.map { calendar.startOfDay(for: $0.completedOn) })

        var streak = 0
        var cursor = calendar.startOfDay(for: .now)
        while days.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        entity.streak = streak
        entity.longestStreak = max(entity.longestStreak, streak)
        entity.lastDoneAt = logs.map(\.completedOn).max()
    }
}
