import Core
import Foundation
import SwiftData
import UserNotifications
import WidgetKit

/// Higher-level reminder operations: create from raw text, mark complete,
/// snooze, schedule local notifications.
/// Lightweight snapshot used by the home view's undo toast. Carries enough
/// info to render the toast and the reminder ID needed to revert.
public struct ReminderCompletion: Identifiable, Equatable {
    public let id = UUID()
    public let reminderID: UUID
    public let title: String
    public let completedAt: Date
}

@MainActor
public final class RemindersService: ObservableObject {
    public static let shared = RemindersService()

    /// The most recently completed reminder. UI observes this to render an
    /// "Undo" toast for ~5 seconds. Cleared automatically (or by the toast).
    @Published public var lastCompletion: ReminderCompletion?

    /// Reminders that were just marked done but should still appear in the
    /// active list for `gracePeriod` seconds with strikethrough styling, so
    /// the user can:
    ///   * actually see what they tapped (the row doesn't vanish instantly)
    ///   * tap again to untick by mistake
    /// Maps reminder ID → moment it was completed. Items roll out of this
    /// dictionary automatically after the grace period expires.
    @Published public var recentlyCompleted: [UUID: Date] = [:]

    /// How long a freshly completed reminder lingers in the active list
    /// before it disappears. iOS Reminders does ~5s; the user asked for a
    /// minute.
    public static let gracePeriod: TimeInterval = 60

    /// How many alarm repeats to schedule for high/critical priority. The
    /// first fires at the due time, the others one minute apart.
    private static let repeatCount = 5
    /// Filename of the bundled looping bell tone (resides in the main bundle
    /// under `App/Resources/Sounds/`). Must match the case-sensitive name on
    /// disk because iOS reads it directly from the bundle root at notification
    /// fire time.
    private static let alarmSoundFile = "lumen-alarm.caf"
    /// Notification category identifier registered in `LumenAppDelegate`. The
    /// "Stop alarm" action is attached to this category.
    public static let alarmCategoryIdentifier = "lumen.reminder.alarm"

    private let parser = NLParser()
    private let recurrence = RecurrenceEngine()
    private let priorityEngine = PriorityEngine()
    private let persistence: PersistenceController

