import Core
import EventKit
import Foundation
import SwiftData

/// Bridges Apple Calendar events into Lumen reminders. Idempotent: existing
/// rows are matched by `externalID == eventIdentifier` so re-running won't
/// duplicate.
@MainActor
public final class CalendarImporter: ObservableObject {
    public static let shared = CalendarImporter()

    @Published public private(set) var isImporting = false
    @Published public private(set) var lastImported: Date?
    @Published public private(set) var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    private let store = EKEventStore()
    private let persistence: PersistenceController

    public init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    /// Trigger the system permission prompt. Returns `true` if access was
    /// granted. Uses `requestFullAccessToEvents` on iOS 17+ which is the
    /// only API that surfaces the new "Full Access" dialog.
    public func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            return granted
        } catch {
            LumenLog.app.error("calendar access request failed: \(error.localizedDescription)")
            return false
        }
    }

    public var hasAccess: Bool {
        switch authorizationStatus {
        case .fullAccess, .authorized: true
        default: false
        }
    }

    /// Import events from now through `daysAhead` days into Lumen. Only
    /// non-all-day events with a start date in the future are imported, and
    /// ones already imported (matched by `externalID`) are updated in place.
    @discardableResult
    public func importUpcoming(daysAhead: Int = 14, ownerID: UUID) async -> Int {
        guard hasAccess else { return 0 }
        isImporting = true
        defer { isImporting = false }

        let now = Date()
        guard let end = Calendar.current.date(byAdding: .day, value: daysAhead, to: now) else { return 0 }
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.startDate > now }

        let context = persistence.mainContext
        var imported = 0
        for event in events {
            let externalID = "apple:\(event.eventIdentifier ?? UUID().uuidString)"
            let descriptor = FetchDescriptor<ReminderEntity>(
                predicate: #Predicate { $0.externalID == externalID }
            )
            if let existing = try? context.fetch(descriptor).first {
                existing.title = event.title ?? existing.title
                existing.body = event.notes
                existing.dueAt = event.startDate
                existing.locationName = event.location
                existing.updatedAt = .now
            } else {
                let entity = ReminderEntity(
                    ownerID: ownerID,
                    title: event.title ?? "Calendar event",
                    body: event.notes,
                    dueAt: event.startDate,
                    locationName: event.location,
                    priority: 1,
                    source: .imported,
                    kind: .reminder,
                    externalID: externalID
                )
                context.insert(entity)
                imported += 1
            }
        }
        try? context.save()
        lastImported = .now
        await reloadWidgets()
        return imported
    }

    @MainActor
    private func reloadWidgets() async {
        // Reach through RemindersService so widget reload uses the same path.
        await RemindersService.shared.reloadAfterImport()
    }
}
