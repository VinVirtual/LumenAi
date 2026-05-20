import Core
import DesignSystem
import SwiftUI

/// The big, can't-miss card at the top of the Today screen. Always shows the
/// single next active reminder with a live countdown so the user can glance
/// at the screen and instantly know what's next.
public struct HeroNextCard: View {
    let entity: ReminderEntity?
    let now: Date
    let onMarkDone: () -> Void
    let onSnooze: () -> Void
    let onTap: () -> Void

    public init(
        entity: ReminderEntity?,
        now: Date,
        onMarkDone: @escaping () -> Void,
        onSnooze: @escaping () -> Void,
        onTap: @escaping () -> Void
    ) {
        self.entity = entity
        self.now = now
        self.onMarkDone = onMarkDone
        self.onSnooze = onSnooze
        self.onTap = onTap
    }

    public var body: some View {
        if let entity {
            content(for: entity)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
        } else {
            emptyHero
        }
    }

    @ViewBuilder
    private func content(for entity: ReminderEntity) -> some View {
        let due = entity.dueAt
        let countdown = countdownLabel(for: due)
        let countdownColor = countdownTone(for: due)

        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(LinearGradient(
                                colors: [.purple.opacity(0.6), .cyan.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 24, y: 12)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "alarm.fill")
                            .font(.caption)
                            .foregroundStyle(LinearGradient(
                                colors: [.purple, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        Text("Next up").font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(1.2)
                        Spacer()
                        priorityBadge(for: entity.priority)
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

                    Text(countdown)
                        .font(.system(.title3, design: .rounded).weight(.medium).monospacedDigit())
                        .foregroundStyle(countdownColor)
                        .contentTransition(.numericText())

                    HStack(spacing: 10) {
                        Button {
                            HapticEngine.shared.play(.success)
                            onMarkDone()
                        } label: {
                            Label("Done", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.green.opacity(0.85), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            HapticEngine.shared.play(.tap)
                            onSnooze()
                        } label: {
                            Label("Snooze 10m", systemImage: "moon.zzz.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.thinMaterial, in: Capsule())
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 28))
    }

    private var emptyHero: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36))
                .foregroundStyle(LinearGradient(
                    colors: [.green, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Text("You're all caught up").font(.headline)
            Text("No upcoming alarms. Tap + to add the next thing.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
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

    private func countdownLabel(for due: Date?) -> String {
        guard let due else { return "No alarm scheduled" }
        let delta = Int(due.timeIntervalSince(now))
        if delta > 0 {
            return "Rings in \(formatDelta(delta))"
        } else if delta > -60 {
            return "Ringing now"
        } else {
            return "\(formatDelta(-delta)) overdue"
        }
    }

    private func countdownTone(for due: Date?) -> Color {
        guard let due else { return .secondary }
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
}
