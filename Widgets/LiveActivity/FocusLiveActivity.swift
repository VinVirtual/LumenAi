import ActivityKit
import AppIntents
import Core
import DesignSystem
import SwiftUI
import WidgetKit

/// Lock-screen + Dynamic Island presentation for the running Lumen focus
/// session. The countdown uses `Text(timerInterval:)` so the system
/// renders a ticking display without us having to update every second.
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            FocusLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: glyph(for: context.state.mode))
                        .foregroundStyle(.orange)
                        .font(.title3)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.paused, let remaining = context.state.pausedRemaining {
                        Text(formatted(remaining))
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.white)
                    } else {
                        Text(timerInterval: Date()...context.state.endsAt, countsDown: true)
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.label)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        Button(intent: PauseFocusIntent()) {
                            Label(context.state.paused ? "Resume" : "Pause",
                                  systemImage: context.state.paused ? "play.fill" : "pause.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        Button(intent: EndFocusIntent()) {
                            Label("End", systemImage: "stop.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
            } compactLeading: {
                Image(systemName: glyph(for: context.state.mode))
                    .foregroundStyle(.orange)
            } compactTrailing: {
                if context.state.paused, let remaining = context.state.pausedRemaining {
                    Text(formatted(remaining))
                        .font(.caption2.monospacedDigit())
                } else {
                    Text(timerInterval: Date()...context.state.endsAt, countsDown: true)
                        .font(.caption2.monospacedDigit())
                        .frame(maxWidth: 56)
                }
            } minimal: {
                Image(systemName: glyph(for: context.state.mode))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func glyph(for mode: FocusActivityAttributes.ContentState.Mode) -> String {
        switch mode {
        case .focus: return "circle.dotted"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "leaf.fill"
        }
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

private struct FocusLockScreenView: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Countdown ring
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.18), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: glyph)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    LumiBrand(size: 12)
                    Text(context.attributes.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                if context.state.paused, let remaining = context.state.pausedRemaining {
                    Text(formatted(remaining))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("Paused")
                        .font(.caption2)
                        .foregroundStyle(.orange.opacity(0.85))
                } else {
                    Text(timerInterval: Date()...context.state.endsAt, countsDown: true)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
            Spacer()
            VStack(spacing: 6) {
                Button(intent: PauseFocusIntent()) {
                    Image(systemName: context.state.paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.15), in: Circle())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Button(intent: EndFocusIntent()) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(.red.opacity(0.85), in: Circle())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    /// Approximate ring fill: uses `pausedRemaining` while paused, else
    /// time-to-endsAt against `totalDuration`.
    private var progress: Double {
        let total = max(1, context.attributes.totalDuration)
        let remaining: TimeInterval
        if context.state.paused, let r = context.state.pausedRemaining {
            remaining = r
        } else {
            remaining = max(0, context.state.endsAt.timeIntervalSinceNow)
        }
        let ratio = 1 - (remaining / total)
        return min(1, max(0, ratio))
    }

    private var glyph: String {
        switch context.state.mode {
        case .focus: return "circle.dotted"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "leaf.fill"
        }
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
