import Core
import DesignSystem
import Finance
import Reminders
import SwiftUI
import Wellness

enum RootTab: Hashable {
    case home, habits, money, you
}

struct RootView: View {
    @EnvironmentObject private var identity: LocalIdentityService

    var body: some View {
        ZStack {
            Aurora()
            content
                .sheet(isPresented: nameSheetBinding) {
                    NameSheet()
                        .interactiveDismissDisabled()
                        .presentationDetents([.medium])
                        .presentationBackground(.ultraThinMaterial)
                }
        }
        .animation(Tokens.Easing.glide, value: identity.needsDisplayName)
    }

    /// Pop the first-launch name sheet only on a brand-new install. It
    /// dismisses itself the moment the user types anything, and never
    /// reappears until the user explicitly clears their name from the
    /// Profile tab.
    private var nameSheetBinding: Binding<Bool> {
        Binding(
            get: { identity.needsDisplayName },
            set: { _ in }
        )
    }

    private var content: some View {
        MainTabsView()
    }
}

private struct MainTabsView: View {
    @EnvironmentObject private var identity: LocalIdentityService
    @State private var tab: RootTab = .home

    /// The center FAB only fires on surfaces with a clear "compose" /
    /// "add" target. Habits / Profile would have no target so we hide
    /// it there (animated out by `FloatingTabBar`).
    private var centerActionEnabled: Bool {
        tab == .home || tab == .money
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .home: RemindersHomeView()
                case .habits: HabitsHomeView()
                case .money: MoneyHomeView(ownerID: identity.ownerID)
                case .you: YouView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 96)
            }

            FloatingTabBar(
                selection: $tab,
                items: [
                    .init(id: .home, icon: "house.fill", title: "Home"),
                    .init(id: .habits, icon: "flame.fill", title: "Habits"),
                    .init(id: .money, icon: "dollarsign.circle.fill", title: "Money"),
                    .init(id: .you, icon: "person.crop.circle.fill", title: "Profile")
                ],
                centerAccessoryEnabled: centerActionEnabled,
                centerAccessoryAction: handlePlus
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumenSelectFilter)) { _ in
            tab = .home
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumenOpenCompose)) { _ in
            tab = .home
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumenOpenReminder)) { _ in
            tab = .home
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumenOpenAddExpense)) { _ in
            tab = .money
        }
    }

    private func handlePlus() {
        switch tab {
        case .home:
            NotificationCenter.default.post(name: .lumenOpenCompose, object: nil)
        case .money:
            NotificationCenter.default.post(name: .lumenOpenAddExpense, object: nil)
        default:
            break
        }
    }
}

// MARK: - First-launch name sheet

private struct NameSheet: View {
    @EnvironmentObject private var identity: LocalIdentityService
    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: Tokens.Spacing.l) {
            LumiMark(size: .medium, glow: true, animated: true)
                .frame(width: 72, height: 72)
                .padding(.top, Tokens.Spacing.l)
            VStack(spacing: 4) {
                Text("Welcome to Lumen")
                    .font(Tokens.Typography.title)
                Text("Just one thing — what should I call you?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            TextField("Your name", text: $draft)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .focused($focused)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, Tokens.Spacing.l)
                .submitLabel(.done)
                .onSubmit(save)
            Button(action: save) {
                Text("Let's go").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, Tokens.Spacing.l)
            Text("Everything stays on this device. No account, no servers.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Spacing.l)
                .padding(.bottom, Tokens.Spacing.m)
        }
        .onAppear { focused = true }
    }

    private func save() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        identity.displayName = trimmed
        HapticEngine.shared.play(.success)
    }
}

// MARK: - Profile tab

