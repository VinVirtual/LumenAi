import Core
import Foundation

/// Computes the next occurrence of a reminder based on its recurrence rule.
public struct RecurrenceEngine: Sendable {
    public init() {}

    public func nextOccurrence(
        after date: Date,
        recurrence: Reminder.Recurrence,
        calendar: Calendar = .current
    ) -> Date? {
        if let until = recurrence.until, date >= until { return nil }
        switch recurrence.freq {
        case .daily:
            return calendar.date(byAdding: .day, value: recurrence.interval, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: recurrence.interval, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: recurrence.interval, to: date)
        case .custom:
            return nil
        }
    }
}
