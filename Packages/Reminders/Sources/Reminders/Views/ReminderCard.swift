import Core
import DesignSystem
import SwiftUI

public struct ReminderCard: View {
    @Environment(\.theme) private var theme
    let entity: ReminderEntity
    let urgency: Int
    /// Optional owner display info for friend-shared rows. When the
    /// row's owner_id differs from the current user, this name is
    /// rendered as a "from X" pill and all mutate gestures are
    /// disabled (they'd 403 server-side anyway).
    let sharedFromName: String?
    @State private var showEditor = false
    @State private var confirmDelete = false
    @State private var showReadOnlyToast = false

    public init(entity: ReminderEntity, urgency: Int, sharedFromName: String? = nil) {
        self.entity = entity
        self.urgency = urgency
        self.sharedFromName = sharedFromName
    }

    private var isReadOnly: Bool { sharedFromName != nil }

    /// True while the reminder is sitting in the post-tap grace window.
    private var isCompletedLingering: Bool { entity.status == .done }

    public var body: some View {
        GlassCard(cornerRadius: Tokens.Radius.l) {
            HStack(alignment: .top, spacing: Tokens.Spacing.m) {
                urgencyDot
                VStack(alignment: .leading, spacing: 6) {
                    Text(entity.title)
                        .font(Tokens.Typography.bodyMedium)
                        .strikethrough(isCompletedLingering, color: .secondary)
                        .foregroundStyle(isCompletedLingering ? .secondary : .primary)
                        .lineLimit(2)
                    if let body = entity.body, !body.isEmpty {
                        Text(body)
                            .font(Tokens.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if let name = sharedFromName {
                        sharedFromPill(name: name)
                    }
                    HStack(spacing: 8) {
                        if isCompletedLingering {
                            Label("Done — tap to undo", systemImage: "arrow.uturn.backward")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.green)
                        } else if let due = entity.dueAt {
                            Label(dueLabel(for: due), systemImage: "alarm")
                                .font(.caption2.monospacedDigit())
                        } else {
                            Label("No alarm set", systemImage: "alarm.waves.left.and.right")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        if let loc = entity.locationName, !loc.isEmpty {
                            Label(loc, systemImage: "mappin.and.ellipse").font(.caption2)
                        }
                        if entity.recurrenceJSON != nil {
                            Label("repeats", systemImage: "repeat").font(.caption2)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if !isReadOnly {
                    completeButton
                }
            }
        }
        .opacity(isCompletedLingering ? 0.7 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticEngine.shared.play(.tap)
            if isReadOnly {
                showReadOnlyToast = true
            } else if isCompletedLingering {
                Task { await RemindersService.shared.unmarkDone(entity) }
            } else {
                showEditor = true
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: !isReadOnly) {
            if !isReadOnly {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: { Label("Delete", systemImage: "trash") }

                Button("Done") { Task { await RemindersService.shared.markDone(entity) } }
                    .tint(.green)
            }
        }
        .swipeActions(edge: .leading) {
            if !isReadOnly {
                Button("Snooze 10m") { Task { await RemindersService.shared.snooze(entity, minutes: 10) } }
                    .tint(.orange)
                Button("Edit") { showEditor = true }
                    .tint(.blue)
            }
        }
        .contextMenu {
            if !isReadOnly {
                Button { showEditor = true } label: { Label("Edit", systemImage: "pencil") }
                Button { Task { await RemindersService.shared.markDone(entity) } } label: { Label("Mark Done", systemImage: "checkmark.circle") }
                Button { Task { await RemindersService.shared.snooze(entity, minutes: 60) } } label: { Label("Snooze 1h", systemImage: "moon.zzz") }
                Divider()
                Button(role: .destructive) {
                    confirmDelete = true
                } label: { Label("Delete", systemImage: "trash") }
            }
        }
        .alert("Delete this reminder?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                HapticEngine.shared.play(.error)
                Task { await RemindersService.shared.delete(entity) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\u{201C}\(entity.title)\u{201D} will be permanently removed.")
        }
        .alert("Shared by \(sharedFromName ?? "a friend")", isPresented: $showReadOnlyToast) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Only \(sharedFromName ?? "they") can edit or complete this. You'll get a heads-up when it fires.")
        }
        .sheet(isPresented: $showEditor) {
            ReminderEditorSheet(entity: entity)
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
    }

    private func sharedFromPill(name: String) -> some View {
        Label("From \(name)", systemImage: "person.2.fill")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.accentColor.opacity(0.18)))
            .foregroundStyle(Color.accentColor)
    }

    private func dueLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "Today \u{2022} \(date.formatted(date: .omitted, time: .shortened))"
        } else if cal.isDateInTomorrow(date) {
            return "Tomorrow \u{2022} \(date.formatted(date: .omitted, time: .shortened))"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        }
    }

    private var urgencyDot: some View {
        Circle()
            .fill(urgencyColor)
            .frame(width: 10, height: 10)
            .padding(.top, 6)
            .accessibilityLabel("Urgency \(urgency)")
    }

    private var urgencyColor: Color {
        switch urgency {
        case ..<25: .green
        case 25..<60: .yellow
        case 60..<85: .orange
        default: .pink
        }
    }

    private var completeButton: some View {
        Button {
            Task {
                if isCompletedLingering {
                    HapticEngine.shared.play(.tap)
                    await RemindersService.shared.unmarkDone(entity)
                } else {
                    HapticEngine.shared.play(.success)
                    await RemindersService.shared.markDone(entity)
                }
            }
        } label: {
            Image(systemName: isCompletedLingering ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.title2)
                .foregroundStyle(isCompletedLingering ? Color.green : Color.white.opacity(0.85))
                .symbolEffect(.bounce, value: isCompletedLingering)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCompletedLingering ? "Undo done" : "Mark complete")
    }
}
