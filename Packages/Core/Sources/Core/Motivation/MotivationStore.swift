import Foundation
import SwiftUI

/// One curated motivational line, bundled with the app.
public struct Motivation: Codable, Identifiable, Hashable, Sendable {
    public enum Category: String, Codable, CaseIterable, Sendable {
        case focus, gratitude, calm, drive, kindness

        public var label: String {
            switch self {
            case .focus: "Focus"
            case .gratitude: "Gratitude"
            case .calm: "Calm"
            case .drive: "Drive"
            case .kindness: "Kindness"
            }
        }

        public var iconSymbol: String {
            switch self {
            case .focus: "target"
            case .gratitude: "sparkles"
            case .calm: "leaf.fill"
            case .drive: "flame.fill"
            case .kindness: "heart.fill"
            }
        }
    }

    public let id: String
    public let category: Category
    public let text: String
}

/// Picks a daily, never-recently-repeated `Motivation` from the bundled
/// JSON. Day-anchored: the same quote stays for the whole calendar day,
/// then rolls over. The user can tap "refresh" to roll within the same day
/// (which still pushes the new ID into the recent set).
///
/// Persistence is `@AppStorage` so it survives launches without needing
/// SwiftData. Recent IDs are a comma-joined string of the last ~50 IDs we
/// surfaced; we never re-show one until it falls off the back.
@MainActor
public final class MotivationStore: ObservableObject {
    public static let shared = MotivationStore()

    /// Today's quote. Computed lazily on first access; refreshes when the
    /// calendar day flips or when the user explicitly asks for a new one.
    @Published public private(set) var current: Motivation?

    /// AI-generated quote (when the user taps "generate one with Companion").
    /// Layered on top of `current` and cleared on day flip.
    @Published public private(set) var aiOverride: String?

    /// Categories the user has hidden. Empty = all categories.
    @AppStorage("lumen.motivation.disabledCategories") private var disabledRaw: String = ""

    /// Calendar day key ("yyyy-MM-dd") of the currently displayed quote.
    @AppStorage("lumen.motivation.todayKey") private var todayKey: String = ""

    /// ID of the currently displayed quote.
    @AppStorage("lumen.motivation.currentID") private var currentID: String = ""

    /// Comma-joined list of IDs recently shown (newest at the back). Capped
    /// to `recentLimit` entries so we don't grow unbounded.
    @AppStorage("lumen.motivation.recentIDs") private var recentRaw: String = ""

    /// How many days of memory the rotation keeps before allowing a repeat.
    private static let recentLimit = 60

    /// Full bundled pool, exposed so adjacent helpers (e.g. the
    /// notification scheduler) can sample non-repeating quotes for future
    /// days without having to load the JSON themselves.
    public let all: [Motivation]

    public convenience init() {
        self.init(bundle: .module)
    }

    /// Designated initializer used by tests / previews to inject a custom
    /// bundle. The default `init()` always uses the package's own
    /// resource bundle.
    public init(bundle: Bundle) {
        self.all = Self.loadBundled(bundle: bundle)
        ensureFreshForToday()
    }

    /// Force a new quote within the same day. Also pushes the previous ID
    /// into the recent set so we don't immediately bounce back to it.
    public func reroll() {
        let next = pickNew()
        adopt(next)
    }

    /// Apply an AI-generated quote on top of today's bundled one.
    public func setAIOverride(_ text: String?) {
        aiOverride = text?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Replace the recent-IDs list with a fresh draw, ignoring the day
    /// anchor. Mostly here for tests / future "Reset history" toggles.
    public func resetHistory() {
        recentRaw = ""
        ensureFreshForToday(force: true)
    }

    /// Re-evaluates whether today's quote is stale. Called on init and any
    /// time the app comes back to the foreground.
    public func ensureFreshForToday(force: Bool = false) {
        let key = Self.dayKey(for: Date())
        if !force, key == todayKey, let existing = all.first(where: { $0.id == currentID }) {
            current = existing
            return
        }
        // Day flipped — clear any AI override so the user gets a fresh seed.
        aiOverride = nil
        let next = pickNew()
        adopt(next)
        todayKey = key
    }

    // MARK: - Private

    private func adopt(_ motivation: Motivation) {
        current = motivation
        currentID = motivation.id
        var recent = recentIDs
        recent.append(motivation.id)
        // Drop duplicates (in case we somehow re-seeded the same ID) and
        // trim from the front.
        let deduped = Array(NSOrderedSet(array: recent)) as? [String] ?? recent
        let trimmed = Array(deduped.suffix(Self.recentLimit))
        recentRaw = trimmed.joined(separator: ",")
    }

    private func pickNew() -> Motivation {
        let recent = Set(recentIDs)
        let disabled = Set(disabledRaw.split(separator: ",").map(String.init))
        let candidates = all.filter { m in
            !recent.contains(m.id) && !disabled.contains(m.category.rawValue)
        }
        // If the user has been very active, fall back to "anything not the
        // last one shown" so we don't produce no result.
        let pool = candidates.isEmpty
            ? all.filter { !disabled.contains($0.category.rawValue) && $0.id != currentID }
            : candidates
        return pool.randomElement() ?? all.randomElement()!
    }

    private var recentIDs: [String] {
        recentRaw.split(separator: ",").map(String.init)
    }

    private static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        return f.string(from: date)
    }

    private static func loadBundled(bundle: Bundle) -> [Motivation] {
        guard let url = bundle.url(forResource: "motivations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let parsed = try? JSONDecoder().decode([Motivation].self, from: data)
        else {
            // Fail soft: a tiny inline fallback so the card doesn't crash
            // if the resource ever fails to load.
            return [
                Motivation(id: "fb1", category: .focus, text: "One small win today is enough."),
                Motivation(id: "fb2", category: .gratitude, text: "Notice one good thing right now.")
            ]
        }
        return parsed
    }
}
