import DesignSystem
import SwiftUI
import WidgetKit

struct QuickAddEntry: TimelineEntry {
    let date: Date
}

struct QuickAddProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry { QuickAddEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(QuickAddEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        completion(Timeline(entries: [QuickAddEntry(date: .now)], policy: .never))
    }
}

/// Two-button shortcut widget: tap "Note" or "Alarm" to jump straight into the
/// Lumen composer pre-set to that kind. Uses widgetURL fallbacks for
/// accessory families that don't support buttons (e.g. lock screen).
struct QuickAddWidget: Widget {
    let kind = "lumen.widget.quick-add"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickAddProvider()) { _ in
            QuickAddWidgetView()
                .containerBackground(.ultraThinMaterial, for: .widget)
        }
        .configurationDisplayName("Quick Add")
        .description("Tap to jot a note or set an alarm.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryRectangular, .accessoryCircular
        ])
    }
}

struct QuickAddWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Link(destination: URL(string: "lumen://compose?kind=note")!) {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                }
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Link(destination: URL(string: "lumen://compose?kind=note")!) {
                    Label("Note", systemImage: "note.text").font(.caption.bold())
                }
                Link(destination: URL(string: "lumen://compose?kind=alarm")!) {
                    Label("Alarm", systemImage: "alarm.fill").font(.caption.bold())
                }
            }
        case .systemSmall:
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    LumiBrand(size: 16)
                    Text("Quick Add").font(.caption.bold())
                }
                Link(destination: URL(string: "lumen://compose?kind=note")!) {
                    quickButton(title: "Note", system: "note.text")
                }
                Link(destination: URL(string: "lumen://compose?kind=alarm")!) {
                    quickButton(title: "Alarm", system: "alarm.fill")
                }
            }
            .padding(4)
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    LumiBrand(size: 16)
                    Text("Quick Add").font(.caption.bold())
                    Spacer()
                }
                HStack(spacing: 12) {
                    Link(destination: URL(string: "lumen://compose?kind=note")!) {
                        quickButton(title: "New note", system: "note.text", expanded: true)
                    }
                    Link(destination: URL(string: "lumen://compose?kind=alarm")!) {
                        quickButton(title: "New alarm", system: "alarm.fill", expanded: true)
                    }
                }
            }
            .padding(8)
        }
    }

    private func quickButton(title: String, system: String, expanded: Bool = false) -> some View {
        HStack {
            Image(systemName: system)
            Text(title)
            if expanded { Spacer() }
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: expanded ? .infinity : nil)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
