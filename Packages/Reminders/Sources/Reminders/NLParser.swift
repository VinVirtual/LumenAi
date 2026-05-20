import Core
import Foundation

/// Lightweight natural-language parser for reminders. Handles common time and
/// recurrence phrases on-device. Ambiguous inputs should be sent to the
/// `ai-parse` Edge Function (see `RemindersService`).
public struct NLParser: Sendable {
    public struct Draft: Sendable {
        public var title: String
        public var dueAt: Date?
        public var recurrence: Reminder.Recurrence?
        public var priority: Int

        public init(
            title: String,
            dueAt: Date? = nil,
            recurrence: Reminder.Recurrence? = nil,
            priority: Int = 0
        ) {
            self.title = title
            self.dueAt = dueAt
            self.recurrence = recurrence
            self.priority = priority
        }
    }

    public init() {}

    public func parse(_ raw: String, calendar: Calendar = .current, now: Date = .now) -> Draft {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var dueAt: Date? = nil
        var recurrence: Reminder.Recurrence? = nil
        var priority = 0

        if let bang = title.range(of: "!!") {
            priority = 3
            title.removeSubrange(bang)
        } else if title.contains("!") {
            priority = 2
            title = title.replacingOccurrences(of: "!", with: "")
        }

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(title.startIndex..., in: title)
            if let match = detector.firstMatch(in: title, range: range), let date = match.date {
                dueAt = date
                if let r = Range(match.range, in: title) {
                    title.removeSubrange(r)
                }
            }
        }

        let lowered = title.lowercased()
        if lowered.contains("every day") || lowered.contains("daily") {
            recurrence = .init(freq: .daily)
        } else if lowered.contains("every week") || lowered.contains("weekly") {
            recurrence = .init(freq: .weekly)
        } else if lowered.contains("every month") || lowered.contains("monthly") {
            recurrence = .init(freq: .monthly)
        }

        for word in ["every day", "daily", "every week", "weekly", "every month", "monthly"] {
            if let r = title.range(of: word, options: .caseInsensitive) {
                title.removeSubrange(r)
            }
        }

        if dueAt == nil {
            if lowered.contains("tonight") {
                dueAt = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)
            } else if lowered.contains("tomorrow") {
                dueAt = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            }
        }

        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return Draft(title: title, dueAt: dueAt, recurrence: recurrence, priority: priority)
    }
}
