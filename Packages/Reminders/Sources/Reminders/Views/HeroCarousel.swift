import Core
import DesignSystem
import SwiftUI

/// Swipeable Today hero. Shows the most relevant active items front and
/// centre: the next reminder, the next task, pinned notes, etc. The user
/// scrubs horizontally through them to see "everything important right
/// now" without leaving the Today tab.
public struct HeroCarousel: View {
    let entities: [ReminderEntity]
    let now: Date
    let onMarkDone: (ReminderEntity) -> Void
    let onSnooze: (ReminderEntity) -> Void
    let onTogglePin: (ReminderEntity) -> Void
    let onTap: (ReminderEntity) -> Void

    @State private var currentIndex: Int = 0

    public init(
        entities: [ReminderEntity],
        now: Date,
        onMarkDone: @escaping (ReminderEntity) -> Void,
        onSnooze: @escaping (ReminderEntity) -> Void,
        onTogglePin: @escaping (ReminderEntity) -> Void,
        onTap: @escaping (ReminderEntity) -> Void
    ) {
        self.entities = entities
        self.now = now
        self.onMarkDone = onMarkDone
        self.onSnooze = onSnooze
        self.onTogglePin = onTogglePin
        self.onTap = onTap
    }

    public var body: some View {
        if entities.isEmpty {
            HeroEmptyCard()
        } else {
            VStack(spacing: 8) {
                TabView(selection: $currentIndex) {
                    ForEach(Array(entities.enumerated()), id: \.element.id) { index, entity in
                        HeroSlideCard(
                            entity: entity,
                            now: now,
                            onMarkDone: { onMarkDone(entity) },
                            onSnooze: { onSnooze(entity) },
                            onTogglePin: { onTogglePin(entity) },
                            onTap: { onTap(entity) }
                        )
                        .padding(.horizontal, 2)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 270)
                if entities.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<entities.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentIndex ? Color.primary : Color.secondary.opacity(0.3))
                                .frame(width: i == currentIndex ? 16 : 6, height: 4)
                                .animation(.spring(duration: 0.25), value: currentIndex)
                        }
                    }
                    .padding(.top, 2)
                    Text("\(currentIndex + 1) of \(entities.count) — swipe for more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: entities.map(\.id)) { _, _ in
                if currentIndex >= entities.count { currentIndex = max(0, entities.count - 1) }
            }
        }
    }
}

/// Single slide. Picks chrome by `entity.kind` so a pinned note doesn't
/// pretend to be an alarm.
private struct HeroSlideCard: View {
    let entity: ReminderEntity
    let now: Date
    let onMarkDone: () -> Void
    let onSnooze: () -> Void
    let onTogglePin: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(strokeGradient, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 24, y: 12)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: kindIcon)
                            .font(.caption)
                            .foregroundStyle(strokeGradient)
                        Text(kindLabel).font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(1.2)
                        Spacer()
                        if entity.kind != .note {
                            priorityBadge(for: entity.priority)
                        } else if entity.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(entity.title)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)

                    if let body = entity.body, !body.isEmpty {
                        Text(body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if entity.kind != .note {
                        Text(countdownLabel)
                            .font(.system(.title3, design: .rounded).weight(.medium).monospacedDigit())
                            .foregroundStyle(countdownTone)
                            .contentTransition(.numericText())
                    }

                    actions
                }
                .padding(20)
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 28))
    }

    @ViewBuilder
    private var actions: some View {
        switch entity.kind {
        case .reminder:
            HStack(spacing: 10) {
                actionButton(label: "Done", icon: "checkmark.circle.fill", tint: .green) {
                    HapticEngine.shared.play(.success); onMarkDone()
                }
                actionButton(label: "Snooze 10m", icon: "moon.zzz.fill", tint: .clear) {
                    HapticEngine.shared.play(.tap); onSnooze()
                }
            }
        case .task:
            HStack(spacing: 10) {
                actionButton(label: "Mark done", icon: "checkmark.square.fill", tint: .green) {
                    HapticEngine.shared.play(.success); onMarkDone()
                }
                actionButton(label: "Open", icon: "arrow.up.right.square", tint: .clear) {
                    HapticEngine.shared.play(.tap); onTap()
                }
            }
        case .note:
            HStack(spacing: 10) {
                actionButton(
                    label: entity.isPinned ? "Unpin" : "Pin",
                    icon: entity.isPinned ? "pin.slash.fill" : "pin.fill",
                    tint: .orange
                ) {
                    HapticEngine.shared.play(.tap); onTogglePin()
                }
                actionButton(label: "Open", icon: "arrow.up.right.square", tint: .clear) {
                    HapticEngine.shared.play(.tap); onTap()
                }
            }
        }
    }

    private func actionButton(label: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(tint == .clear ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(tint.opacity(0.85)),
                            in: Capsule())
                .foregroundStyle(tint == .clear ? Color.primary : Color.white)
        }
        .buttonStyle(.plain)
    }

    private var kindIcon: String {
        switch entity.kind {
        case .note: return "note.text"
        case .reminder: return "alarm.fill"
        case .task: return "checklist"
        }
    }

    private var kindLabel: String {
        switch entity.kind {
        case .note: return entity.isPinned ? "Pinned note" : "Note"
        case .reminder: return "Next up"
        case .task: return "To do"
        }
    }

    private var strokeGradient: LinearGradient {
        switch entity.kind {
        case .note:
            return LinearGradient(
                colors: [.orange.opacity(0.7), .yellow.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .reminder:
            return LinearGradient(
                colors: [.purple.opacity(0.6), .cyan.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .task:
            return LinearGradient(
                colors: [.blue.opacity(0.6), .green.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    private var countdownLabel: String {
        guard let due = entity.dueAt else { return "No date" }
        let delta = Int(due.timeIntervalSince(now))
        if delta > 0 {
            return entity.kind == .task ? "Due in \(formatDelta(delta))" : "Rings in \(formatDelta(delta))"
        } else if delta > -60 {
            return entity.kind == .task ? "Due now" : "Ringing now"
        } else {
            return "\(formatDelta(-delta)) overdue"
        }
    }

    private var countdownTone: Color {
        guard let due = entity.dueAt else { return .secondary }
        let delta = due.timeIntervalSince(now)
        if delta < -60 { return .pink }
        if delta < 60 { return .orange }
        if delta < 60 * 10 { return .yellow }
        return .secondary
    }

    private func formatDelta(_ seconds: Int) -> String {
        let s = seconds % 60
        let m = (seconds / 60) % 60
        let h = (seconds / 3_600) % 24
        let d = seconds / 86_400
        if d > 0 { return d == 1 ? "1 day" : "\(d) days" }
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return "\(s)s"
    }

    private func priorityBadge(for priority: Int) -> some View {
        let label: String
        let color: Color
        switch priority {
        case 0: label = "Low"; color = .green
        case 1: label = "Medium"; color = .yellow
        case 2: label = "High"; color = .orange
        default: label = "Critical"; color = .pink
        }
        return Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.25), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct HeroEmptyCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36))
                .foregroundStyle(LinearGradient(
                    colors: [.green, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Text("You're all caught up").font(.headline)
            Text("No pinned notes, reminders, or to-dos right now. Tap + to add the next thing.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
    }
}
