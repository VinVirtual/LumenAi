import Core
import DesignSystem
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

public struct RemindersHomeView: View {
    @ObservedObject private var identity = LocalIdentityService.shared
    @ObservedObject private var remindersService = RemindersService.shared
    @StateObject private var calendarImporter = CalendarImporter.shared
    @Environment(\.modelContext) private var context
    @Query(sort: \ReminderEntity.dueAt, order: .forward) private var reminders: [ReminderEntity]

    @State private var showQuickAdd = false
    @State private var draftText = ""
    @State private var draftDate: Date?
    @State private var draftPriority: Int = 0
    @State private var draftKind: ReminderKind = .reminder
    @State private var draftPinned = false
    @State private var now: Date = .now
    @State private var filter: HomeFilter = .today
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var editingEntity: ReminderEntity?
    @State private var showHowTo = false
    @State private var pinEnabled: Bool = LumenPinController.shared.isEnabled
    @StateObject private var motivation = MotivationStore.shared
    @AppStorage("lumen.motivation.enabled") private var motivationEnabled: Bool = true
    @Environment(\.scenePhase) private var scenePhase

    private let priorityEngine = PriorityEngine()
    private let calendar = Calendar.current
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        // The trailing FAB used to live in a `ZStack(alignment: .bottomTrailing)`
        // here. The central `+` on the floating tab bar replaces it, so we
        // collapse to a plain ScrollView. `.lumenOpenCompose` (posted by the
        // tab bar) still wakes the QuickAdd sheet via `.onReceive` below.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Tokens.Spacing.l) {
                    HeaderBlock(now: now, name: firstName)
                    StatusRow(
                        notificationStatus: notificationStatus,
                        calendarHasAccess: calendarImporter.hasAccess,
                        pinEnabled: pinEnabled,
                        onOpenSettings: openNotificationSettings,
                        onShowHowTo: { showHowTo = true },
                        onSyncCalendar: syncCalendar,
                        onTogglePin: togglePin
                    )
                    if motivationEnabled, let m = motivation.current {
                        let displayText = motivation.aiOverride ?? m.text
                        MotivationCard(
                            text: displayText,
                            iconSymbol: m.category.iconSymbol,
                            categoryLabel: m.category.label,
                            isAI: motivation.aiOverride != nil,
                            onRefresh: {
                                HapticEngine.shared.play(.tap)
                                motivation.setAIOverride(nil)
                                motivation.reroll()
                            },
                            onCopy: {
                                UIPasteboard.general.string = displayText
                                HapticEngine.shared.play(.success)
                            }
                        )
                    }
                    HeroCarousel(
                        entities: heroEntities,
                        now: now,
                        onMarkDone: { entity in Task { await RemindersService.shared.markDone(entity) } },
                        onSnooze: { entity in Task { await RemindersService.shared.snooze(entity, minutes: 10) } },
                        onTogglePin: { entity in Task { await RemindersService.shared.togglePin(entity) } },
                        onTap: { entity in editingEntity = entity }
                    )
                    FilterChips(selection: $filter, counts: filterCounts)
                    ListSection(
                        filter: filter,
                        active: filteredActive,
                        completed: completedHistory,
                        urgencyFor: { urgencyFor($0) },
                        currentUserID: identity.ownerID
                    )
                }
                .padding(Tokens.Spacing.l)
                .padding(.bottom, 180)
                .animation(.spring(duration: 0.3), value: filter)
                .animation(.spring(duration: 0.3), value: heroEntities.map(\.id))
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet(
                text: $draftText,
                pickedDate: $draftDate,
                priority: $draftPriority,
                kind: $draftKind,
                isPinned: $draftPinned,
                onCommit: createReminder
            )
            .presentationDetents([.fraction(0.7), .large])
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $editingEntity) { entity in
            ReminderEditorSheet(entity: entity)
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showHowTo) {
            LockScreenHowToSheet().presentationDetents([.medium, .large])
        }
        .onReceive(clockTimer) { value in now = value }
        .onChange(of: scenePhase) { _, phase in
            // If the app stayed open across midnight, the motivation card
            // would still be showing yesterday's quote. Roll it forward
            // when we come back from the background.
            if phase == .active { motivation.ensureFreshForToday() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumenOpenCompose)) { note in
            let kindRaw = note.userInfo?["kind"] as? String ?? ReminderKind.reminder.rawValue
            draftText = ""
            draftDate = nil
            draftPriority = 0
            draftKind = ReminderKind(rawValue: kindRaw) ?? .reminder
            draftPinned = false
            showQuickAdd = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumenSelectFilter)) { note in
            if let raw = note.userInfo?["filter"] as? String,
               let f = HomeFilter(rawValue: raw) {
                withAnimation(.spring(duration: 0.25)) { filter = f }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumenOpenReminder)) { note in
            if let id = note.userInfo?["id"] as? UUID,
               let entity = reminders.first(where: { $0.id == id }) {
                editingEntity = entity
            }
        }
        .task { await refreshNotificationStatus() }
        .undoToast()
    }

    // MARK: - Derived state

    private var firstName: String {
        let name = identity.friendlyName(fallback: "friend")
        return name.split(separator: " ").first.map(String.init) ?? "friend"
    }

    /// Top-of-mind active items shown in the swipeable hero carousel.
    /// Order: imminent reminders, then upcoming tasks (by due date), then
    /// pinned notes (most recently updated). Capped to 5 so the carousel
    /// stays glanceable.
    private var heroEntities: [ReminderEntity] {
        var seen = Set<UUID>()
        var ordered: [ReminderEntity] = []

        let activeReminders = reminders
            .filter { $0.status == .active && $0.kind == .reminder && $0.dueAt != nil }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
        for entity in activeReminders {
            if seen.insert(entity.id).inserted { ordered.append(entity) }
            if ordered.count >= 5 { return ordered }
        }

        let activeTasks = reminders
            .filter { $0.status == .active && $0.kind == .task }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
        for entity in activeTasks {
            if seen.insert(entity.id).inserted { ordered.append(entity) }
            if ordered.count >= 5 { return ordered }
        }

        let pinnedNotes = reminders
            .filter { $0.status == .active && $0.kind == .note && $0.isPinned }
            .sorted { $0.updatedAt > $1.updatedAt }
        for entity in pinnedNotes {
            if seen.insert(entity.id).inserted { ordered.append(entity) }
            if ordered.count >= 5 { return ordered }
        }

        return ordered
    }

    /// Reminders whose `status` is active OR were just completed within
    /// the grace period (still rendered, struck through). Mixing them here
    /// is what gives the user the "checkbox stays for a minute" UX.
    private var visiblyActive: [ReminderEntity] {
        let recentIDs = remindersService.recentlyCompleted.keys
        return reminders.filter { entity in
            entity.status == .active || recentIDs.contains(entity.id)
        }
    }

    private var filteredActive: [ReminderEntity] {
        let active = visiblyActive
        switch filter {
        case .today:
            return active.filter { entity in
                guard entity.kind != .note else { return false }
                guard let due = entity.dueAt else { return false }
                return due < endOfToday() && due >= startOfDay()
                    || (due < Date())
            }
        case .upcoming:
            return active.filter {
                guard $0.kind != .note else { return false }
                guard let due = $0.dueAt else { return false }
                return due >= endOfToday()
            }
        case .notes:
            return active
                .filter { $0.kind == .note }
                .sorted { lhs, rhs in
                    if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
                    return lhs.updatedAt > rhs.updatedAt
                }
        case .all:
            return active
        case .done:
            return []
        }
    }

    private var completedHistory: [ReminderEntity] {
        reminders
            .filter { $0.status == .done }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private var filterCounts: [HomeFilter: Int] {
        let active = visiblyActive
        let todayCount = active.filter { entity in
            guard entity.kind != .note else { return false }
            guard let due = entity.dueAt else { return false }
            return due < endOfToday() && due >= startOfDay()
                || (due < Date())
        }.count
        let upcomingCount = active.filter {
            guard $0.kind != .note else { return false }
            guard let due = $0.dueAt else { return false }
            return due >= endOfToday()
        }.count
        let notesCount = active.filter { $0.kind == .note }.count
        return [
            .today: todayCount,
            .upcoming: upcomingCount,
            .notes: notesCount,
            .all: active.count,
            .done: completedHistory.count
        ]
    }

    private func startOfDay() -> Date {
        calendar.startOfDay(for: now)
    }

    private func endOfToday() -> Date {
        calendar.date(byAdding: .day, value: 1, to: startOfDay()) ?? now
    }

    private func urgencyFor(_ entity: ReminderEntity) -> Int {
        priorityEngine.urgency(for: entity.snapshot())
    }

    // MARK: - Actions

    private func createReminder() {
        let userID = identity.ownerID
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let dueOverride = draftDate
        let priorityOverride = draftPriority
        let kind = draftKind
        let pinned = draftPinned
        Task {
            _ = try? await RemindersService.shared.createFromText(
                text,
                ownerID: userID,
                overrideDueAt: dueOverride,
                overridePriority: priorityOverride == 0 ? nil : priorityOverride,
                kind: kind,
                isPinned: pinned
            )
            HapticEngine.shared.play(.success)
            draftText = ""
            draftDate = nil
            draftPriority = 0
            draftKind = .reminder
            draftPinned = false
            showQuickAdd = false
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    private func togglePin() {
        let newValue = !pinEnabled
        LumenPinController.shared.isEnabled = newValue
        pinEnabled = newValue
        if newValue {
            LumenPinController.shared.refreshAsync()
            HapticEngine.shared.play(.success)
        } else {
            LumenPinController.shared.stopAll()
            HapticEngine.shared.play(.tap)
        }
    }

    private func syncCalendar() {
        let userID = identity.ownerID
        Task {
            if !calendarImporter.hasAccess {
                _ = await calendarImporter.requestAccess()
            }
            _ = await calendarImporter.importUpcoming(ownerID: userID)
            HapticEngine.shared.play(.success)
        }
    }

    private func openNotificationSettings() {
        if notificationStatus == .notDetermined {
            Task {
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                await refreshNotificationStatus()
            }
            return
        }
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

}

public extension Notification.Name {
    /// Deep-link: open QuickAdd. `userInfo["kind"]` is a `ReminderKind.rawValue`.
    static let lumenOpenCompose = Notification.Name("lumen.open.compose")
    /// Deep-link: switch the Today filter. `userInfo["filter"]` is a `HomeFilter.rawValue`.
    static let lumenSelectFilter = Notification.Name("lumen.select.filter")
    /// Deep-link: open the editor for an existing reminder. `userInfo["id"]` is a UUID.
    static let lumenOpenReminder = Notification.Name("lumen.open.reminder")
    /// Deep-link: open the AI Companion tab.
    static let lumenOpenAICompanion = Notification.Name("lumen.open.ai")
}

// MARK: - Subviews

enum HomeFilter: String, CaseIterable, Identifiable, Hashable {
    case today, upcoming, notes, all, done
    var id: Self { self }
    var label: String {
        switch self {
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .notes: "Notes"
        case .all: "All"
        case .done: "Done"
        }
    }
    var icon: String {
        switch self {
        case .today: "sun.max.fill"
        case .upcoming: "calendar"
        case .notes: "note.text"
        case .all: "tray.full"
        case .done: "checkmark.circle"
        }
    }
}

private struct HeaderBlock: View {
    let now: Date
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                LumiMark(size: .tiny, glow: true, animated: true)
                Text(greeting)
                    .font(.system(.title, design: .rounded).weight(.semibold))
                Spacer()
                Text(now.formatted(date: .omitted, time: .shortened))
                    .font(.system(.title3, design: .rounded).monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(now.formatted(date: .complete, time: .omitted))
                .font(Tokens.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 36)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<12: return "Good morning, \(name)"
        case 12..<17: return "Hey \(name)"
        case 17..<22: return "Evening, \(name)"
        default: return "Hi \(name)"
        }
    }
}

private struct StatusRow: View {
    let notificationStatus: UNAuthorizationStatus
    let calendarHasAccess: Bool
    let pinEnabled: Bool
    let onOpenSettings: () -> Void
    let onShowHowTo: () -> Void
    let onSyncCalendar: () -> Void
    let onTogglePin: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                NotifPill(status: notificationStatus, action: onOpenSettings)
                PinPill(enabled: pinEnabled, action: onTogglePin)
                LockScreenPill(action: onShowHowTo)
                CalendarPill(hasAccess: calendarHasAccess, action: onSyncCalendar)
            }
        }
        .scrollClipDisabled()
    }
}

