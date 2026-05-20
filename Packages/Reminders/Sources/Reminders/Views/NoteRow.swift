import Core
import DesignSystem
import SwiftUI

/// Compact note row used in the Notes filter and All tab.
/// Tap to edit, swipe to pin/delete, long-press for quick actions.
struct NoteRow: View {
    let entity: ReminderEntity
    @State private var showEditor = false
    @State private var confirmDelete = false

    var body: some View {
        Button { showEditor = true } label: {
            HStack(alignment: .top, spacing: Tokens.Spacing.m) {
                Image(systemName: entity.isPinned ? "pin.fill" : "note.text")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(entity.isPinned ? .orange : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entity.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if let body = entity.body, !body.isEmpty {
                        Text(body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Text(entity.updatedAt.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, Tokens.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(entity.isPinned ? AnyShapeStyle(.orange.opacity(0.12)) : AnyShapeStyle(.ultraThinMaterial))
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button {
                HapticEngine.shared.play(.tap)
                Task { await RemindersService.shared.togglePin(entity) }
            } label: {
                Label(entity.isPinned ? "Unpin" : "Pin", systemImage: entity.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                Task { await RemindersService.shared.togglePin(entity) }
            } label: {
                Label(entity.isPinned ? "Unpin from lock screen" : "Pin to lock screen",
                      systemImage: entity.isPinned ? "pin.slash" : "pin")
            }
            Button { showEditor = true } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete this note?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                Task { await RemindersService.shared.delete(entity) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditor) {
            ReminderEditorSheet(entity: entity)
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
    }
}
