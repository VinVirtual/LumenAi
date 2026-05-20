import Combine
import DesignSystem
import Foundation

@MainActor
public final class ThemeStore: ObservableObject {
    @Published public private(set) var activeTheme: Theme
    @Published public private(set) var availableThemes: [Theme]

    private let userDefaults: UserDefaults
    private let storageKey = "lumen.theme.id"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        availableThemes = Theme.bundled
        if let id = userDefaults.string(forKey: storageKey),
           let theme = Theme.bundled.first(where: { $0.id == id })
        {
            activeTheme = theme
        } else {
            activeTheme = .aurora
        }
    }

    public func select(_ theme: Theme) {
        activeTheme = theme
        userDefaults.set(theme.id, forKey: storageKey)
    }

    public func register(_ theme: Theme) {
        if !availableThemes.contains(where: { $0.id == theme.id }) {
            availableThemes.append(theme)
        }
    }
}
