import ActivityKit
import AppIntents
import DesignSystem
import Reminders
import SwiftUI
import WidgetKit

/// Persistent lock-screen card. Looks like a notification but doesn't
/// dismiss until the user manually unpins everything (or the system reaps
/// after ~8 hours, at which point the next app open re-pins it).
///
/// Lock-screen variant is interactive:
///   * Each row has a hollow circle that fires `MarkLumenItemDoneIntent`
///     so the user can check things off without unlocking.
///   * A "+ Note" / "+ Todo" footer fires `OpenLumenComposerIntent` to
///     bounce them straight into the right composer.
///
/// Dynamic Island variant is intentionally minimal -- compact/minimal
/// regions render `Color.clear` so the pill is barely visible. iOS still
/// reserves the slot while a Live Activity is alive; the in-app help sheet
/// points users at Settings > Notifications > Lumen > Live Activities >
/// Show on Dynamic Island = Off if they want it gone entirely.
struct LumenPinLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LumenPinAttributes.self) { context in
            LumenPinLockView(items: context.state.items)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.items.count)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(context.state.items.prefix(3)) { item in
                            HStack(spacing: 8) {
                                Button(intent: MarkLumenItemDoneIntent(itemID: item.id)) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .buttonStyle(.plain)
                                .tint(.white)
                                Text(item.title)
                                    .lineLimit(1)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                            }
                        }
                        HStack(spacing: 8) {
                            ComposerChip(kind: "note", label: "Note", icon: "note.text")
                            ComposerChip(kind: "task", label: "Todo", icon: "checklist")
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                }
            } compactLeading: {
                Color.clear.frame(width: 1, height: 1)
            } compactTrailing: {
                Color.clear.frame(width: 1, height: 1)
            } minimal: {
                Color.clear.frame(width: 1, height: 1)
            }
        }
    }
}

/// Interactive lock-screen card -- mark-done buttons per row, composer
/// chips at the bottom. Mirrors Apple's Reminders Live Activity UX, but
/// scales gracefully when the user has more than 3 active items: rows
/// tighten and a "+N more" footer indicates overflow.
struct LumenPinLockView: View {
    let items: [LumenPinAttributes.ContentState.Item]

    /// We always render at most this many rows. Anything past the limit
    /// gets summarised in the footer to keep the lock-screen card from
    /// pushing other notifications off-screen.
    private let displayLimit = 5

    private var visibleItems: [LumenPinAttributes.ContentState.Item] {
        Array(items.prefix(displayLimit))
    }

    private var overflowCount: Int {
        max(0, items.count - displayLimit)
    }

    /// Shrink row spacing when many items so the card stays compact.
    private var rowSpacing: CGFloat { items.count > 3 ? 4 : 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if items.isEmpty {
                emptyBody
            } else {
                VStack(alignment: .leading, spacing: rowSpacing) {
                    ForEach(visibleItems) { item in
                        ItemRow(item: item, dense: items.count > 3)
                    }
                    if overflowCount > 0 {
                        Link(destination: URL(string: "lumen://notes")!) {
                            Text("+\(overflowCount) more in Lumen")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange.opacity(0.95))
                        }
                    }
                }
                composerRow.padding(.top, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var header: some View {
        HStack(spacing: 6) {
            LumiBrand(size: 14)
            Text("Lumen")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            if !items.isEmpty {
                Text("\(items.count)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            Image(systemName: "pin.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange.opacity(0.85))
        }
    }

    private var emptyBody: some View {
        HStack {
            Text("All clear")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            composerRow
        }
    }

    private var composerRow: some View {
        HStack(spacing: 8) {
            ComposerChip(kind: "note", label: "Note", icon: "note.text")
            ComposerChip(kind: "task", label: "Todo", icon: "checklist")
            Spacer()
        }
    }
}

private struct ItemRow: View {
    let item: LumenPinAttributes.ContentState.Item
    let dense: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Tap the circle = mark done in place (intent, no app open).
            Button(intent: MarkLumenItemDoneIntent(itemID: item.id)) {
                Image(systemName: glyph)
                    .font(.system(size: dense ? 14 : 16, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .tint(.white)

            // Tap the title = open the item in the app via an intent.
            // `Link(destination:)` was unreliable inside Live Activities on
            // iOS 17 (silently no-op'd for some users); `Button(intent:)`
            // with `openAppWhenRun = true` is the official replacement.
            Button(intent: OpenLumenItemIntent(itemID: item.id)) {
                HStack(spacing: 6) {
                    if let glyphForKind = kindIndicator {
                        Image(systemName: glyphForKind)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: dense ? 13 : 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if !dense, let subtitle = item.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                        } else if !dense, let due = item.dueAt {
                            Text(due, style: .time)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var glyph: String {
        switch item.kind {
        case .note: return "circle.dotted"
        case .reminder: return "circle"
        case .task: return "square"
        }
    }

    private var tint: Color {
        switch item.kind {
        case .note: return .orange
        case .reminder: return .white
        case .task: return .white
        }
    }

    /// Tiny pre-title glyph so users can tell note/task/reminder apart at a
    /// glance when the row is dense.
    private var kindIndicator: String? {
        switch item.kind {
        case .note: return "note.text"
        case .reminder: return "alarm.fill"
        case .task: return "checklist"
        }
    }
}

/// Pill-shaped button that fires `OpenLumenComposerIntent` -- the only way
/// to "type" something from the lock screen since iOS bans text fields in
/// Live Activities.
private struct ComposerChip: View {
    let kind: String
    let label: String
    let icon: String

    var body: some View {
        Button(intent: OpenLumenComposerIntent(kind: kind)) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(.white)
            .background(.white.opacity(0.18), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
