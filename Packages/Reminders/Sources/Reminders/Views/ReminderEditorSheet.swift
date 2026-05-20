import Core
import DesignSystem
import SwiftUI

/// Full editor for an existing reminder. Lets the user rename, set a precise
/// alarm date+time (or remove it), tweak priority, add notes, mark done, or
/// delete entirely.
public struct ReminderEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entity: ReminderEntity

    @State private var title: String
    @State private var notes: String
    @State private var hasAlarm: Bool
    @State private var alarmDate: Date
    @State private var priority: Int
    @State private var isPinned: Bool
    @State private var confirmDelete = false
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var fieldFocused: Bool

    public init(entity: ReminderEntity) {
        self.entity = entity
        _title = State(initialValue: entity.title)
        _notes = State(initialValue: entity.body ?? "")
        _hasAlarm = State(initialValue: entity.dueAt != nil)
        _alarmDate = State(initialValue: entity.dueAt ?? Date().addingTimeInterval(60 * 60))
        _priority = State(initialValue: entity.priority)
        _isPinned = State(initialValue: entity.isPinned)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("What") {
                    TextField("Title", text: $title)
                        .focused($fieldFocused)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                        .focused($fieldFocused)
                }

                if entity.kind == .note {
                    Section("Lock screen") {
                        Toggle(isOn: $isPinned.animation()) {
                            Label("Pin to lock screen widget", systemImage: "pin.fill")
                        }
                        Text("Pinned notes appear in the Lumen widget so you see them on every glance.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if entity.kind != .note {
                    Section(entity.kind == .task ? "Due date" : "Alarm") {
                        Toggle(isOn: $hasAlarm.animation()) {
                            Label(entity.kind == .task ? "Has due date" : "Notify me",
                                  systemImage: entity.kind == .task ? "calendar" : "alarm.fill")
                        }
                        if hasAlarm {
                            DatePicker(
                                "When",
                                selection: $alarmDate,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.graphical)
                            QuickAlarmChips(date: $alarmDate)
                        } else {
                            Text(entity.kind == .task
                                ? "Tasks without a due date sit at the bottom of the list."
                                : "This reminder will live in your list but won't ring.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    if entity.kind == .reminder {
                        Section("Priority") {
                            Picker("Priority", selection: $priority) {
                                Text("Low").tag(0)
                                Text("Medium").tag(1)
                                Text("High").tag(2)
                                Text("Critical").tag(3)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                if let saveError {
                    Section { Text(saveError).foregroundStyle(.pink) }
                }

                Section {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label(entity.kind == .note ? "Delete note" : "Delete reminder", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { fieldFocused = false }
                }
            }
            .alert("Delete this reminder?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    HapticEngine.shared.play(.error)
                    Task {
                        await RemindersService.shared.delete(entity)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\u{201C}\(entity.title)\u{201D} will be permanently removed.")
            }
        }
    }

    private var navTitle: String {
        switch entity.kind {
        case .note: "Edit note"
        case .reminder: "Edit reminder"
        case .task: "Edit task"
        }
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            let appliedDue: Date?? = entity.kind == .note
                ? .some(nil)
                : (hasAlarm ? .some(alarmDate) : .some(nil))
            await RemindersService.shared.update(
                entity,
                title: title,
                body: notes,
                dueAt: appliedDue,
                priority: priority
            )
            if entity.isPinned != isPinned {
                await RemindersService.shared.togglePin(entity)
            }
            HapticEngine.shared.play(.success)
            dismiss()
        }
    }
}

private struct QuickAlarmChips: View {
    @Binding var date: Date
    private let cal = Calendar.current

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("In 15 min") { date = Date().addingTimeInterval(15 * 60) }
                chip("In 1 hour") { date = Date().addingTimeInterval(60 * 60) }
                chip("Tonight 8pm") { date = todayAt(hour: 20) }
                chip("Tomorrow 9am") { date = tomorrowAt(hour: 9) }
                chip("Next Mon 9am") { date = nextWeekday(2, hour: 9) }
            }
        }
    }

    private func chip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(.caption)
            .buttonStyle(.bordered)
            .clipShape(Capsule())
    }

    private func todayAt(hour: Int) -> Date {
        var c = cal.dateComponents([.year, .month, .day], from: Date())
        c.hour = hour
        return cal.date(from: c) ?? Date()
    }

    private func tomorrowAt(hour: Int) -> Date {
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var c = cal.dateComponents([.year, .month, .day], from: tomorrow)
        c.hour = hour
        return cal.date(from: c) ?? tomorrow
    }

    private func nextWeekday(_ weekday: Int, hour: Int) -> Date {
        var date = Date()
        for _ in 0..<8 {
            date = cal.date(byAdding: .day, value: 1, to: date) ?? date
            if cal.component(.weekday, from: date) == weekday {
                var c = cal.dateComponents([.year, .month, .day], from: date)
                c.hour = hour
                return cal.date(from: c) ?? date
            }
        }
        return date
    }
}
