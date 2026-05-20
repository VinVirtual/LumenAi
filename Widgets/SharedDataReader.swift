import Core
import Foundation
import SwiftData

/// Read-only access to the SwiftData store from extensions. The store lives in
/// the App Group container so widgets/intents/NSE can read the same data.
@MainActor
enum SharedDataReader {
    static func nextReminder() -> ReminderEntity? {
        let context = PersistenceController.shared.mainContext
        var descriptor = FetchDescriptor<ReminderEntity>(
            predicate: #Predicate { $0.statusRaw == "active" && $0.dueAt != nil },
            sortBy: [SortDescriptor(\.dueAt)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func upcomingReminders(limit: Int = 4) -> [ReminderEntity] {
        let context = PersistenceController.shared.mainContext
        var descriptor = FetchDescriptor<ReminderEntity>(
            predicate: #Predicate { $0.statusRaw == "active" },
            sortBy: [SortDescriptor(\.dueAt)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Pinned note that powers the lock-screen note widget. Falls back to the
    /// most recently updated note when nothing is explicitly pinned.
    static func pinnedNote() -> ReminderEntity? {
        let context = PersistenceController.shared.mainContext
        let noteRaw = ReminderKind.note.rawValue
        var pinned = FetchDescriptor<ReminderEntity>(
            predicate: #Predicate { $0.statusRaw == "active" && $0.kindRaw == noteRaw && $0.isPinned },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        pinned.fetchLimit = 1
        if let p = try? context.fetch(pinned).first { return p }

        var fallback = FetchDescriptor<ReminderEntity>(
            predicate: #Predicate { $0.statusRaw == "active" && $0.kindRaw == noteRaw },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        fallback.fetchLimit = 1
        return try? context.fetch(fallback).first
    }
}
