import Foundation
import SwiftUI

/// In the public/offline edition there are no friends. This stub keeps
/// the `FriendDirectory.shared.firstName(for:)` call in
/// `RemindersHomeView` compiling — it always returns `nil`, which
/// suppresses the "from {name}" pill that would otherwise label a
/// shared reminder.
@MainActor
public final class FriendDirectory: ObservableObject {
    public static let shared = FriendDirectory()

    public init() {}

    public func displayName(for id: UUID) -> String? { nil }
    public func firstName(for id: UUID) -> String? { nil }
}
