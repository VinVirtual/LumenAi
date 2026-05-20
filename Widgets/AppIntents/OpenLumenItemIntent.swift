import AppIntents
import Core
import Foundation
import Reminders

/// Live Activity / lock-screen intent. Foregrounds the app and routes to
/// the editor for the tapped reminder. Replaces the unreliable
/// `Link(destination:)` we used inside `ItemRow` — Apple's own samples
/// switched away from `Link` because it silently no-ops on some iOS 17
/// builds.
///
/// Mirrors `OpenLumenComposerIntent`: `openAppWhenRun = true` lets iOS
/// foreground the app, then we hand the work off to the existing
/// `lumenOpenReminder` notification (RemindersHomeView already opens the
/// editor for the matching id).
struct OpenLumenItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Lumen item"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Item ID") var itemID: String

    init() {}
    init(itemID: String) {
        self.itemID = itemID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: itemID) {
            NotificationCenter.default.post(
                name: .lumenOpenReminder,
                object: nil,
                userInfo: ["id": uuid]
            )
        }
        return .result()
    }
}
