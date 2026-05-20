import ActivityKit
import DesignSystem
import Reminders
import SwiftUI
import WidgetKit

struct ReminderLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderActivityAttributes.self) { context in
            // Lock screen / banner UI
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.dueAt, style: .timer)
                        .monospacedDigit()
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if !context.state.sharedWith.isEmpty {
                            Image(systemName: "person.2.fill")
                            Text(context.state.sharedWith.prefix(3).joined(separator: ", "))
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button(intent: MarkReminderDoneIntent(reminderID: context.attributes.reminderID)) {
                            Label("Done", systemImage: "checkmark")
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                    }
                }
            } compactLeading: {
                Image(systemName: "sparkles").foregroundStyle(.tint)
            } compactTrailing: {
                Text(context.state.dueAt, style: .timer)
                    .monospacedDigit()
                    .frame(maxWidth: 50)
            } minimal: {
                Image(systemName: "sparkles").foregroundStyle(.tint)
            }
        }
    }
}

private struct LockScreenView: View {
    @Environment(\.isLuminanceReduced) private var lowLum
    let context: ActivityViewContext<ReminderActivityAttributes>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    // Mascot reads as "Lumen" when the lock screen is at full
                    // luminance; under reduced-luminance the colored asset
                    // turns into a smudge so we fall back to the SF symbol.
                    if lowLum {
                        Image(systemName: "sparkles").font(.caption.bold())
                    } else {
                        LumiBrand(size: 14)
                    }
                    Text(context.attributes.personaName).font(.caption.bold())
                }
                Text(context.state.title).font(.headline).lineLimit(1)
                Text(context.state.dueAt, style: .timer)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(intent: MarkReminderDoneIntent(reminderID: context.attributes.reminderID)) {
                Image(systemName: "checkmark")
                    .padding(8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(12)
        .opacity(lowLum ? 0.7 : 1.0)
    }
}
