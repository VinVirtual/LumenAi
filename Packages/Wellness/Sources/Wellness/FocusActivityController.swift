import ActivityKit
import Core
import Foundation

/// Owns the lock-screen focus session Live Activity. The Pomodoro timer
/// in `PomodoroController` ticks locally; this controller mirrors the
/// state to ActivityKit so the user sees a countdown ring on the lock
/// screen / Dynamic Island even while the phone is locked.
@MainActor
public final class FocusActivityController {
    public static let shared = FocusActivityController()

    public init() {}

    public var isAvailable: Bool {
        guard #available(iOS 16.2, *) else { return false }
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    public func start(label: String, duration: TimeInterval, mode: FocusActivityAttributes.ContentState.Mode = .focus) {
        guard #available(iOS 16.2, *), isAvailable else { return }
        // End any leftover focus activity so we never stack two timers.
        endAll()
        let attributes = FocusActivityAttributes(label: label, totalDuration: duration)
        let endsAt = Date().addingTimeInterval(duration)
        let state = FocusActivityAttributes.ContentState(endsAt: endsAt, mode: mode)
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: endsAt.addingTimeInterval(60))
            )
        } catch {
            LumenLog.app.error("Focus LiveActivity start failed: \(error.localizedDescription)")
        }
    }

    public func update(paused: Bool, remaining: TimeInterval) {
        guard #available(iOS 16.2, *) else { return }
        Task {
            for activity in Activity<FocusActivityAttributes>.activities {
                var state = activity.content.state
                state.paused = paused
                if paused {
                    state.pausedRemaining = remaining
                } else {
                    // Roll endsAt forward by the time we were paused.
                    state.endsAt = Date().addingTimeInterval(remaining)
                    state.pausedRemaining = nil
                }
                await activity.update(.init(state: state, staleDate: state.endsAt.addingTimeInterval(60)))
            }
        }
    }

    public func endAll() {
        guard #available(iOS 16.2, *) else { return }
        Task {
            for activity in Activity<FocusActivityAttributes>.activities {
                await activity.end(activity.content, dismissalPolicy: .immediate)
            }
        }
    }
}
