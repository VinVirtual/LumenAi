import Core
import DesignSystem
import SwiftUI

/// Pillbox toast that appears whenever a reminder is marked done. Stays
/// visible for ~5 seconds; tapping the Undo button restores the reminder.
public struct UndoToast: View {
    let title: String
    let onUndo: () -> Void

    public init(title: String, onUndo: @escaping () -> Void) {
        self.title = title
        self.onUndo = onUndo
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Marked done").font(.subheadline.weight(.semibold))
                Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                HapticEngine.shared.play(.tap)
                onUndo()
            } label: {
                Text("Undo")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
        .padding(.horizontal, 24)
    }
}

/// Hosting modifier: subscribes to `RemindersService.shared.lastCompletion`
/// and shows an `UndoToast` that fades in fast and fades out clearly.
public struct UndoToastHost: ViewModifier {
    @ObservedObject private var service = RemindersService.shared
    @State private var visible = false
    @State private var dismissTask: Task<Void, Never>?

    /// How long the toast stays fully visible before starting to fade.
    private static let visibleDuration: UInt64 = 4_000_000_000
    /// Fade-out animation duration matches the system spring used here.
    private static let fadeDuration = 0.45

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let completion = service.lastCompletion {
                    UndoToast(title: completion.title) {
                        dismissTask?.cancel()
                        Task {
                            await RemindersService.shared.unmarkDone(reminderID: completion.reminderID)
                        }
                        hide()
                    }
                    .padding(.bottom, 100)
                    .id(completion.id)
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 16)
                    .onAppear {
                        dismissTask?.cancel()
                        withAnimation(.easeOut(duration: 0.22)) { visible = true }
                        dismissTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: Self.visibleDuration)
                            guard RemindersService.shared.lastCompletion?.id == completion.id else { return }
                            withAnimation(.easeIn(duration: Self.fadeDuration)) { visible = false }
                            try? await Task.sleep(nanoseconds: UInt64(Self.fadeDuration * 1_000_000_000))
                            if RemindersService.shared.lastCompletion?.id == completion.id {
                                RemindersService.shared.lastCompletion = nil
                            }
                        }
                    }
                    .onDisappear { visible = false }
                }
            }
    }

    private func hide() {
        withAnimation(.easeIn(duration: Self.fadeDuration)) { visible = false }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Self.fadeDuration * 1_000_000_000))
            RemindersService.shared.lastCompletion = nil
        }
    }
}

public extension View {
    /// Drop this near the root of any view that wants to participate in the
    /// "Mark done -> Undo" flow.
    func undoToast() -> some View { modifier(UndoToastHost()) }
}
