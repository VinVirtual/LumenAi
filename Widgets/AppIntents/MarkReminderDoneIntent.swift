import AppIntents
import Core
import Foundation
import SwiftData

/// Interactive widget intent: marks a reminder done with a single tap, no app
/// launch required.
struct MarkReminderDoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Reminder Done"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Reminder ID") var reminderID: String

    init() {}
    init(reminderID: String) {
        self.reminderID = reminderID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = PersistenceController.shared.mainContext
        guard let uuid = UUID(uuidString: reminderID) else { return .result() }
        let descriptor = FetchDescriptor<ReminderEntity>(
            predicate: #Predicate { $0.id == uuid }
        )
        if let entity = try context.fetch(descriptor).first {
            entity.status = .done
            entity.completedAt = Date()
            entity.pendingSync = true
            try context.save()
        }
        return .result()
    }
}
