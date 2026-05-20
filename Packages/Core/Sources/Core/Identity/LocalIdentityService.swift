import Foundation
import SwiftUI

/// Replaces `AuthService` in the public/offline edition of Lumen.
///
/// Lumen Lite has no account system — everything stays on-device.
/// `LocalIdentityService` owns a stable per-install UUID (`ownerID`) and an
/// optional display name. Both live in `UserDefaults` (under the App Group
/// so widgets and Live Activities resolve the same identity).
///
/// The UUID is generated lazily on first read so existing installs that
/// upgrade in place are also handled without an explicit "first launch"
/// hook.
@MainActor
public final class LocalIdentityService: ObservableObject {
    public static let shared = LocalIdentityService()

    /// The user-facing display name. Empty by default — the optional
    /// first-run sheet writes to this. Anything reading the name should
    /// fall back to a friendly default (e.g. "Friend") when this is
    /// empty.
    @Published public var displayName: String {
        didSet {
            defaults.set(displayName, forKey: Keys.displayName)
        }
    }

    /// Stable owner id used as the `ownerID` on every SwiftData row.
    /// Generated once per install and never rotated.
    public let ownerID: UUID

    private let defaults: UserDefaults

    private enum Keys {
        static let ownerID = "lumen.local.ownerID"
        static let displayName = "lumen.local.displayName"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let raw = defaults.string(forKey: Keys.ownerID),
           let parsed = UUID(uuidString: raw) {
            self.ownerID = parsed
        } else {
            let fresh = UUID()
            defaults.set(fresh.uuidString, forKey: Keys.ownerID)
            self.ownerID = fresh
        }

        self.displayName = defaults.string(forKey: Keys.displayName) ?? ""
    }

    /// True until the user has typed a display name. Drives whether the
    /// first-run name sheet should appear.
    public var needsDisplayName: Bool {
        displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Convenience used by greeting copy. Returns the user-typed name if
    /// any, otherwise the supplied fallback.
    public func friendlyName(fallback: String = "Friend") -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? fallback : trimmed
    }

    /// Erase the on-device identity. Called by the Profile → "Erase
    /// everything" flow alongside wiping the SwiftData store. We can't
    /// erase the UUID itself without violating the `let ownerID`
    /// guarantee — re-launching the app generates a new one.
    public func clearDisplayName() {
        displayName = ""
    }
}
