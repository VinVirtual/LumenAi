import Core
import DesignSystem
import SwiftUI
import WidgetKit

struct PinnedNoteEntry: TimelineEntry {
    let date: Date
    let title: String?
    let body: String?
    let updatedAt: Date?
    let isPinned: Bool
}

struct PinnedNoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> PinnedNoteEntry {
        PinnedNoteEntry(
            date: .now,
            title: "Bring earbuds",
            body: "Standup at 10:30 today.",
            updatedAt: .now,
            isPinned: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PinnedNoteEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PinnedNoteEntry>) -> Void) {
        let entry = makeEntry()
        // Notes don't expire; refresh hourly so a freshly pinned note shows up
        // even if the app forgot to call reloadAllTimelines for some reason.
        let next = Date().addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> PinnedNoteEntry {
        MainActor.assumeIsolated {
            guard let note = SharedDataReader.pinnedNote() else {
                return PinnedNoteEntry(date: .now, title: nil, body: nil, updatedAt: nil, isPinned: false)
            }
            return PinnedNoteEntry(
                date: .now,
                title: note.title,
                body: note.body,
                updatedAt: note.updatedAt,
                isPinned: note.isPinned
            )
        }
    }
}

struct PinnedNoteWidget: Widget {
    let kind = "lumen.widget.pinned-note"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PinnedNoteProvider()) { entry in
            PinnedNoteWidgetView(entry: entry)
                .containerBackground(.ultraThinMaterial, for: .widget)
                .widgetURL(URL(string: "lumen://notes"))
        }
        .configurationDisplayName("Pinned Note")
        .description("A note you pinned, always on your lock screen.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryRectangular, .accessoryInline
        ])
    }
}

struct PinnedNoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.isLuminanceReduced) private var lowLuminance
    let entry: PinnedNoteEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(entry.title ?? "Pin a note in Lumen")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if !lowLuminance {
                        LumiBrand(size: 12)
                    }
                    Label(entry.title ?? "No pinned note", systemImage: entry.isPinned ? "pin.fill" : "note.text")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                }
                if let body = entry.body, !body.isEmpty {
                    Text(body).font(.caption2).lineLimit(2).foregroundStyle(.secondary)
                }
            }
        case .systemSmall:
            small
        default:
            medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                LumiBrand(size: 16)
                Image(systemName: entry.isPinned ? "pin.fill" : "note.text").font(.caption)
                Text("Note").font(.caption.bold())
                Spacer()
            }
            if let title = entry.title {
                Text(title).font(.system(.subheadline, design: .rounded).weight(.semibold)).lineLimit(3)
                if let body = entry.body, !body.isEmpty {
                    Text(body).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
            } else {
                Spacer()
                Text("Pin a note in Lumen to see it here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                LumiBrand(size: 16)
                Label("Pinned note", systemImage: entry.isPinned ? "pin.fill" : "note.text")
                    .font(.caption.bold())
                Spacer()
                if let updated = entry.updatedAt {
                    Text(updated, style: .relative).font(.caption2).foregroundStyle(.secondary)
                }
            }
            if let title = entry.title {
                Text(title).font(.headline).lineLimit(2)
                if let body = entry.body, !body.isEmpty {
                    Text(body).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }
            } else {
                Text("Pin a note in Lumen to glance it here.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
