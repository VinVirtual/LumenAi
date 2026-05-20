import Core
import Reminders
import SwiftData
import UIKit
import UserNotifications

final class LumenAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        Task { @MainActor in
            NotificationCategories.register()
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        }
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard
            let raw = info["reminder_id"] as? String,
            let reminderID = UUID(uuidString: raw)
        else { return }

        switch response.actionIdentifier {
        case NotificationCategories.stopAlarmActionIdentifier,
             UNNotificationDismissActionIdentifier:
            // Wipe pending + delivered for every identifier associated with
            // this reminder, including the legacy bare-uuid one. Using the
            // shared helper keeps the rule in one place.
            await MainActor.run {
                RemindersService.cancelNotifications(for: reminderID)
            }
        case NotificationCategories.markDoneActionIdentifier:
            await markDone(reminderID: reminderID)
        case NotificationCategories.snoozeActionIdentifier:
            await snooze(reminderID: reminderID, minutes: 10)
        default:
            break
        }
    }

    @MainActor
    private func markDone(reminderID: UUID) async {
        guard let entity = fetchReminder(id: reminderID) else {
            // No local row (deleted, or this device hasn't synced yet).
            // Still cancel notifications so the user isn't pestered again.
            RemindersService.cancelNotifications(for: reminderID)
            return
        }
        await RemindersService.shared.markDone(entity)
    }

    @MainActor
    private func snooze(reminderID: UUID, minutes: Int) async {
        guard let entity = fetchReminder(id: reminderID) else {
            RemindersService.cancelNotifications(for: reminderID)
            return
        }
        await RemindersService.shared.snooze(entity, minutes: minutes)
    }

    @MainActor
    private func fetchReminder(id: UUID) -> ReminderEntity? {
        let context = PersistenceController.shared.mainContext
        let descriptor = FetchDescriptor<ReminderEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }
}
