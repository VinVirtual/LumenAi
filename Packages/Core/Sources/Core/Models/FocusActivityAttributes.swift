import ActivityKit
import Foundation

/// Live Activity attributes for the Lumen focus session card. Lives in
/// Core so the Widgets extension and the Wellness package can both touch
/// it without spinning up a new module dependency.
public struct FocusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public enum Mode: String, Codable, Hashable, Sendable {
            case focus, shortBreak, longBreak
        }

        public var endsAt: Date
        public var mode: Mode
        public var paused: Bool
        /// Seconds left when paused; ignored when `paused == false`.
        public var pausedRemaining: TimeInterval?

        public init(
            endsAt: Date,
            mode: Mode = .focus,
            paused: Bool = false,
            pausedRemaining: TimeInterval? = nil
        ) {
            self.endsAt = endsAt
            self.mode = mode
            self.paused = paused
            self.pausedRemaining = pausedRemaining
        }
    }

    public var label: String
    public var totalDuration: TimeInterval

    public init(label: String, totalDuration: TimeInterval) {
        self.label = label
        self.totalDuration = totalDuration
    }
}
