import Core
import DesignSystem
import Reminders
import SwiftUI
import Wellness

@main
struct LumenLiteApp: App {
    @UIApplicationDelegateAdaptor(LumenAppDelegate.self) private var appDelegate

    @StateObject private var identity = LocalIdentityService.shared
    @StateObject private var themeStore = ThemeStore()
    @StateObject private var reminders = RemindersService.shared
    @StateObject private var wellness = WellnessService.shared

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(identity)
                .environmentObject(themeStore)
                .environmentObject(reminders)
                .environmentObject(wellness)
                .theme(themeStore.activeTheme)
                .modelContainer(PersistenceController.shared.container)
                .task { await bootstrap() }
                .onOpenURL { url in
                    Task { await handleDeepLink(url) }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task { await refreshOnForeground() }
                }
        }
    }

    @MainActor
    private func refreshOnForeground() async {
        // Keep the lock-screen Live Activity card in sync after long
        // backgrounds.
        LumenPinController.shared.refreshAsync()
        MotivationNotifier.shared.reschedule()
        guard CalendarImporter.shared.hasAccess else { return }
        _ = await CalendarImporter.shared.importUpcoming(ownerID: identity.ownerID)
    }

    @MainActor
    private func bootstrap() async {
        await wellness.refresh()
        if CalendarImporter.shared.hasAccess {
            _ = await CalendarImporter.shared.importUpcoming(ownerID: identity.ownerID)
        }
        LumenPinController.shared.refreshAsync()
        MotivationNotifier.shared.reschedule()
    }

    @MainActor
    private func handleDeepLink(_ url: URL) async {
        guard url.scheme == "lumen" else { return }
        switch url.host {
        case "compose":
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let kindRaw = comps?.queryItems?.first(where: { $0.name == "kind" })?.value ?? "reminder"
            let resolved: ReminderKind
            switch kindRaw {
            case "note": resolved = .note
            case "alarm", "reminder": resolved = .reminder
            case "task": resolved = .task
            default: resolved = .reminder
            }
            NotificationCenter.default.post(
                name: .lumenSelectFilter,
                object: nil,
                userInfo: ["filter": resolved == .note ? "notes" : "today"]
            )
            NotificationCenter.default.post(
                name: .lumenOpenCompose,
                object: nil,
                userInfo: ["kind": resolved.rawValue]
            )
        case "notes":
            NotificationCenter.default.post(
                name: .lumenSelectFilter,
                object: nil,
                userInfo: ["filter": "notes"]
            )
        case "reminder":
            let pathID = url.pathComponents.last(where: { $0 != "/" })
            if let pathID, let id = UUID(uuidString: pathID) {
                NotificationCenter.default.post(
                    name: .lumenOpenReminder,
                    object: nil,
                    userInfo: ["id": id]
                )
            }
        default:
            break
        }
    }
}
