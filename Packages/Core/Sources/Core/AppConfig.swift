import Foundation

/// Resolves runtime configuration (App Group, environment) from
/// `Info.plist` keys injected via the `.xcconfig` files.
///
/// Public/offline edition: there is no Supabase URL or anon key. Only
/// the App Group identifier survives so widgets and Live Activities can
/// reach the shared SwiftData store.
public struct AppConfig: Sendable {
    public let appGroup: String
    public let environment: Environment

    public enum Environment: String, Sendable {
        case debug, release
    }

    public static let shared: AppConfig = .load()

    public static func load(bundle: Bundle = .main) -> AppConfig {
        let info = bundle.infoDictionary ?? [:]
        guard let group = info["LumenAppGroup"] as? String else {
            assertionFailure("Lumen configuration missing LumenAppGroup in Info.plist")
            return AppConfig(
                appGroup: "group.app.lumen.lite.shared",
                environment: .debug
            )
        }

        #if DEBUG
        let env = Environment.debug
        #else
        let env = Environment.release
        #endif

        return AppConfig(appGroup: group, environment: env)
    }
}
