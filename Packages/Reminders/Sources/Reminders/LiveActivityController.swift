import ActivityKit
import Core
import Foundation

/// Wraps `ActivityKit` so the app can launch a Live Activity for a reminder
/// (countdown + dynamic island), with graceful no-ops when activities are
/// disabled by the user.
@MainActor
public final class LiveActivityController {
    public static let shared = LiveActivityController()

    public func start(
        reminderID: UUID,
        title: String,
        dueAt: Date,
        personaName: String,
        sharedWith: [String] = []
    ) {
        guard #available(iOS 16.2, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = ReminderActivityAttributes(
            reminderID: reminderID.uuidString,
            personaName: personaName
        )
        let state = ReminderActivityAttributes.ContentState(
            title: title,
            dueAt: dueAt,
            sharedWith: sharedWith
        )
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: dueAt.addingTimeInterval(60 * 30))
            )
        } catch {
            LumenLog.app.error("LiveActivity start failed: \(error.localizedDescription)")
        }
    }

    public func update(reminderID: UUID, ackEmoji: String) async {
        guard #available(iOS 16.2, *) else { return }
        for activity in Activity<ReminderActivityAttributes>.activities
            where activity.attributes.reminderID == reminderID.uuidString
        {
            var state = activity.content.state
            state.ackEmoji = ackEmoji
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    public func end(reminderID: UUID) async {
        guard #available(iOS 16.2, *) else { return }
        for activity in Activity<ReminderActivityAttributes>.activities
            where activity.attributes.reminderID == reminderID.uuidString
        {
            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
    }
}

/// Re-exported for use both inside `Widgets` and the main app target.
public typealias LumenReminderActivityAttributes = ReminderActivityAttributes