    public init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        // Listen for status transitions that happened off-device (e.g. user
        // marked the reminder done on iPad, server merge, realtime delete).
        // SwiftData updates the row but won't touch UNUserNotificationCenter,
        // so without this hook a "ghost" alarm could still fire on this
        // device. Cheap to be defensive here.
        NotificationCenter.default.addObserver(
            forName: .lumenReminderResolved,
            object: nil,
            queue: .main
        ) { note in
            guard let id = note.userInfo?["reminder_id"] as? UUID else { return }
            Task { @MainActor in
                Self.cancelNotifications(for: id)
            }
        }
    }

    /// Create a reminder from natural-language text. If `overrideDueAt` is
    /// provided, it wins over whatever the parser extracts (used by the
    /// Precise tab in QuickAddSheet). Same for `overridePriority`.
    ///
    /// `kind` controls whether this is a note (no alarm), reminder (with
    /// alarm), or task (checkbox). Notes never schedule notifications even
    /// if the parser extracts a time.
    @discardableResult
    public func createFromText(
        _ raw: String,
        ownerID: UUID,
        overrideDueAt: Date? = nil,
        overridePriority: Int? = nil,
        kind: ReminderKind = .reminder,
        isPinned: Bool = false
    ) async throws -> ReminderEntity {
        let draft = parser.parse(raw)
        let resolvedDueAt: Date?
        switch kind {
        case .note:
            resolvedDueAt = nil
        case .reminder:
            resolvedDueAt = overrideDueAt ?? draft.dueAt
        case .task:
            resolvedDueAt = overrideDueAt
        }
        let entity = ReminderEntity(
            ownerID: ownerID,
            title: draft.title.isEmpty ? raw : draft.title,
            dueAt: resolvedDueAt,
            recurrenceJSON: draft.recurrence.flatMap(encodeRecurrence(_:)),
            priority: overridePriority ?? draft.priority,
            kind: kind,
            isPinned: isPinned
        )
        let context = persistence.mainContext
        context.insert(entity)
        try context.save()
        if kind == .reminder {
            await scheduleNotifications(for: entity)
        }
        reloadWidgets()
        return entity
    }

    /// Toggle whether a note is pinned to the lock-screen widget. No-op for
    /// non-note kinds.
    public func togglePin(_ entity: ReminderEntity) async {
        entity.isPinned.toggle()
        try? persistence.mainContext.save()
        reloadWidgets()
    }

    public func markDone(_ entity: ReminderEntity) async {
        cancelNotifications(for: entity.id)
        let snapshot = ReminderCompletion(
            reminderID: entity.id,
            title: entity.title,
            completedAt: Date()
        )
        entity.status = .done
        entity.completedAt = snapshot.completedAt
        lastCompletion = snapshot
        // Keep this row visible (with strikethrough) for `gracePeriod`
        // seconds so the user can actually see they ticked it and undo
        // by mistake. The view layer unions `recentlyCompleted` keys with
        // the active list; once they roll off here, the row vanishes.
        let completedID = entity.id
        recentlyCompleted[completedID] = snapshot.completedAt
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.gracePeriod * 1_000_000_000))
            await MainActor.run { [weak self] in
                guard let self else { return }
                // Only evict if the reminder is still done; if the user
                // already untapped it, `unmarkDone` cleared the entry.
                if self.recentlyCompleted[completedID] == snapshot.completedAt {
                    self.recentlyCompleted.removeValue(forKey: completedID)
                    self.reloadWidgets()
                }
            }
        }
        if let json = entity.recurrenceJSON,
           let recurrence: Reminder.Recurrence = try? JSONDecoder().decode(
               Reminder.Recurrence.self,
               from: Data(json.utf8)
           ),
           let due = entity.dueAt,
           let next = self.recurrence.nextOccurrence(after: due, recurrence: recurrence)
        {
            // Spawn next occurrence
            let context = persistence.mainContext
            let copy = ReminderEntity(
                ownerID: entity.ownerID,
                title: entity.title,
                body: entity.body,
                dueAt: next,
                recurrenceJSON: entity.recurrenceJSON,
                priority: entity.priority,
                source: entity.source
            )
            context.insert(copy)
            await scheduleNotifications(for: copy)
        }
        try? persistence.mainContext.save()
        reloadWidgets()
    }

    /// Permanently delete a reminder.
    public func delete(_ entity: ReminderEntity) async {
        let id = entity.id
        cancelNotifications(for: id)
        recentlyCompleted.removeValue(forKey: id)
        let context = persistence.mainContext
        context.delete(entity)
        try? context.save()
        reloadWidgets()
    }

    /// Reverse `markDone(_:)` so a tap-by-mistake can be undone.
    public func unmarkDone(_ entity: ReminderEntity) async {
        entity.status = .active
        entity.completedAt = nil
        try? persistence.mainContext.save()
        if lastCompletion?.reminderID == entity.id { lastCompletion = nil }
        recentlyCompleted.removeValue(forKey: entity.id)
        await scheduleNotifications(for: entity)
        reloadWidgets()
    }

    /// Restore by reminder ID. Used by the undo toast which only holds a
    /// snapshot, not the live entity (especially when the entity scrolled out
    /// of @Query range).
    public func unmarkDone(reminderID: UUID) async {
        let context = persistence.mainContext
        let descriptor = FetchDescriptor<ReminderEntity>(
            predicate: #Predicate { $0.id == reminderID }
        )
        guard let entity = try? context.fetch(descriptor).first else {
            lastCompletion = nil
            return
        }
        await unmarkDone(entity)
    }

    /// Update title / body / dueAt / priority of an existing reminder.
    public func update(
        _ entity: ReminderEntity,
        title: String? = nil,
        body: String? = nil,
        dueAt: Date?? = nil,
        priority: Int? = nil
    ) async {
        if let title { entity.title = title }
        if let body { entity.body = body.isEmpty ? nil : body }
        if case .some(let newDue) = dueAt { entity.dueAt = newDue }
        if let priority { entity.priority = priority }
        try? persistence.mainContext.save()
        await scheduleNotifications(for: entity)
        reloadWidgets()
    }

    public func snooze(_ entity: ReminderEntity, minutes: Int) async {
        entity.dueAt = (entity.dueAt ?? Date()).addingTimeInterval(TimeInterval(minutes * 60))
        entity.status = .snoozed
        try? persistence.mainContext.save()
        await scheduleNotifications(for: entity)
        reloadWidgets()
    }

    public func nextDue(in context: ModelContext) -> ReminderEntity? {
        var descriptor = FetchDescriptor<ReminderEntity>(
            predicate: #Predicate { $0.statusRaw == "active" && $0.dueAt != nil },
            sortBy: [SortDescriptor(\.dueAt)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    public func urgency(for snapshot: Reminder) -> Int {
        priorityEngine.urgency(for: snapshot)
    }

    private func encodeRecurrence(_ recurrence: Reminder.Recurrence) -> String? {
        guard let data = try? JSONEncoder().encode(recurrence) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Notification scheduling

    /// Build the deterministic identifiers a reminder uses for its pending
    /// notification requests. We cancel/list using these so a single mutation
    /// covers all repeats for an alarm.
    public static func notificationIdentifiers(for reminderID: UUID) -> [String] {
        (0..<repeatCount).map { "\(reminderID.uuidString)-rep\($0)" }
    }

    /// Public so other modules (e.g. `LumenAppDelegate` notification action
    /// handlers) can wipe pending + delivered alarms for a reminder ID
    /// without having to fetch the entity first.
    public static func cancelNotifications(for reminderID: UUID) {
        let ids = Self.notificationIdentifiers(for: reminderID)
        // Include the legacy bare-uuid identifier so older pending requests
        // (scheduled before the tiered rewrite) are also removed.
        let allIDs = [reminderID.uuidString] + ids
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allIDs)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: allIDs)
    }

    private func cancelNotifications(for reminderID: UUID) {
        Self.cancelNotifications(for: reminderID)
    }

    /// Schedules one or more local notifications for a reminder.
    ///
    /// Low/Medium priority (0-1) gets a single ding. High/Critical (>=2) gets
    /// up to `repeatCount` repeats one minute apart, each playing the bundled
    /// looping bell tone, so the user can't miss it.
    private func scheduleNotifications(for entity: ReminderEntity) async {
        // Always wipe any existing scheduled requests first; nothing else
        // ensures a clean slate when the user moves the alarm time.
        cancelNotifications(for: entity.id)

        guard let due = entity.dueAt, due > Date() else { return }

        let center = UNUserNotificationCenter.current()
        let isAlarmPriority = entity.priority >= 2
        let repeatTotal = isAlarmPriority ? Self.repeatCount : 1

        let baseSound: UNNotificationSound = isAlarmPriority
            ? UNNotificationSound(named: UNNotificationSoundName(Self.alarmSoundFile))
            : .default

        for offsetIndex in 0..<repeatTotal {
            let fireDate = due.addingTimeInterval(TimeInterval(offsetIndex * 60))
            let content = UNMutableNotificationContent()
            content.title = entity.title
            if let b = entity.body { content.body = b }
            content.sound = baseSound
            content.interruptionLevel = .active
            content.threadIdentifier = "lumen.reminders"
            content.categoryIdentifier = Self.alarmCategoryIdentifier
            content.userInfo = [
                "reminder_id": entity.id.uuidString,
                "is_alarm": isAlarmPriority,
                "repeat_index": offsetIndex
            ]

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: fireDate
                ),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: Self.notificationIdentifiers(for: entity.id)[offsetIndex],
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// Public hook for things like Calendar import that need to nudge the
    /// widget timelines without owning a `RemindersService` reference.
    public func reloadAfterImport() async {
        reloadWidgets()
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        // Keep the lock-screen Live Activity in sync with whatever is now in
        // the store. Costs nothing if it's already up to date.
        LumenPinController.shared.refreshAsync()
    }
}