private struct YouView: View {
    @EnvironmentObject private var identity: LocalIdentityService
    @EnvironmentObject private var themeStore: ThemeStore
    @State private var showRename = false
    @State private var showEraseConfirm = false
    @AppStorage("lumen.motivation.enabled") private var motivationEnabled: Bool = true
    @AppStorage("lumen.motivation.notif.enabled") private var motivationNotifEnabled: Bool = false
    @AppStorage("lumen.motivation.notif.startMinutes") private var motivationNotifStart: Int = 9 * 60
    @AppStorage("lumen.motivation.notif.endMinutes") private var motivationNotifEnd: Int = 21 * 60

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.Spacing.l) {
                profileCard
                ThemePickerView()
                preferencesCard
                privacyCard
            }
            .padding(Tokens.Spacing.l)
            .padding(.bottom, 120)
        }
        .sheet(isPresented: $showRename) {
            RenameSheet().presentationDetents([.medium])
        }
        .alert("Erase everything?", isPresented: $showEraseConfirm) {
            Button("Erase", role: .destructive, action: eraseEverything)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This wipes every reminder, habit, transaction, and your name from this device. The action can't be undone.")
        }
    }

    private var profileCard: some View {
        GlassCard {
            VStack(spacing: Tokens.Spacing.m) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.purple, .pink, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 96, height: 96)
                    LumiMark(size: .medium, glow: false, animated: true)
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                }
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)

                VStack(spacing: 2) {
                    Text(identity.friendlyName(fallback: "Hello"))
                        .font(Tokens.Typography.title)
                    Text("This is your offline space")
                        .font(Tokens.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    showRename = true
                    HapticEngine.shared.play(.tap)
                } label: {
                    Label("Change name", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, Tokens.Spacing.s)
        }
    }

    private var preferencesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Preferences")
                    .font(Tokens.Typography.titleSmall)
                    .padding(.bottom, 2)
                Toggle(isOn: $motivationEnabled) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily motivation").font(Tokens.Typography.bodyMedium)
                            Text("A new line each day on Home")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Divider().padding(.vertical, 2)
                Toggle(isOn: $motivationNotifEnabled) {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge")
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notify me daily").font(Tokens.Typography.bodyMedium)
                            Text("One quote a day, at a random time inside your window")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: motivationNotifEnabled) { _, _ in
                    MotivationNotifier.shared.reschedule()
                }
                if motivationNotifEnabled {
                    motivationWindowEditor
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: motivationNotifEnabled)
        }
    }

    private var motivationWindowEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Random between")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                DatePicker(
                    "Start",
                    selection: Binding(
                        get: { Self.date(fromMinutes: motivationNotifStart) },
                        set: { motivationNotifStart = Self.minutes(from: $0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                Text("→").foregroundStyle(.secondary)
                DatePicker(
                    "End",
                    selection: Binding(
                        get: { Self.date(fromMinutes: motivationNotifEnd) },
                        set: { motivationNotifEnd = Self.minutes(from: $0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                Spacer()
            }
            Text("Tip: keep at least an hour between start and end so the time can actually feel random.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
        .onChange(of: motivationNotifStart) { _, _ in
            MotivationNotifier.shared.reschedule()
        }
        .onChange(of: motivationNotifEnd) { _, _ in
            MotivationNotifier.shared.reschedule()
        }
    }

    private var privacyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Privacy")
                    .font(Tokens.Typography.titleSmall)
                Text("Lumen Lite is fully offline. Nothing leaves this device — no account, no analytics, no servers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(role: .destructive) {
                    showEraseConfirm = true
                    HapticEngine.shared.play(.tap)
                } label: {
                    Label("Erase everything", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private static func date(fromMinutes minutes: Int) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = max(0, min(23, minutes / 60))
        comps.minute = max(0, min(59, minutes % 60))
        return cal.date(from: comps) ?? Date()
    }

    private static func minutes(from date: Date) -> Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    private func eraseEverything() {
        let context = PersistenceController.shared.mainContext
        do {
            try context.delete(model: ReminderEntity.self)
            try context.delete(model: HabitEntity.self)
            try context.delete(model: HabitLogEntity.self)
            try context.delete(model: FinanceTransactionEntity.self)
            try context.delete(model: FinanceAccountEntity.self)
            try context.delete(model: FinanceCategoryEntity.self)
            try context.save()
        } catch {
            LumenLog.app.error("erase everything failed: \(error.localizedDescription)")
        }
        identity.clearDisplayName()
        Task { await WellnessService.shared.refresh() }
        HapticEngine.shared.play(.success)
    }
}

private struct RenameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var identity: LocalIdentityService
    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Display name") {
                    TextField("Your name", text: $draft)
                        .textContentType(.name)
                        .focused($focused)
                }
                Section {
                    Text("Lumen Lite uses your name only inside the app — it never leaves the device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit name")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        identity.displayName = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        HapticEngine.shared.play(.success)
                        dismiss()
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            draft = identity.displayName
            focused = true
        }
    }
}

private struct ThemePickerView: View {
    @EnvironmentObject private var themeStore: ThemeStore

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                HStack {
                    Text("Theme").font(Tokens.Typography.titleSmall)
                    Spacer()
                    Text(themeStore.activeTheme.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(themeStore.availableThemes) { theme in
                            ThemeSwatch(
                                theme: theme,
                                isSelected: theme.id == themeStore.activeTheme.id
                            ) {
                                withAnimation(.spring(duration: 0.4)) {
                                    themeStore.select(theme)
                                }
                                HapticEngine.shared.play(.tap)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct ThemeSwatch: View {
    let theme: Theme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                ZStack {
                    LinearGradient(
                        colors: theme.gradient.stops.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 64, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? Color(hex: theme.palette.primaryHex) : .clear, lineWidth: 3)
                    )
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                }
                Text(theme.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? Color(hex: theme.palette.primaryHex) : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.displayName) theme\(isSelected ? ", selected" : "")")
    }
}
