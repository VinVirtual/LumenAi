import AppIntents
import Core
import Foundation
import Reminders

/// Siri / Shortcuts entry point: "Hey Siri, ask Lumen to remind me to call Dad
/// at 6pm."
struct CreateReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Reminder"
    static var description = IntentDescription("Add a Lumen reminder from natural language.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Reminder") var text: String

    init() {}
    init(text: String) {
        self.text = text
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let userID = await MainActor.run { LocalIdentityService.shared.ownerID }
        let entity = try await RemindersService.shared.createFromText(text, ownerID: userID)
        return .result(dialog: "Got it. Reminding you about \(entity.title).")
    }
}

struct LumenShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateReminderIntent(),
            phrases: [
                "Add a reminder to \(.applicationName)",
                "Tell \(.applicationName) to remind me"
            ],
            shortTitle: "Add reminder",
            systemImageName: "sparkles"
        )
    }
}
