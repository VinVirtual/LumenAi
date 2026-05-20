import Combine
import Core
import Foundation
import UserNotifications

/// Local pomodoro timer. UI binds to `state` for countdown, transitions, and
/// session counts. Mirrors itself to ActivityKit via
/// `FocusActivityController` so the lock screen card stays in sync.
@MainActor
public final class PomodoroController: ObservableObject {
    public static let shared = PomodoroController()

    @Published public private(set) var state: State = .idle
    @Published public private(set) var remaining: TimeInterval = 0
    @Published public private(set) var completedFocusBlocks: Int = 0
    @Published public private(set) var isPaused: Bool = false

    public enum State: Equatable {
        case idle
        case focus(endsAt: Date)
        case shortBreak(endsAt: Date)
        case longBreak(endsAt: Date)
    }

    public var focusDuration: TimeInterval = 25 * 60
    public var shortBreakDuration: TimeInterval = 5 * 60
    public var longBreakDuration: TimeInterval = 20 * 60
    /// User-customizable label shown on the lock screen Live Activity ("Studying", "Workout", ...).
    public var focusLabel: String = "Focus"
    /// Filename of the .caf sound played when a focus session ends. The
    /// asset must ship with the app target. Defaults to the existing
    /// alarm tone.
    public var endSoundName: String = "lumen-alarm.caf"

    /// Identifier used for the "focus session done" local notification.
    /// Cancelled on reset so abandoned sessions don't fire.
    private static let focusEndNotificationID = "lumen.focus.session-end"

    private var timer: AnyCancellable?
    private var observers: [NSObjectProtocol] = []

    public init() {
        // Listen for the lock-screen Live Activity intents. The intents
        // post a Notification and we route to the matching method here.
        // Keeping this in the singleton means the Pomodoro responds even
        // before WellnessHomeView is on screen (e.g. user launches via the
        // Live Activity itself).
        let endObs = NotificationCenter.default.addObserver(
            forName: Notification.Name("lumen.focus.end"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reset() }
        }
        let pauseObs = NotificationCenter.default.addObserver(
            forName: Notification.Name("lumen.focus.togglePause"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.isPaused { self.resume() } else { self.pause() }
            }
        }
        observers = [endObs, pauseObs]
    }

    deinit {
        for obs in observers {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    /// Update the focus duration for the next session. Has no effect on a
    /// session already in flight.
    public func setFocusDuration(minutes: Int) {
        focusDuration = TimeInterval(max(1, minutes) * 60)
    }

    public func setBreakDuration(minutes: Int) {
        shortBreakDuration = TimeInterval(max(1, minutes) * 60)
    }

    public func setLabel(_ label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        focusLabel = trimmed.isEmpty ? "Focus" : trimmed
    }

    public func setEndSound(_ filename: String) {
        endSoundName = filename
    }

    public func startFocus() {
        let ends = Date().addingTimeInterval(focusDuration)
        state = .focus(endsAt: ends)
        isPaused = false
        scheduleFocusEndNotification(at: ends)
        FocusActivityController.shared.start(
            label: focusLabel,
            duration: focusDuration,
            mode: .focus
        )
        tickToward(ends)
    }

    public func startBreak() {
        let isLong = (completedFocusBlocks + 1) % 4 == 0
        let duration = isLong ? longBreakDuration : shortBreakDuration
        let ends = Date().addingTimeInterval(duration)
        state = isLong ? .longBreak(endsAt: ends) : .shortBreak(endsAt: ends)
        isPaused = false
        FocusActivityController.shared.start(
            label: isLong ? "Long break" : "Short break",
            duration: duration,
            mode: isLong ? .longBreak : .shortBreak
        )
        tickToward(ends)
    }

    /// Pause the running session. Live Activity flips into a "paused"
    /// presentation; the local notification is cancelled because the end
    /// time is no longer fixed.
    public func pause() {
        guard !isPaused, state != .idle else { return }
        isPaused = true
        timer?.cancel()
        timer = nil
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.focusEndNotificationID])
        FocusActivityController.shared.update(paused: true, remaining: max(0, remaining))
    }

    public func resume() {
        guard isPaused else { return }
        let ends = Date().addingTimeInterval(max(1, remaining))
        switch state {
        case .focus: state = .focus(endsAt: ends)
        case .shortBreak: state = .shortBreak(endsAt: ends)
        case .longBreak: state = .longBreak(endsAt: ends)
        case .idle: return
        }
        isPaused = false
        if case .focus = state { scheduleFocusEndNotification(at: ends) }
        FocusActivityController.shared.update(paused: false, remaining: max(0, remaining))
        tickToward(ends)
    }

    public func reset() {
        timer?.cancel()
        timer = nil
        state = .idle
        remaining = 0
        isPaused = false
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.focusEndNotificationID])
        FocusActivityController.shared.endAll()
    }

    private func scheduleFocusEndNotification(at fireDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Focus complete"
        content.body = "Nice work — take a breath, stretch, sip some water."
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: endSoundName))
            ?? .default

        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.focusEndNotificationID,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.focusEndNotificationID])
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    private func tickToward(_ ends: Date) {
        timer?.cancel()
        remaining = ends.timeIntervalSinceNow
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                remaining = ends.timeIntervalSinceNow
                if remaining <= 0 {
                    timer?.cancel()
                    if case .focus = state {
                        completedFocusBlocks += 1
                        startBreak()
                    } else {
                        state = .idle
                        FocusActivityController.shared.endAll()
                    }
                }
            }
    }
}
