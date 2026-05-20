import Core
import DesignSystem
import SwiftUI
import WidgetKit

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let goal: Int
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        .init(date: .now, streak: 7, goal: 14)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let next = Calendar.current.startOfDay(for: .now.addingTimeInterval(86400))
        completion(Timeline(entries: [makeEntry()], policy: .after(next)))
    }

    private func makeEntry() -> StreakEntry {
        let defaults = UserDefaults(suiteName: AppConfig.shared.appGroup)
        let streak = defaults?.integer(forKey: "lumen.streak") ?? 0
        let goal = max(7, streak + 7)
        return StreakEntry(date: .now, streak: streak, goal: goal)
    }
}

struct StreakWidget: Widget {
    let kind = "lumen.widget.streak"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Streak")
        .description("Keep your habits on track.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct StreakView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakEntry

    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                Gauge(value: Double(entry.streak), in: 0...Double(entry.goal)) {
                    Image(systemName: "flame.fill")
                } currentValueLabel: {
                    Text("\(entry.streak)").font(.caption2.bold())
                }
                .gaugeStyle(.accessoryCircular)
            }
        } else {
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    LumiBrand(size: 16)
                    Label("Streak", systemImage: "flame.fill").font(.caption.bold())
                }
                Spacer()
                Text("\(entry.streak)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text("of \(entry.goal)-day goal")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
