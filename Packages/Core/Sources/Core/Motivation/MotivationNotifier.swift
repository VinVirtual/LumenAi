import Foundation
import SwiftUI
import UserNotifications

/// Schedules at most one local notification per calendar day carrying a
/// curated motivational line. The user picks a window of the day; we draw
/// a random fire-time inside that window for each upcoming day so the ping
/// doesn't feel mechanical.
///
/// We keep the next ~7 days primed at any moment so even if the app stays
/// closed for a while, motivations keep landing. Each schedule pass
/// cancels any of our previously-queued requests first to avoid stale
/// duplicates after a settings change.
@MainActor
public final class MotivationNotifier {
    public static let shared = MotivationNotifier()

    public static let identifierPrefix = "lumen.motivation.notif."

    /// How many calendar days to keep primed in the system queue. A week
    /// is the iOS pending-request soft limit per app sliced thin enough to
    /// not crowd reminders.
    private let lookaheadDays = 7

    @AppStorage("lumen.motivation.notif.enabled") private var enabled: Bool = false
    /// Minute-of-day for the earliest allowed fire (0–1439). Default 09:00.
    @AppStorage("lumen.motivation.notif.startMinutes") private var startMinutes: Int = 9 * 60
    /// Minute-of-day for the latest allowed fire (0–1439). Default 21:00.
    @AppStorage("lumen.motivation.notif.endMinutes") private var endMinutes: Int = 21 * 60

    private let store: MotivationStore
    private let center: UNUserNotificationCenter

    public init(
        store: MotivationStore = .shared,
        center: UNUserNotificationCenter = .current()
    ) {
        self.store = store
        self.center = center
    }

    // MARK: - Public API

    /// Re-derive the upcoming week of motivation notifications based on
    /// the current settings. Cheap to call repeatedly; safe to invoke on
    /// foreground, on toggle change, on time-window change.
    public func reschedule() {
        cancelPending { [weak self] in
            guard let self else { return }
            guard self.enabled else { return }
            Task { @MainActor in
                await self.scheduleNextDays()
            }
        }
    }

    /// Wipe pending motivation notifications without scheduling new ones.
    /// Used when the user disables the feature.
    public func cancelAll() {
        cancelPending(completion: nil)
    }

    // MARK: - Scheduling

    private func scheduleNextDays() async {
        let calendar = Calendar.current
        let now = Date()
        let safeWindow = clampedWindow()

        // Build a small rolling pool of recent IDs so adjacent days don't
        // repeat the same line. Seed it with the rotation already in the
        // store to stay in sync with the on-screen card.
        var recentIDs: [String] = []
        let pool = store.all
        guard !pool.isEmpty else { return }

        for offset in 0..<lookaheadDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let comps = calendar.dateComponents([.year, .month, .day], from: day)

            let minute = Int.random(in: safeWindow)
            var fireComps = comps
            fireComps.hour = minute / 60
            fireComps.minute = minute % 60
            fireComps.second = 0

            // Skip today's slot if it has already passed — otherwise iOS
            // happily fires the notification immediately.
            if offset == 0,
               let scheduledDate = calendar.date(from: fireComps),
               scheduledDate <= now.addingTimeInterval(60) {
                continue
            }

            let pick = pickMotivation(pool: pool, recent: recentIDs)
            recentIDs.append(pick.id)

            let content = UNMutableNotificationContent()
            content.title = title(for: pick)
            content.body = pick.text
            content.sound = .default
            content.threadIdentifier = "lumen.motivation"
            content.userInfo = [
                "type": "motivation",
                "id": pick.id,
                "category": pick.category.rawValue
            ]

            let trigger = UNCalendarNotificationTrigger(dateMatching: fireComps, repeats: false)
            let dayKey = Self.dayKey(from: comps)
            let request = UNNotificationRequest(
                identifier: Self.identifierPrefix + dayKey,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private func pickMotivation(pool: [Motivation], recent: [String]) -> Motivation {
        let recentSet = Set(recent)
        let candidates = pool.filter { !recentSet.contains($0.id) }
        if let picked = candidates.randomElement() { return picked }
        return pool.randomElement() ?? pool[0]
    }

    private func title(for motivation: Motivation) -> String {
        // Keep the title short and varied so banners don't all read the
        // same. The category label gives just enough flavour.
        switch motivation.category {
        case .focus: return "A nudge for today"
        case .gratitude: return "A small thanks"
        case .calm: return "Take a breath"
        case .drive: return "Keep going"
        case .kindness: return "Be kind today"
        }
    }

    private func clampedWindow() -> Range<Int> {
        let lower = max(0, min(startMinutes, 1439))
        let upper = max(0, min(endMinutes, 1439))
        // If the user inverts the window, fall back to a sensible 9–21
        // span rather than refusing to schedule anything at all.
        guard upper - lower >= 15 else { return (9 * 60)..<(21 * 60) }
        return lower..<upper
    }

    private func cancelPending(completion: (() -> Void)?) {
        center.getPendingNotificationRequests { [weak self] requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.identifierPrefix) }
            if !ids.isEmpty {
                self?.center.removePendingNotificationRequests(withIdentifiers: ids)
            }
            DispatchQueue.main.async { completion?() }
        }
    }

    private static func dayKey(from comps: DateComponents) -> String {
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
