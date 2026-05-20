import Core
import DesignSystem
import SwiftUI

/// Composer for new reminders. Shows the title field, an inline alarm row
/// (toggle + date picker + chips), priority, and a live preview describing
/// when it'll ring. The natural-language parser still runs against the title
/// in the background, but anything the user explicitly picks here wins.
public struct QuickAddSheet: View {
    @Binding var text: String
    @Binding var pickedDate: Date?
    @Binding var priority: Int
    @Binding var kind: ReminderKind
    @Binding var isPinned: Bool
    let onCommit: () -> Void

    @State private var alarmOn: Bool
    @State private var date: Date
    @FocusState private var focused: Bool

    public init(
        text: Binding<String>,
        pickedDate: Binding<Date?> = .constant(nil),
        priority: Binding<Int> = .constant(0),
        kind: Binding<ReminderKind> = .constant(.reminder),
        isPinned: Binding<Bool> = .constant(false),
        onCommit: @escaping () -> Void
    ) {
        _text = text
        _pickedDate = pickedDate
        _priority = priority
        _kind = kind
        _isPinned = isPinned
        self.onCommit = onCommit
        let initial = pickedDate.wrappedValue ?? Date().addingTimeInterval(60 * 60)
        _alarmOn = State(initialValue: pickedDate.wrappedValue != nil)
        _date = State(initialValue: initial)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
                Text(headline).font(.title2.weight(.semibold))

                kindPicker

                TextField(titlePlaceholder, text: $text, axis: .vertical)
                    .textFieldStyle(GlassFieldStyle())
                    .focused($focused)
                    .lineLimit(1...4)
                    .submitLabel(.done)

                if kind == .reminder { alarmCard }
                if kind == .task { taskDueCard }
                if kind == .note { noteCard }
                if kind == .reminder { priorityCard }

                preview

                PrimaryButton(action: commit) { Text(commitLabel) }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer(minLength: 24)
            }
            .padding(Tokens.Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = false }
            }
        }
        .onAppear {
            focused = true
            syncBindings()
        }
        .onChange(of: alarmOn) { _, _ in syncBindings() }
        .onChange(of: date) { _, _ in syncBindings() }
        .onChange(of: kind) { _, _ in syncBindings() }
    }

    private var headline: String {
        switch kind {
        case .note: "New note"
        case .reminder: "New reminder"
        case .task: "New task"
        }
    }

    private var titlePlaceholder: String {
        switch kind {
        case .note: "Jot a thought…"
        case .reminder: "What do you want to remember?"
        case .task: "What needs doing?"
        }
    }

    private var commitLabel: String {
        switch kind {
        case .note: isPinned ? "Pin to lock screen" : "Save note"
        case .reminder: "Add reminder"
        case .task: "Add task"
        }
    }

    private var kindPicker: some View {
        Picker("Kind", selection: $kind.animation(.spring(duration: 0.25))) {
            Label("Note", systemImage: "note.text").tag(ReminderKind.note)
            Label("Reminder", systemImage: "alarm").tag(ReminderKind.reminder)
            Label("Task", systemImage: "checkmark.circle").tag(ReminderKind.task)
        }
        .pickerStyle(.segmented)
    }

    private var noteCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $isPinned.animation(.spring(duration: 0.25))) {
                    Label {
                        Text("Pin to lock screen").font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "pin.fill").foregroundStyle(.orange)
                    }
                }
                Text(isPinned
                    ? "This note will show on the lock screen widget. You can unpin from the Notes tab."
                    : "Notes live in the Notes tab. Pin one to keep it on your lock screen.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var taskDueCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $alarmOn.animation(.spring(duration: 0.25))) {
                    Label {
                        Text("Set due date").font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "calendar").foregroundStyle(.cyan)
                    }
                }
                if alarmOn {
                    DatePicker("Due", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                } else {
                    Text("Tasks without a due date sit at the bottom of the list until you check them off.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Sub-cards

    private var alarmCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $alarmOn.animation(.spring(duration: 0.25))) {
                    Label {
                        Text("Alarm").font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "alarm.fill")
                            .foregroundStyle(LinearGradient(
                                colors: [.purple, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    }
                }

                if alarmOn {
                    DatePicker(
                        "When",
                        selection: $date,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)

                    chips
                } else {
                    Text("This reminder will live in your list but won't ring.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("In 5m") { date = Date().addingTimeInterval(5 * 60) }
                chip("In 15m") { date = Date().addingTimeInterval(15 * 60) }
                chip("In 1h") { date = Date().addingTimeInterval(60 * 60) }
                chip("Tonight 8pm") { date = todayAt(hour: 20) }
                chip("Tomorrow 9am") { date = tomorrowAt(hour: 9) }
            }
        }
    }

    private func chip(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(duration: 0.2)) { action() }
            HapticEngine.shared.play(.tap)
        } label: {
            Text(label).font(.caption.weight(.medium))
        }
        .buttonStyle(.bordered)
        .clipShape(Capsule())
    }

    private var priorityCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("Priority").font(.subheadline.weight(.semibold))
                } icon: {
                    Image(systemName: "flag.fill").foregroundStyle(.orange)
                }
                Picker("Priority", selection: $priority) {
                    Text("Low").tag(0)
                    Text("Med").tag(1)
                    Text("High").tag(2)
                    Text("Critical").tag(3)
                }
                .pickerStyle(.segmented)
                Text(priority >= 2
                    ? "High/Critical plays a louder bell and repeats every minute for 5 min."
                    : "Plays the iOS default chime once.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var preview: some View {
        HStack(spacing: 8) {
            Image(systemName: alarmOn ? "alarm.fill" : "alarm.waves.left.and.right")
                .foregroundStyle(alarmOn ? .green : .secondary)
            Text(previewText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var previewText: String {
        switch kind {
        case .note:
            return isPinned ? "Pinned note — visible on the lock screen widget." : "Saved as a note."
        case .task:
            if !alarmOn { return "Task with no due date." }
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .full
            return "Due \(f.localizedString(for: date, relativeTo: Date()))"
        case .reminder:
            if !alarmOn {
                return "Saved without an alarm."
            }
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .full
            let when = f.localizedString(for: date, relativeTo: Date())
            return "Rings \(when) (\(date.formatted(.dateTime.weekday(.abbreviated).hour().minute())))"
        }
    }

    // MARK: - Helpers

    private func syncBindings() {
        switch kind {
        case .note:
            pickedDate = nil
        case .reminder, .task:
            pickedDate = alarmOn ? date : nil
        }
    }

    private func commit() {
        syncBindings()
        onCommit()
    }

    private func todayAt(hour: Int) -> Date {
        let cal = Calendar.current
        var c = cal.dateComponents([.year, .month, .day], from: Date())
        c.hour = hour
        return cal.date(from: c) ?? Date()
    }

    private func tomorrowAt(hour: Int) -> Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var c = cal.dateComponents([.year, .month, .day], from: tomorrow)
        c.hour = hour
        return cal.date(from: c) ?? tomorrow
    }
}
