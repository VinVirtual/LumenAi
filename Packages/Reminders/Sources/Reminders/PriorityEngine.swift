import Core
import Foundation

/// Computes a 0...100 urgency score for a reminder based on its proximity to
/// the due date, declared priority, and snooze count.
public struct PriorityEngine: Sendable {
    public init() {}

    public func urgency(for reminder: Reminder, now: Date = .now) -> Int {
        var score = reminder.priority * 15
        if let due = reminder.dueAt {
            let delta = due.timeIntervalSince(now)
            if delta < 0 {
                score += 60 // overdue
            } else if delta < 60 * 30 {
                score += 50
            } else if delta < 60 * 60 * 2 {
                score += 30
            } else if delta < 60 * 60 * 24 {
                score += 15
            }
        }
        if reminder.status == .escalated { score += 25 }
        return max(0, min(100, score))
    }
}
