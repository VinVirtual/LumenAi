import Core
import DesignSystem
import SwiftUI

/// The Habits tab — tiny daily check-ins, streak tracking, templates,
/// tiny wins. Money is its own dedicated tab now, so this view is no
/// longer a segmented host.
public struct HabitsHomeView: View {
    @EnvironmentObject private var wellness: WellnessService
    @State private var showAddHabit = false
    @State private var showTemplates = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
                header
                StreakBoard(habits: wellness.habits)
                TodayProgressCard(habits: wellness.habits)
                HabitsCard(
                    habits: wellness.habits,
                    onAdd: { showAddHabit = true },
                    onTemplates: { showTemplates = true }
                )
                TinyWinsCard()
                SuggestionsCard()
            }
            .padding(Tokens.Spacing.l)
            .padding(.bottom, 140)
        }
        .task { await wellness.refresh() }
        .sheet(isPresented: $showAddHabit) {
            AddHabitSheet().presentationDetents([.fraction(0.55)])
        }
        .sheet(isPresented: $showTemplates) {
            HabitTemplatesSheet().presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Habits").font(Tokens.Typography.title)
            Text("Tiny daily wins. Lumen handles the streaks, you handle the showing up.")
                .font(Tokens.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Streak Board

private struct StreakBoard: View {
    let habits: [Habit]

    private var topStreak: Int { habits.map(\.streak).max() ?? 0 }
    private var totalActive: Int { habits.count }
    private var longest: Int { habits.map(\.longestStreak).max() ?? 0 }

    var body: some View {
        GlassCard(cornerRadius: 22) {
            HStack(spacing: 18) {
                Stat(label: "Streak", value: "\(topStreak)d", color: .orange)
                Divider().frame(height: 36)
                Stat(label: "Best", value: "\(longest)d", color: .purple)
                Divider().frame(height: 36)
                Stat(label: "Habits", value: "\(totalActive)", color: .cyan)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private struct Stat: View {
        let label: String
        let value: String
        let color: Color
        var body: some View {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Today progress

private struct TodayProgressCard: View {
    let habits: [Habit]

    private var doneToday: Int {
        habits.filter { habit in
            guard let last = habit.lastDoneAt else { return false }
            return Calendar.current.isDateInToday(last)
        }.count
    }

    private var ratio: Double {
        guard !habits.isEmpty else { return 0 }
        return Double(doneToday) / Double(habits.count)
    }

    var body: some View {
        if habits.isEmpty {
            EmptyView()
        } else {
            GlassCard(cornerRadius: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Today", systemImage: "sparkles")
                            .font(Tokens.Typography.titleSmall)
                        Spacer()
                        Text("\(doneToday) of \(habits.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: ratio)
                        .progressViewStyle(.linear)
                        .tint(.green)
                    Text(footnote)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var footnote: String {
        switch ratio {
        case 0: "Pick one habit and start with that. Momentum > perfection."
        case 1: "Perfect day! Streaks rolled forward."
        case 0.5...: "Halfway there — finish strong."
        default: "One step is enough."
        }
    }
}

// MARK: - Habits card

private struct HabitsCard: View {
    let habits: [Habit]
    let onAdd: () -> Void
    let onTemplates: () -> Void

    var body: some View {
        GlassCard(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                HStack {
                    Label("Habits", systemImage: "checkmark.circle")
                        .font(Tokens.Typography.titleSmall)
                    Spacer()
                    Button {
                        HapticEngine.shared.play(.tap)
                        onTemplates()
                    } label: {
                        Image(systemName: "square.grid.2x2")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Habit templates")
                    Button {
                        HapticEngine.shared.play(.tap)
                        onAdd()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New habit")
                }
                if habits.isEmpty {
                    EmptyHabitsHint(onTemplates: onTemplates)
                } else {
                    ForEach(habits) { habit in
                        HabitRow(habit: habit)
                    }
                }
            }
        }
    }
}

private struct EmptyHabitsHint: View {
    let onTemplates: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Build a streak.")
                .font(.subheadline.weight(.medium))
            Text("Pick a starter habit (water, meds, sleep, journal) — Lumen handles the daily check-in.")
                .font(.caption).foregroundStyle(.secondary)
            Button {
                HapticEngine.shared.play(.tap)
                onTemplates()
            } label: {
                Label("Browse templates", systemImage: "square.grid.2x2")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}

private struct HabitRow: View {
    let habit: Habit
    @State private var optimisticDoneToday: Bool?
    @State private var confirmDelete: Bool = false

    private var doneToday: Bool {
        if let opt = optimisticDoneToday { return opt }
        guard let last = habit.lastDoneAt else { return false }
        return Calendar.current.isDateInToday(last)
    }

    var body: some View {
        HStack {
            Image(systemName: habit.icon ?? "circle")
                .font(.title3)
                .foregroundStyle(doneToday ? Color.green : Color.primary)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(habit.title).font(.body)
                    if doneToday {
                        Text("Done")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.18), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }
                Text(streakLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                HapticEngine.shared.play(doneToday ? .tap : .success)
                let next = !doneToday
                withAnimation(.snappy(duration: 0.2)) { optimisticDoneToday = next }
                Task {
                    try? await WellnessService.shared.toggleHabit(habit)
                    withAnimation(.snappy(duration: 0.2)) { optimisticDoneToday = nil }
                }
            } label: {
                Image(systemName: doneToday ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(doneToday ? Color.green : Color.secondary)
                    .symbolEffect(.bounce, value: doneToday)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Label("Delete habit", systemImage: "trash")
            }
        }
        .alert("Delete this habit?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                Task { try? await WellnessService.shared.deleteHabit(habit) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Streak history for \"\(habit.title)\" will be removed.")
        }
    }

    private var streakLabel: String {
        let s = habit.streak
        if s == 0 { return "Start your streak today" }
        if s == 1 { return "1 day streak — keep going" }
        return "\(s) day streak"
    }
}

// MARK: - Tiny wins

private struct TinyWinsCard: View {
    @AppStorage("lumen.tinywins.lastNote") private var lastNote: String = ""
    @AppStorage("lumen.tinywins.lastDate") private var lastDate: String = ""
    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        GlassCard(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Tiny win today", systemImage: "trophy.fill")
                    .font(Tokens.Typography.titleSmall)
                Text("One sentence. The thing you're a little proud of.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("e.g. Walked instead of doomscrolling", text: $draft, axis: .vertical)
                    .focused($focused)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .submitLabel(.done)
                    .onSubmit(save)
                if !lastNote.isEmpty, !showsTodayDraft {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        Text(lastNote)
                            .font(.caption.italic())
                            .lineLimit(2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Spacer()
                    Button("Save win", action: save)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = false }
            }
        }
    }

    private var showsTodayDraft: Bool {
        lastDate == today
    }

    private var today: String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]
        return f.string(from: Date())
    }

    private func save() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lastNote = trimmed
        lastDate = today
        draft = ""
        focused = false
        HapticEngine.shared.play(.success)
    }
}

// MARK: - Suggestions

private struct SuggestionsCard: View {
    var body: some View {
        GlassCard(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Tiny ideas", systemImage: "lightbulb.fill")
                    .font(Tokens.Typography.titleSmall)
                ForEach(suggestions, id: \.title) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: item.icon)
                            .foregroundStyle(item.color)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.subheadline.weight(.semibold))
                            Text(item.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private struct Suggestion {
        let icon: String
        let color: Color
        let title: String
        let detail: String
    }

    private var suggestions: [Suggestion] {
        [
            Suggestion(icon: "drop.fill", color: .cyan,
                       title: "Hydration cue",
                       detail: "Add a Lumen reminder for water — 11am, 3pm, 7pm. Three sips, three taps."),
            Suggestion(icon: "moon.zzz.fill", color: .purple,
                       title: "Wind-down ritual",
                       detail: "Schedule \"Phone in another room\" 30 min before sleep target."),
            Suggestion(icon: "figure.walk", color: .green,
                       title: "Two-song walk",
                       detail: "After lunch, walk for the length of two songs. Tiny but consistent."),
            Suggestion(icon: "book.fill", color: .orange,
                       title: "Five page rule",
                       detail: "Open the book. Read five pages. That's the entire commitment."),
            Suggestion(icon: "heart.text.square.fill", color: .pink,
                       title: "Tell someone",
                       detail: "Send a quick text to someone you care about. Connection is wellness too.")
        ]
    }
}

// MARK: - Add Habit Sheet

private struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var icon = "drop.fill"
    @State private var isSaving = false
    @FocusState private var focused: Bool

    private let presets: [(label: String, icon: String, title: String)] = [
        ("Water", "drop.fill", "Drink water"),
        ("Sleep", "moon.zzz.fill", "Sleep 8h"),
        ("Meds", "pills.fill", "Take meds"),
        ("Move", "figure.walk", "Move 30 min"),
        ("Read", "book.fill", "Read 10 pages"),
        ("Journal", "square.and.pencil", "Journal"),
        ("Gratitude", "heart.fill", "1 gratitude")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick start") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(presets, id: \.label) { preset in
                                Button {
                                    title = preset.title
                                    icon = preset.icon
                                    HapticEngine.shared.play(.tap)
                                } label: {
                                    Label(preset.label, systemImage: preset.icon)
                                }
                                .buttonStyle(.bordered)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
                Section("Custom") {
                    TextField("Habit title", text: $title)
                        .focused($focused)
                    TextField("SF Symbol (optional)", text: $icon)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("New habit")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        isSaving = true
                        Task {
                            defer { isSaving = false }
                            try? await WellnessService.shared.addHabit(
                                title: title,
                                icon: icon.isEmpty ? nil : icon
                            )
                            HapticEngine.shared.play(.success)
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }
                }
            }
        }
    }
}

// MARK: - Templates sheet

private struct HabitTemplatesSheet: View {
    @Environment(\.dismiss) private var dismiss

    private struct Template: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let blurb: String
        let group: String
    }

    private let templates: [Template] = [
        .init(title: "Drink water", icon: "drop.fill", blurb: "8 cups a day, one tap each.", group: "Body"),
        .init(title: "Move 30 min", icon: "figure.walk", blurb: "Walk, stretch, dance — anything counts.", group: "Body"),
        .init(title: "Sleep 8h", icon: "moon.zzz.fill", blurb: "Track consistent bedtime.", group: "Body"),
        .init(title: "Take meds", icon: "pills.fill", blurb: "Daily medication / vitamins.", group: "Body"),
        .init(title: "Stretch 5 min", icon: "figure.flexibility", blurb: "Prevent the afternoon slump.", group: "Body"),
        .init(title: "Journal", icon: "square.and.pencil", blurb: "Two minutes, free-form.", group: "Mind"),
        .init(title: "Gratitude", icon: "heart.fill", blurb: "Name one thing you're thankful for.", group: "Mind"),
        .init(title: "Read 10 pages", icon: "book.fill", blurb: "Finish more books than last year.", group: "Mind"),
        .init(title: "No phone in bed", icon: "iphone.slash", blurb: "Phone outside the bedroom.", group: "Mind"),
        .init(title: "Tidy 5 min", icon: "sparkles", blurb: "Set timer, tidy until it dings.", group: "Home"),
        .init(title: "Cook at home", icon: "fork.knife", blurb: "Instead of ordering in.", group: "Home"),
        .init(title: "Plan tomorrow", icon: "calendar", blurb: "3 priorities for the next day.", group: "Mind"),
        .init(title: "Reach out", icon: "message.fill", blurb: "Text one friend, even briefly.", group: "Connect"),
        .init(title: "Sunlight", icon: "sun.max.fill", blurb: "10 min outdoors before noon.", group: "Body")
    ]

    private var groups: [String] { Array(NSOrderedSet(array: templates.map(\.group))) as? [String] ?? [] }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups, id: \.self) { group in
                    Section(group) {
                        ForEach(templates.filter { $0.group == group }) { tpl in
                            Button {
                                Task {
                                    try? await WellnessService.shared.addHabit(title: tpl.title, icon: tpl.icon)
                                    HapticEngine.shared.play(.success)
                                    dismiss()
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: tpl.icon)
                                        .frame(width: 28)
                                        .foregroundStyle(.cyan)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tpl.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(tpl.blurb)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Habit templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