private struct PinPill: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: enabled ? "pin.fill" : "pin.slash")
                Text(enabled ? "Lock-screen pin on" : "Pin to lock screen")
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(enabled
                        ? AnyShapeStyle(.orange.opacity(0.18))
                        : AnyShapeStyle(.thinMaterial),
                        in: Capsule())
            .foregroundStyle(enabled ? Color.orange : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

private struct CalendarPill: View {
    let hasAccess: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: hasAccess ? "calendar.badge.checkmark" : "calendar.badge.plus")
                Text(hasAccess ? "Calendar synced" : "Sync calendar")
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(hasAccess ? AnyShapeStyle(.green.opacity(0.18)) : AnyShapeStyle(.thinMaterial), in: Capsule())
            .foregroundStyle(hasAccess ? Color.green : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

private struct NotifPill: View {
    let status: UNAuthorizationStatus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch status {
        case .authorized, .provisional, .ephemeral: "bell.fill"
        case .denied: "bell.slash.fill"
        default: "bell"
        }
    }

    private var label: String {
        switch status {
        case .authorized, .provisional, .ephemeral: "Notifications on"
        case .denied: "Enable notifications"
        default: "Tap to enable"
        }
    }

    private var foreground: Color {
        switch status {
        case .authorized, .provisional, .ephemeral: .green
        case .denied: .pink
        default: .orange
        }
    }

    private var background: AnyShapeStyle {
        switch status {
        case .authorized, .provisional, .ephemeral: AnyShapeStyle(.green.opacity(0.18))
        case .denied: AnyShapeStyle(.pink.opacity(0.2))
        default: AnyShapeStyle(.orange.opacity(0.2))
        }
    }
}

private struct LockScreenPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.on.rectangle")
                Text("Lock screen widget").font(.caption.weight(.medium))
                Image(systemName: "questionmark.circle").font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct FilterChips: View {
    @Binding var selection: HomeFilter
    let counts: [HomeFilter: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HomeFilter.allCases) { filter in
                    Chip(
                        filter: filter,
                        count: counts[filter] ?? 0,
                        selected: filter == selection
                    ) {
                        HapticEngine.shared.play(.tap)
                        withAnimation(.spring(duration: 0.25)) { selection = filter }
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    private struct Chip: View {
        let filter: HomeFilter
        let count: Int
        let selected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: filter.icon).font(.caption)
                    Text(filter.label).font(.subheadline.weight(.semibold))
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.thinMaterial, in: Capsule())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(selected ? AnyShapeStyle(LinearGradient(
                        colors: [.purple.opacity(0.7), .cyan.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )) : AnyShapeStyle(.thinMaterial))
                )
                .foregroundStyle(selected ? .white : .primary)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ListSection: View {
    let filter: HomeFilter
    let active: [ReminderEntity]
    let completed: [ReminderEntity]
    let urgencyFor: (ReminderEntity) -> Int
    let currentUserID: UUID?

    var body: some View {
        if filter == .done {
            if completed.isEmpty {
                emptyDoneState
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(completed) { reminder in
                        CompletedRow(entity: reminder)
                    }
                }
            }
        } else {
            if active.isEmpty {
                emptyActiveState
            } else {
                LazyVStack(spacing: Tokens.Spacing.m) {
                    ForEach(active) { reminder in
                        if reminder.kind == .note {
                            NoteRow(entity: reminder)
                        } else {
                            ReminderCard(
                                entity: reminder,
                                urgency: urgencyFor(reminder),
                                sharedFromName: sharedFromName(for: reminder)
                            )
                        }
                    }
                }
            }
        }
    }

    private var emptyActiveState: some View {
        VStack(spacing: 8) {
            Image(systemName: filter == .notes ? "note.text" : "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(LinearGradient(
                    colors: [.purple, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Text(filter == .notes ? "No notes yet" : "Nothing here").font(.headline)
            Text(filter == .notes
                ? "Tap + and pick \u{201C}Note\u{201D} to jot a thought. Pin one to put it on your lock screen."
                : "Tap + to add the next reminder. Try \u{201C}drink water in 5 min\u{201D}.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.bottom, 80) // keep above the floating + button
    }

    private var emptyDoneState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray").font(.system(size: 28))
            Text("No completed reminders yet").font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(.secondary)
        .padding(.vertical, 32)
    }

    /// Friend-shared rows (`ownerID != current user`) get a "from {name}"
    /// pill in `ReminderCard` so the user knows it's not their own. We
    /// resolve through the lightweight `FriendDirectory` populated by
    /// `SocialService` to avoid a Reminders -> Social dependency.
    private func sharedFromName(for reminder: ReminderEntity) -> String? {
        guard let me = currentUserID else { return nil }
        guard reminder.ownerID != me else { return nil }
        return FriendDirectory.shared.firstName(for: reminder.ownerID)
            ?? "a friend"
    }
}

struct CompletedRow: View {
    let entity: ReminderEntity
    @State private var confirmDelete = false

    var body: some View {
        HStack(spacing: Tokens.Spacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(entity.title)
                    .font(.subheadline)
                    .strikethrough(true, color: .secondary)
                    .foregroundStyle(.secondary)
                if let completed = entity.completedAt {
                    Text(completed.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, Tokens.Spacing.m)
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                HapticEngine.shared.play(.tap)
                Task { await RemindersService.shared.unmarkDone(entity) }
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading) {
            Button {
                HapticEngine.shared.play(.tap)
                Task { await RemindersService.shared.unmarkDone(entity) }
            } label: { Label("Restore", systemImage: "arrow.uturn.backward") }
                .tint(.blue)
        }
        .contextMenu {
            Button { Task { await RemindersService.shared.unmarkDone(entity) } } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete this reminder?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                Task { await RemindersService.shared.delete(entity) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct LockScreenHowToSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Get reminders on your lock screen").font(.title2.weight(.semibold))
                    Text("Two things make this work:")
                        .font(.subheadline).foregroundStyle(.secondary)

                    Step(
                        number: 1,
                        title: "Allow notifications",
                        detail: "When the app prompts, tap Allow. The pill at the top of Today shows whether they're on."
                    )
                    Step(
                        number: 2,
                        title: "Add the Lumen widget",
                        detail: "Wake the phone (don't unlock) \u{2192} long-press the lock screen \u{2192} Customize \u{2192} Lock Screen \u{2192} tap a widget slot \u{2192} pick Lumen."
                    )
                    Step(
                        number: 3,
                        title: "How alarms ring",
                        detail: "Low/Medium priority plays the iOS default chime once. High/Critical priority plays a louder bell tone and repeats every minute for 5 minutes, with a Stop alarm button on the notification."
                    )
                    Step(
                        number: 4,
                        title: "Persistent lock-screen card (Lumen Pin)",
                        detail: "Toggle \u{201C}Pin to lock screen\u{201D} in the Today header. A live card appears on the lock screen with hollow circles you can tap to mark items done, plus +Note / +Todo chips that open the composer. The card stays put until you uncheck or unpin."
                    )
                    Step(
                        number: 5,
                        title: "Hide the Dynamic Island pill",
                        detail: "The pill is intentionally tiny, but if you want it gone entirely, open Settings \u{2192} Notifications \u{2192} Lumen \u{2192} Live Activities \u{2192} turn off \u{201C}Show on Dynamic Island.\u{201D} The lock-screen card stays."
                    )
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") { dismiss() }
                }
            }
        }
    }

    private struct Step: View {
        let number: Int
        let title: String
        let detail: String

        var body: some View {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)
                    Text("\(number)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
