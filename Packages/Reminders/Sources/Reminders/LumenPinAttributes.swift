import ActivityKit
import Foundation

/// Attributes for the persistent "Lumen Pin" Live Activity. Rather than a
/// single timer-style activity per reminder, this one shows up to 3 pinned
/// items at once — the look the user pointed at from Meteor (a card sitting
/// on the lock screen that won't dismiss).
public struct LumenPinAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var items: [Item]
        public var updatedAt: Date

        public init(items: [Item], updatedAt: Date = .now) {
            self.items = items
            self.updatedAt = updatedAt
        }

        public struct Item: Codable, Hashable, Identifiable {
            public enum Kind: String, Codable, Hashable, Sendable {
                case note, reminder, task
            }

            public var id: String
            public var title: String
            public var subtitle: String?
            public var dueAt: Date?
            public var kind: Kind

            public init(
                id: String,
                title: String,
                subtitle: String? = nil,
                dueAt: Date? = nil,
                kind: Kind = .reminder
            ) {
                self.id = id
                self.title = title
                self.subtitle = subtitle
                self.dueAt = dueAt
                self.kind = kind
            }

            /// Convenience for callers that still think in terms of the old
            /// boolean.
            public var isNote: Bool { kind == .note }
        }
    }

    /// Static channel name. There's only one Lumen Pin per device — we update
    /// the same activity instead of starting a new one each time content
    /// changes.
    public var channel: String

    public init(channel: String = "lumen-pin") {
        self.channel = channel
    }
}
