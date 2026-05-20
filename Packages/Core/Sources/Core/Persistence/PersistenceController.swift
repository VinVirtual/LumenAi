import Foundation
import SwiftData

/// Owns the SwiftData container, configured to live in the App Group container
/// so widgets, intents, and the notification service can read locally.
public final class PersistenceController: @unchecked Sendable {
    public static let shared = PersistenceController()

    public let container: ModelContainer

    private init() {
        let schema = Schema([
            ReminderEntity.self,
            FinanceAccountEntity.self,
            FinanceCategoryEntity.self,
            FinanceTransactionEntity.self,
            HabitEntity.self,
            HabitLogEntity.self
        ])

        let storeURL: URL? = {
            guard let groupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: AppConfig.shared.appGroup
            ) else { return nil }
            return groupURL.appending(path: "Lumen.sqlite")
        }()

        let configuration = if let storeURL {
            ModelConfiguration(schema: schema, url: storeURL)
        } else {
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            LumenLog.app.error("Failed to create on-disk ModelContainer: \(error.localizedDescription); falling back to in-memory")
            do {
                container = try ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
                )
            } catch {
                fatalError("Unable to create even an in-memory ModelContainer: \(error)")
            }
        }
    }

    @MainActor
    public var mainContext: ModelContext {
        container.mainContext
    }
}
