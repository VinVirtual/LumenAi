import CoreText
import Foundation
import SwiftUI

/// Registers user-selectable custom fonts at runtime. Fonts ship as TTF files
/// in the main app bundle's `Resources/Fonts` folder and are referenced by
/// PostScript name from this enum.
public enum CustomFont: String, CaseIterable, Identifiable, Sendable {
    case system
    case rounded
    case serif
    case mono
    case satoshi

    public var id: String {
        rawValue
    }

    public var displayName: String {
        rawValue.capitalized
    }

    public func font(size: CGFloat) -> Font {
        switch self {
        case .system: .system(size: size)
        case .rounded: .system(size: size, design: .rounded)
        case .serif: .system(size: size, design: .serif)
        case .mono: .system(size: size, design: .monospaced)
        case .satoshi: .custom("Satoshi-Variable", size: size)
        }
    }
}

public enum FontRegistrar {
    public static func registerBundledFonts() {
        let bundle = Bundle.main
        let candidates = ["Satoshi-Variable.ttf"]
        for name in candidates {
            guard let url = bundle.url(forResource: name, withExtension: nil) else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
