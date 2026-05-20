import AppIntents
import Core
import Foundation
import Reminders
import SwiftData

/// Live Activity / lock-screen intent. Marks the tapped row done in
/// SwiftData, immediately re-renders the Lumen Pin so the row drops, and
/// keeps everything off the main app -- the user never has to unlock to
/// check things off their list.
struct MarkLumenItemDoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Lumen item done"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Item ID") var itemID: String

    init() {}
    init(itemID: String) {
        self.itemID = itemID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: itemID) else { return .result() }
        let context = PersistenceController.shared.mainContext
        let descriptor = FetchDescriptor<ReminderEntity>(
            predicate: #Predicate { $0.id == uuid }
        )
        if let entity = try context.fetch(descriptor).first {
            entity.status = .done
            entity.completedAt = Date()
            entity.updatedAt = Date()
            entity.pendingSync = true
            try context.save()
            // Force the SwiftData container to flush any pending changes
            // before LumenPinController re-reads. Without this, refresh()
            // can race the save and re-render the now-done item as still
            // active, leaving the row stuck on the lock screen.
            context.processPendingChanges()
        }
        // `await` here so iOS keeps the intent process alive long enough
        // for the ActivityKit update to commit. The previous fire-and-
        // forget Task could be reaped before the activity updated, which
        // is why the row visibly stuck around until the next foreground.
        await LumenPinController.shared.refresh()
        return .result()
    }
}
