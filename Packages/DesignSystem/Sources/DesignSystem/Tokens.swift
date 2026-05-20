import SwiftUI

/// Static design tokens. Themes layer on top of these via `Theme`.
public enum Tokens {
    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let s: CGFloat = 12
        public static let m: CGFloat = 16
        public static let l: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }

    public enum Radius {
        public static let xs: CGFloat = 8
        public static let s: CGFloat = 12
        public static let m: CGFloat = 18
        public static let l: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let pill: CGFloat = 999
    }

    public enum Stroke {
        public static let hairline: CGFloat = 0.5
        public static let regular: CGFloat = 1
        public static let bold: CGFloat = 2
    }

    public enum Duration {
        public static let micro: Double = 0.12
        public static let quick: Double = 0.22
        public static let smooth: Double = 0.36
        public static let calm: Double = 0.6
        public static let breathe: Double = 1.6
    }

    public enum Easing {
        public static let smooth: Animation = .interpolatingSpring(stiffness: 220, damping: 26)
        public static let pop: Animation = .spring(response: 0.32, dampingFraction: 0.62)
        public static let glide: Animation = .easeInOut(duration: Duration.smooth)
        public static let breathe: Animation = .easeInOut(duration: Duration.breathe)
            .repeatForever(autoreverses: true)
    }

    public enum Typography {
        public static let display = Font.system(size: 34, weight: .semibold, design: .rounded)
        public static let title = Font.system(size: 26, weight: .semibold, design: .rounded)
        public static let titleSmall = Font.system(size: 20, weight: .semibold, design: .rounded)
        public static let body = Font.system(size: 16, weight: .regular, design: .rounded)
        public static let bodyMedium = Font.system(size: 16, weight: .medium, design: .rounded)
        public static let caption = Font.system(size: 13, weight: .regular, design: .rounded)
        public static let mono = Font.system(.body, design: .monospaced).weight(.medium)
        public static let serifAccent = Font.system(.title2, design: .serif).weight(.semibold)
    }
}
