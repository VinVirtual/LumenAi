import DesignSystem
import SwiftUI

/// AI pet avatar. Renders the Lumi mascot scaled and glowing in proportion
/// to the configured `level`, so progression through the `AIPetStage`
/// ladder reads visually without per-stage artwork. The optional
/// `auraSymbol` becomes a slowly rotating ring around Lumi for the
/// higher stages.
public struct LumenAvatarView: View {
    public struct Configuration: Hashable, Codable, Sendable {
        public var primaryHex: String
        public var secondaryHex: String
        public var faceSymbol: String
        public var auraSymbol: String?
        public var level: Int

        public init(
            primaryHex: String = "#A87BFF",
            secondaryHex: String = "#7CE7E1",
            faceSymbol: String = "sparkles",
            auraSymbol: String? = nil,
            level: Int = 1
        ) {
            self.primaryHex = primaryHex
            self.secondaryHex = secondaryHex
            self.faceSymbol = faceSymbol
            self.auraSymbol = auraSymbol
            self.level = level
        }
    }

    private let configuration: Configuration
    private let size: CGFloat
    private let animated: Bool

    public init(configuration: Configuration, size: CGFloat = 96, animated: Bool = true) {
        self.configuration = configuration
        self.size = size
        self.animated = animated
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: animated ? 1.0 / 30.0 : 1.0)) { ctx in
            let elapsed = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                if let aura = configuration.auraSymbol {
                    Image(systemName: aura)
                        .font(.system(size: size * 1.05, weight: .ultraLight))
                        .foregroundStyle(Color(hex: configuration.secondaryHex).opacity(0.55))
                        .rotationEffect(.degrees(elapsed.truncatingRemainder(dividingBy: 360) * 30))
                }

                LumiMark(
                    size: lumiSize,
                    glow: true,
                    animated: animated,
                    glowIntensity: glowIntensity
                )
                .scaleEffect(scaleForLevel)
            }
            .frame(width: size, height: size)
            .accessibilityElement()
            .accessibilityLabel("Lumi level \(configuration.level)")
        }
    }

    /// Pick the smallest LumiMark size that fits inside `size`. Hero/large
    /// surfaces get correspondingly bigger halos.
    private var lumiSize: LumiMark.Size {
        switch size {
        case ..<32: .tiny
        case 32..<60: .small
        case 60..<128: .medium
        case 128..<200: .large
        default: .hero
        }
    }

    /// Higher levels grow Lumi a little (capped) so the AI pet feels like
    /// it's filling out as it ages.
    private var scaleForLevel: CGFloat {
        let level = max(1, configuration.level)
        let extra = min(0.18, CGFloat(level - 1) * 0.012)
        return 1.0 + extra
    }

    /// Halo brightness ramps with level too — egg starts dim, supernova
    /// glows hot.
    private var glowIntensity: Double {
        let level = max(1, configuration.level)
        return min(1.0, 0.4 + Double(level - 1) * 0.025)
    }
}
