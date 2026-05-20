import SwiftUI

/// A `Theme` is the runtime appearance pack that drives palette, gradients,
/// blur intensity, and motion level. Themes serialize to JSON and can be
/// shared via `lumen://theme/...` deep links.
public struct Theme: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let displayName: String
    public let palette: Palette
    public let gradient: AuroraGradient
    public let blurStyle: BlurStyle
    public let motion: MotionLevel

    public struct Palette: Equatable, Codable, Sendable {
        public let backgroundHex: String
        public let surfaceHex: String
        public let primaryHex: String
        public let accentHex: String
        public let textHex: String
        public let mutedTextHex: String

        public init(
            backgroundHex: String,
            surfaceHex: String,
            primaryHex: String,
            accentHex: String,
            textHex: String,
            mutedTextHex: String
        ) {
            self.backgroundHex = backgroundHex
            self.surfaceHex = surfaceHex
            self.primaryHex = primaryHex
            self.accentHex = accentHex
            self.textHex = textHex
            self.mutedTextHex = mutedTextHex
        }
    }

    public struct AuroraGradient: Equatable, Codable, Sendable {
        public let stops: [String]
        public let speed: Double
        public init(stops: [String], speed: Double = 1.0) {
            self.stops = stops
            self.speed = speed
        }
    }

    public enum BlurStyle: String, Codable, Sendable {
        case soft, glass, frosted
    }

    public enum MotionLevel: String, Codable, Sendable {
        case calm, standard, vivid
    }

    public init(
        id: String,
        displayName: String,
        palette: Palette,
        gradient: AuroraGradient,
        blurStyle: BlurStyle,
        motion: MotionLevel
    ) {
        self.id = id
        self.displayName = displayName
        self.palette = palette
        self.gradient = gradient
        self.blurStyle = blurStyle
        self.motion = motion
    }
}

public extension Theme {
    static let aurora = Theme(
        id: "aurora",
        displayName: "Aurora",
        palette: .init(
            backgroundHex: "#0B0B12",
            surfaceHex: "#161624",
            primaryHex: "#A87BFF",
            accentHex: "#7CE7E1",
            textHex: "#F4F1FF",
            mutedTextHex: "#9C9AB6"
        ),
        gradient: .init(stops: ["#3D2A6B", "#7CE7E1", "#FF8FB1"], speed: 1.0),
        blurStyle: .glass,
        motion: .standard
    )

    static let dawn = Theme(
        id: "dawn",
        displayName: "Dawn",
        palette: .init(
            backgroundHex: "#FFF8F1",
            surfaceHex: "#FFFFFF",
            primaryHex: "#FF7A66",
            accentHex: "#FFB066",
            textHex: "#1B1A26",
            mutedTextHex: "#6B6B7C"
        ),
        gradient: .init(stops: ["#FFC9A8", "#FFA1C2", "#9DBDFF"], speed: 0.8),
        blurStyle: .soft,
        motion: .calm
    )

    static let nebula = Theme(
        id: "nebula",
        displayName: "Nebula",
        palette: .init(
            backgroundHex: "#080014",
            surfaceHex: "#13002A",
            primaryHex: "#FF5FCB",
            accentHex: "#5EE7FF",
            textHex: "#FBF6FF",
            mutedTextHex: "#9F95C2"
        ),
        gradient: .init(stops: ["#FF5FCB", "#5E5BFF", "#5EE7FF"], speed: 1.2),
        blurStyle: .frosted,
        motion: .vivid
    )

    static let midnight = Theme(
        id: "midnight",
        displayName: "Midnight",
        palette: .init(
            backgroundHex: "#05060A",
            surfaceHex: "#0F1320",
            primaryHex: "#5B8BFF",
            accentHex: "#8C5BFF",
            textHex: "#EAF0FF",
            mutedTextHex: "#7884A6"
        ),
        gradient: .init(stops: ["#0A1230", "#1F1A4A", "#321B5A"], speed: 0.6),
        blurStyle: .glass,
        motion: .calm
    )

    static let citrus = Theme(
        id: "citrus",
        displayName: "Citrus",
        palette: .init(
            backgroundHex: "#FFFBF1",
            surfaceHex: "#FFFFFF",
            primaryHex: "#FF8A2B",
            accentHex: "#FFD03B",
            textHex: "#1B1A14",
            mutedTextHex: "#6E6A57"
        ),
        gradient: .init(stops: ["#FFE8B0", "#FFB76B", "#FF8A8A"], speed: 0.9),
        blurStyle: .soft,
        motion: .calm
    )

    static let ocean = Theme(
        id: "ocean",
        displayName: "Ocean",
        palette: .init(
            backgroundHex: "#03121C",
            surfaceHex: "#0F2230",
            primaryHex: "#3DDDD8",
            accentHex: "#5BA9FF",
            textHex: "#EAF7FF",
            mutedTextHex: "#7CA3B8"
        ),
        gradient: .init(stops: ["#0F4C6E", "#1F8FA8", "#5BD7C2"], speed: 1.0),
        blurStyle: .glass,
        motion: .standard
    )

    static let forest = Theme(
        id: "forest",
        displayName: "Forest",
        palette: .init(
            backgroundHex: "#0A140C",
            surfaceHex: "#142519",
            primaryHex: "#4FCB7C",
            accentHex: "#A4E26A",
            textHex: "#EFFBE8",
            mutedTextHex: "#84A78D"
        ),
        gradient: .init(stops: ["#1B3A24", "#2D6A47", "#85C56F"], speed: 0.7),
        blurStyle: .glass,
        motion: .calm
    )

    static let bundled: [Theme] = [.aurora, .midnight, .ocean, .forest, .nebula, .citrus, .dawn]
}

public extension Color {
    /// Convenience init from `#RRGGBB` strings used in `Theme.Palette`.
    init(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v & 0xff0000) >> 16) / 255
        let g = Double((v & 0x00ff00) >> 8) / 255
        let b = Double(v & 0x0000ff) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// Inject the active `Theme` via the SwiftUI environment.
private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .aurora
}

public extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

public extension View {
    func theme(_ theme: Theme) -> some View {
        environment(\.theme, theme)
            .tint(Color(hex: theme.palette.primaryHex))
            .preferredColorScheme(theme.isLight ? .light : .dark)
    }
}

public extension Theme {
    /// Lightness heuristic: themes with id matching a known light palette
    /// flip the system into light mode. New light themes should be added
    /// to this set.
    var isLight: Bool {
        ["dawn", "citrus"].contains(id)
    }
}
