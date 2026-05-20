import SwiftUI

/// `Aurora` paints animated gradient blobs as the app's living background.
/// Honors `accessibilityReduceMotion` and `theme.motion` to throttle animation.
public struct Aurora: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        TimelineView(.animation(minimumInterval: shouldAnimate ? 1.0 / 30.0 : 1.0)) { ctx in
            Canvas { canvas, size in
                let elapsed = ctx.date.timeIntervalSinceReferenceDate * theme.gradient.speed
                paintBackground(in: canvas, size: size)
                paintBlobs(in: canvas, size: size, elapsed: elapsed)
            }
            .blur(radius: blurRadius)
        }
        .ignoresSafeArea()
        .background(Color(hex: theme.palette.backgroundHex))
    }

    private var shouldAnimate: Bool {
        !reduceMotion && theme.motion != .calm
    }

    private var blurRadius: CGFloat {
        switch theme.blurStyle {
        case .soft: 60
        case .glass: 80
        case .frosted: 100
        }
    }

    private func paintBackground(in ctx: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        ctx.fill(Path(rect), with: .color(Color(hex: theme.palette.backgroundHex)))
    }

    private func paintBlobs(in ctx: GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let stops = theme.gradient.stops.map { Color(hex: $0) }
        let radius = max(size.width, size.height) * 0.55
        for (idx, color) in stops.enumerated() {
            let phase = Double(idx) * 1.7
            let x = size.width * 0.5
                + cos(elapsed * 0.3 + phase) * size.width * 0.32
            let y = size.height * 0.5
                + sin(elapsed * 0.27 + phase * 1.3) * size.height * 0.32
            let circle = Path(ellipseIn: CGRect(
                x: x - radius / 2, y: y - radius / 2,
                width: radius, height: radius
            ))
            ctx.fill(circle, with: .color(color.opacity(0.55)))
        }
    }
}
