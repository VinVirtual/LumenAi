import SwiftUI

/// Slim card surface for a single motivational line. Caller wires it up
/// against whatever data source it uses (the `MotivationStore` in `Core`,
/// in the typical case). Keeping this UI-only means `DesignSystem` doesn't
/// have to know about the bundled JSON or the @AppStorage rotation logic.
public struct MotivationCard: View {
    private let text: String
    private let iconSymbol: String
    private let categoryLabel: String
    private let isAI: Bool
    private let onRefresh: () -> Void
    private let onAIRefresh: (() -> Void)?
    private let onCopy: (() -> Void)?

    public init(
        text: String,
        iconSymbol: String,
        categoryLabel: String,
        isAI: Bool = false,
        onRefresh: @escaping () -> Void,
        onAIRefresh: (() -> Void)? = nil,
        onCopy: (() -> Void)? = nil
    ) {
        self.text = text
        self.iconSymbol = iconSymbol
        self.categoryLabel = categoryLabel
        self.isAI = isAI
        self.onRefresh = onRefresh
        self.onAIRefresh = onAIRefresh
        self.onCopy = onCopy
    }

    public var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                HStack(spacing: 8) {
                    Image(systemName: iconSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(categoryLabel.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                    if isAI {
                        Text("AI")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.accentColor.opacity(0.18))
                            )
                            .foregroundStyle(.tint)
                    }
                    Spacer()
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("New motivation")
                }
                Text(text)
                    .font(Tokens.Typography.bodyMedium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .contextMenu {
            Button {
                onRefresh()
            } label: {
                Label("New one", systemImage: "arrow.triangle.2.circlepath")
            }
            if let onAIRefresh {
                Button {
                    onAIRefresh()
                } label: {
                    Label("Generate with Companion", systemImage: "sparkles")
                }
            }
            if let onCopy {
                Button {
                    onCopy()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
        }
    }
}
