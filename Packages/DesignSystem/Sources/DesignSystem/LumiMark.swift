import SwiftUI

/// The Lumi mascot mark — a soft glowing buddy character used across the
/// app: AI pet avatar, Companion empty state, onboarding, Today header,
/// You-tab default avatar. Centralised here so call sites don't reinvent
/// the geometry/glow/animation each time.
public struct LumiMark: View {
    public enum Size: Sendable {
        case tiny, small, medium, large, hero

        public var points: CGFloat {
            switch self {
            case .tiny: 24
            case .small: 40
            case .medium: 96
            case .large: 160
            case .hero: 220
            }
        }

        /// How much halo to draw, expressed as a multiplier of the
        /// character size. Bigger sizes earn more breathing room because
        /// the glow reads better on hero surfaces.
        public var haloMultiplier: CGFloat {
            switch self {
            case .tiny: 1.15
            case .small: 1.25
            case .medium: 1.35
            case .large: 1.45
            case .hero: 1.55
            }
        }
    }

    private let size: Size
    private let glow: Bool
    private let animated: Bool
    private let glowIntensity: Double

    /// - Parameters:
    ///   - size: One of the standard sizes; falls back to `.medium`.
    ///   - glow: Soft warm radial halo behind the character. Default on.
    ///   - animated: Subtle vertical bob and halo pulse. Default on.
    ///   - glowIntensity: 0...1, scales the halo opacity. Used by the AI
    ///     pet to convey leveling up. Defaults to 0.6.
    public init(
        size: Size = .medium,
        glow: Bool = true,
        animated: Bool = true,
        glowIntensity: Double = 0.6
    ) {
        self.size = size
        self.glow = glow
        self.animated = animated
        self.glowIntensity = max(0, min(1, glowIntensity))
    }

    @State private var bob: CGFloat = 0
    @State private var pulse: Double = 0

    public var body: some View {
        let p = size.points
        let haloSize = p * size.haloMultiplier
        ZStack {
            if glow {
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.78, blue: 0.55).opacity(glowIntensity * (0.55 + 0.25 * pulse)),
                        Color(red: 1.0, green: 0.6, blue: 0.85).opacity(glowIntensity * 0.18),
                        .clear
                    ],
                    center: .center,
                    startRadius: 1,
                    endRadius: haloSize / 2
                )
                .frame(width: haloSize, height: haloSize)
                .blur(radius: size == .tiny ? 2 : 6)
            }

            Image("Lumi", bundle: .module)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: p, height: p)
                .offset(y: bob)
                .shadow(color: .black.opacity(size == .tiny ? 0 : 0.18), radius: size == .tiny ? 0 : 6, y: 4)
        }
        .frame(width: haloSize, height: haloSize)
        .accessibilityElement()
        .accessibilityLabel("Lumi")
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                bob = -3
            }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                pulse = 1
            }
        }
    }
}

/// Compact non-animated mascot mark. Used in widget headers and other
/// space-constrained surfaces where `LumiMark` would be too large or too
/// expensive (no glow, no bob). The asset bundle is resolved here so
/// callers in other modules don't need to know that `.module` refers to
/// the DesignSystem package.
public struct LumiBrand: View {
    private let size: CGFloat

    public init(size: CGFloat = 16) {
        self.size = size
    }

    public var body: some View {
        Image("Lumi", bundle: .module)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
