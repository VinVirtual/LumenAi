import Foundation
import UserNotifications

/// Centralised registration of `UNNotificationCategory` definitions and their
/// action identifiers. Both the main app (via the AppDelegate) and the
/// notification service extension (when modifying remote payloads) reach in
/// here to make sure the same category IDs and actions are used everywhere.
public enum NotificationCategories {
    public static let alarmCategoryIdentifier = "lumen.reminder.alarm"
    public static let stopAlarmActionIdentifier = "lumen.reminder.stop"
    public static let snoozeActionIdentifier = "lumen.reminder.snooze"
    public static let markDoneActionIdentifier = "lumen.reminder.done"

    /// Returns the categories the app should register at launch.
    public static func all() -> Set<UNNotificationCategory> {
        let stop = UNNotificationAction(
            identifier: stopAlarmActionIdentifier,
            title: "Stop alarm",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: snoozeActionIdentifier,
            title: "Snooze 10 min",
            options: []
        )
        let done = UNNotificationAction(
            identifier: markDoneActionIdentifier,
            title: "Mark done",
            options: []
        )
        let alarm = UNNotificationCategory(
            identifier: alarmCategoryIdentifier,
            actions: [stop, snooze, done],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        return [alarm]
    }

    /// Convenience: register all categories on the shared center. Idempotent.
    @MainActor
    public static func register() {
        UNUserNotificationCenter.current().setNotificationCategories(all())
    }
}
