import AppIntents
import Foundation

/// Lock-screen "End" button on the focus Live Activity. Posts a
/// notification the main app picks up to call `pomodoro.reset()`. Doesn't
/// open the app -- the Live Activity itself disappears once the
/// `FocusActivityController.endAll()` runs in-app.
struct EndFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "End Lumen focus"
    static var openAppWhenRun: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .lumenFocusEnd, object: nil)
        return .result()
    }
}

/// Lock-screen "Pause / Resume" toggle on the focus Live Activity.
struct PauseFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Lumen focus"
    static var openAppWhenRun: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .lumenFocusTogglePause, object: nil)
        return .result()
    }
}

public extension Notification.Name {
    /// Posted from the Live Activity's End button.
    static let lumenFocusEnd = Notification.Name("lumen.focus.end")
    /// Posted from the Live Activity's Pause/Resume button.
    static let lumenFocusTogglePause = Notification.Name("lumen.focus.togglePause")
}
