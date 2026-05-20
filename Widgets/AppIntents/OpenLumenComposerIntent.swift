import AppIntents
import Foundation
import Reminders

/// Lock-screen intent that bounces the user into the Lumen composer with a
/// preselected `kind` ("note" or "task"). iOS does not allow text fields
/// inside a Live Activity, so the cleanest UX is the same as Apple
/// Reminders: tap a "+ Note" / "+ Todo" chip on the lock screen, the app
/// opens with the composer already loaded.
///
/// We can't return `OpenURLIntent` (iOS 18+) on our iOS 17 deployment, so
/// instead we set `openAppWhenRun = true` (the system foregrounds the app
/// for us) and post the existing `lumenOpenCompose` notification. The app
/// already listens for it and routes to QuickAddSheet with the right kind.
struct OpenLumenComposerIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Lumen composer"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Kind", default: "note") var kind: String

    init() {}
    init(kind: String) {
        self.kind = kind
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .lumenOpenCompose,
            object: nil,
            userInfo: ["kind": kind]
        )
        return .result()
    }
}
