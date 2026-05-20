import Core
import DesignSystem
import SwiftUI
import WidgetKit

struct NextReminderEntry: TimelineEntry {
    let date: Date
    let reminder: ReminderSummary?
    let upcoming: [ReminderSummary]
}

struct ReminderSummary: Hashable {
    let id: String
    let title: String
    let dueAt: Date?
    let priority: Int
}

struct NextReminderProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextReminderEntry {
        .init(
            date: .now,
            reminder: ReminderSummary(
                id: "x",
                title: "Drink water",
                dueAt: .now.addingTimeInterval(600),
                priority: 1
            ),
            upcoming: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NextReminderEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextReminderEntry>) -> Void) {
        let entry = makeEntry()
        // Refresh either at the next reminder's due time or 15 min from now,
        // whichever is sooner. The app also calls
        // `WidgetCenter.shared.reloadAllTimelines()` after every mutation so
        // creates/edits show up without waiting for this fallback.
        let fallback = Date().addingTimeInterval(60 * 15)
        let dueRefresh = entry.reminder?.dueAt
        let nextRefresh: Date
        if let due = dueRefresh, due > Date(), due < fallback {
            nextRefresh = due
        } else {
            nextRefresh = fallback
        }
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func makeEntry() -> NextReminderEntry {
        MainActor.assumeIsolated {
            let reminder = SharedDataReader.nextReminder().map {
                ReminderSummary(id: $0.id.uuidString, title: $0.title, dueAt: $0.dueAt, priority: $0.priority)
            }
            let upcoming = SharedDataReader.upcomingReminders(limit: 4).map {
                ReminderSummary(id: $0.id.uuidString, title: $0.title, dueAt: $0.dueAt, priority: $0.priority)
            }
            return NextReminderEntry(date: .now, reminder: reminder, upcoming: upcoming)
        }
    }
}

struct NextReminderWidget: Widget {
    let kind = "lumen.widget.next-reminder"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextReminderProvider()) { entry in
            NextReminderWidgetView(entry: entry)
                .containerBackground(.ultraThinMaterial, for: .widget)
                .widgetURL(entry.reminder.flatMap { URL(string: "lumen://reminder/\($0.id)") })
        }
        .configurationDisplayName("Next Reminder")
        .description("Glance your next thing to remember.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

struct NextReminderWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.isLuminanceReduced) private var lowLuminance
    let entry: NextReminderEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .systemSmall:
            small
        default:
            medium
        }
    }

    private var inline: some View {
        Text(entry.reminder?.title ?? "All clear")
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "sparkles").font(.caption2)
                Text(entry.reminder?.dueAt?.formatted(.dateTime.hour().minute()) ?? "—")
                    .font(.system(size: 10).bold())
            }
        }
    }

    private var rectangular: some View {
        // Meteor-style checklist: top 2 active items with hollow circles, so a
        // glance at the lock screen tells you the next two things to do. Falls
        // back to a friendly empty-state when nothing's queued.
        let items = checklistItems
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                // The colored mascot doesn't read well on the
                // luminance-reduced lock screen; fall back to the SF
                // symbol there so the title stays legible.
                if lowLuminance {
                    Image(systemName: "sparkles").font(.system(size: 10, weight: .bold))
                } else {
                    LumiBrand(size: 12)
                }
                Text("Lumen").font(.system(size: 10, weight: .bold))
            }
            if items.isEmpty {
                Text("All clear today")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items.prefix(2), id: \.id) { item in
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                            .font(.system(size: 11, weight: .bold))
                        Text(item.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var checklistItems: [ReminderSummary] {
        var items: [ReminderSummary] = []
        if let next = entry.reminder { items.append(next) }
        for r in entry.upcoming where !items.contains(where: { $0.id == r.id }) {
            items.append(r)
            if items.count >= 2 { break }
        }
        return items
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                LumiBrand(size: 16)
                Text("Lumen").font(.caption.bold())
                Spacer()
            }
            if let r = entry.reminder {
                Text(r.title).font(.system(.subheadline, design: .rounded)).bold().lineLimit(2)
                if let due = r.dueAt {
                    Text(due, style: .relative).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                doneButton(for: r)
            } else {
                Spacer()
                Text("You're caught up.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .opacity(lowLuminance ? 0.7 : 1.0)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                LumiBrand(size: 16)
                Text("Lumen").font(.caption.bold())
                Spacer()
                if let r = entry.reminder {
                    doneButton(for: r)
                }
            }
            if let r = entry.reminder {
                Text(r.title).font(.headline).lineLimit(2)
                if let due = r.dueAt {
                    Text("Due \(due.formatted(.relative(presentation: .named)))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            ForEach(entry.upcoming.prefix(3), id: \.id) { r in
                HStack {
                    Circle().fill(priorityColor(r.priority)).frame(width: 6, height: 6)
                    Text(r.title).font(.caption).lineLimit(1)
                    Spacer()
                    if let due = r.dueAt {
                        Text(due, style: .time).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .opacity(lowLuminance ? 0.7 : 1.0)
    }

    private func doneButton(for reminder: ReminderSummary) -> some View {
        Button(intent: MarkReminderDoneIntent(reminderID: reminder.id)) {
            Image(systemName: "checkmark")
                .font(.caption.bold())
                .padding(6)
        }
        .buttonStyle(.plain)
        .background(Circle().fill(.thinMaterial))
        .accessibilityLabel("Mark \(reminder.title) done")
    }

    private func priorityColor(_ p: Int) -> Color {
        switch p {
        case 0: .green
        case 1: .yellow
        case 2: .orange
        default: .pink
        }
    }
}
