import SwiftUI

/// A frosted glass surface used as the base for cards, sheets, and bars.
public struct GlassCard<Content: View>: View {
    @Environment(\.theme) private var theme
    private let cornerRadius: CGFloat
    private let content: () -> Content

    public init(cornerRadius: CGFloat = Tokens.Radius.l, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content
    }

    public var body: some View {
        content()
            .padding(Tokens.Spacing.m)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(hex: theme.palette.surfaceHex).opacity(0.4))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: Tokens.Stroke.regular)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, y: 14)
    }
}

/// A primary action button with the active theme's gradient fill.
public struct PrimaryButton<Label: View>: View {
    @Environment(\.theme) private var theme
    private let action: () -> Void
    private let label: () -> Label

    public init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    @State private var tapCount: Int = 0

    public var body: some View {
        Button {
            tapCount &+= 1
            action()
        } label: {
            label()
                .font(Tokens.Typography.bodyMedium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [
                            Color(hex: theme.palette.primaryHex),
                            Color(hex: theme.palette.accentHex)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
        // Counter only changes on actual taps; previously this used
        // `UUID()` which produced a new value every render and fired the
        // haptic on every keystroke (the "tic tic" bug).
        .sensoryFeedback(.impact(weight: .medium), trigger: tapCount)
    }
}

public struct GlassFieldStyle: TextFieldStyle {
    @Environment(\.theme) private var theme

    public init() {}

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, Tokens.Spacing.m)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.l, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.l, style: .continuous)
                    .stroke(Color(hex: theme.palette.primaryHex).opacity(0.18), lineWidth: 1)
            )
            .font(Tokens.Typography.body)
    }
}
