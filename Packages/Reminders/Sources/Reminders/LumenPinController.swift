import ActivityKit
import Core
import Foundation
import SwiftData

/// Owns the single "Lumen Pin" Live Activity on the device. The pin shows
/// pinned notes + the next two due reminders as a Meteor-style checklist on
/// the lock screen. Lives until the user manually unpins everything OR the
/// system reaps it (~8 hours), whichever comes first; refresh() resurrects
/// it any time the app is opened or content changes.
@MainActor
public final class LumenPinController {
    public static let shared = LumenPinController()

    private let persistence: PersistenceController
    /// `nil` = preference not yet saved; default is on so first-run shows it.
    private let prefKey = "lumen.pin.enabled"

    public init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    /// User-facing on/off switch. Wired to a "Lock-screen pin" toggle in the
    /// Today header so people can opt out without unpinning every note.
    public var isEnabled: Bool {
        get { (UserDefaults.standard.object(forKey: prefKey) as? Bool) ?? true }
        set { UserDefaults.standard.set(newValue, forKey: prefKey) }
    }

    /// Whether ActivityKit is actually available + the user has Live
    /// Activities enabled in Settings.
    public var isAvailable: Bool {
        guard #available(iOS 16.2, *) else { return false }
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Recompute what should be on the pin and either start, update, or end
    /// the live activity. Idempotent — call freely after any data change.
    ///
    /// `await`s the underlying `Activity.update` so callers (notably
    /// `MarkLumenItemDoneIntent.perform`) can guarantee the lock-screen
    /// row is fully refreshed before iOS reaps the intent process. Without
    /// that, a fire-and-forget Task could be cancelled mid-flight and the
    /// row would visibly stick around until the next foreground.
    public func refresh() async {
        guard #available(iOS 16.2, *), isAvailable, isEnabled else {
            stopAll()
            return
        }
        let items = currentItems()
        if items.isEmpty {
            stopAll()
            return
        }
        let state = LumenPinAttributes.ContentState(items: items)
        if let existing = currentActivity() {
            await existing.update(.init(state: state, staleDate: staleDate()))
        } else {
            do {
                _ = try Activity.request(
                    attributes: LumenPinAttributes(),
                    content: .init(state: state, staleDate: staleDate())
                )
            } catch {
                LumenLog.app.error("LumenPin start failed: \(error.localizedDescription)")
            }
        }
    }

    /// Fire-and-forget wrapper for callers that don't need to await the
    /// activity update (e.g. data observers, lifecycle hooks).
    public func refreshAsync() {
        Task { await refresh() }
    }

    public func stopAll() {
        guard #available(iOS 16.2, *) else { return }
        Task {
            for activity in Activity<LumenPinAttributes>.activities {
                await activity.end(activity.content, dismissalPolicy: .immediate)
            }
        }
    }

    @available(iOS 16.2, *)
    private func currentActivity() -> Activity<LumenPinAttributes>? {
        Activity<LumenPinAttributes>.activities.first
    }

    private func staleDate() -> Date {
        // Refresh window. iOS auto-stales after 8h regardless; we set 4h so
        // the system asks us to update slightly sooner.
        Date().addingTimeInterval(60 * 60 * 4)
    }

    /// Compose up to `Self.maxItems` rows: pinned notes first (newest →
    /// oldest), then imminent reminders, then active tasks. The Live
    /// Activity itself only renders ~5 visible at a time + a "+N more"
    /// affordance, but we hand it everything so the count badge and the
    /// overflow indicator stay accurate.
    private static let maxItems = 8

    private func currentItems() -> [LumenPinAttributes.ContentState.Item] {
        let context = persistence.mainContext
        let noteRaw = ReminderKind.note.rawValue
        let reminderRaw = ReminderKind.reminder.rawValue

        var items: [LumenPinAttributes.ContentState.Item] = []

        var pinnedDescriptor = FetchDescriptor<ReminderEntity>(
            predicate: #Predicate { $0.statusRaw == "active" && $0.kindRaw == noteRaw && $0.isPinned },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        pinnedDescriptor.fetchLimit = Self.maxItems
        if let pinned = try? context.fetch(pinnedDescriptor) {
            items.append(contentsOf: pinned.map { entity in
                LumenPinAttributes.ContentState.Item(
                    id: entity.id.uuidString,
                    title: entity.title,
                    subtitle: entity.body,
                    kind: .note
                )
            })
        }

        if items.count < Self.maxItems {
            var reminderDescriptor = FetchDescriptor<ReminderEntity>(
                predicate: #Predicate { $0.statusRaw == "active" && $0.kindRaw == reminderRaw && $0.dueAt != nil },
                sortBy: [SortDescriptor(\.dueAt, order: .forward)]
            )
            reminderDescriptor.fetchLimit = Self.maxItems - items.count
            if let reminders = try? context.fetch(reminderDescriptor) {
                items.append(contentsOf: reminders.map { entity in
                    LumenPinAttributes.ContentState.Item(
                        id: entity.id.uuidString,
                        title: entity.title,
                        subtitle: entity.body,
                        dueAt: entity.dueAt,
                        kind: .reminder
                    )
                })
            }
        }

        // Round out the slate with active tasks ordered by due date so the
        // lock-screen "to-do" view also surfaces tasks created from the
        // composer's Task tab.
        if items.count < Self.maxItems {
            let taskRaw = ReminderKind.task.rawValue
            var taskDescriptor = FetchDescriptor<ReminderEntity>(
                predicate: #Predicate { $0.statusRaw == "active" && $0.kindRaw == taskRaw },
                sortBy: [SortDescriptor(\.dueAt, order: .forward), SortDescriptor(\.updatedAt, order: .reverse)]
            )
            taskDescriptor.fetchLimit = Self.maxItems - items.count
            if let tasks = try? context.fetch(taskDescriptor) {
                items.append(contentsOf: tasks.map { entity in
                    LumenPinAttributes.ContentState.Item(
                        id: entity.id.uuidString,
                        title: entity.title,
                        subtitle: entity.body,
                        dueAt: entity.dueAt,
                        kind: .task
                    )
                })
            }
        }

        return items
    }
}
