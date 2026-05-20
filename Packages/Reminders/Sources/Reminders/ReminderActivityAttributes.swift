import ActivityKit
import Foundation

/// Live Activity attributes shared between the main app (which starts the
/// activity) and the widget extension (which renders the UI).
public struct ReminderActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var title: String
        public var dueAt: Date
        public var priority: Int
        public var sharedWith: [String]
        public var ackEmoji: String?

        public init(
            title: String,
            dueAt: Date,
            priority: Int = 0,
            sharedWith: [String] = [],
            ackEmoji: String? = nil
        ) {
            self.title = title
            self.dueAt = dueAt
            self.priority = priority
            self.sharedWith = sharedWith
            self.ackEmoji = ackEmoji
        }
    }

    public var reminderID: String
    public var personaName: String

    public init(reminderID: String, personaName: String) {
        self.reminderID = reminderID
        self.personaName = personaName
    }
}
