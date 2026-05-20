import SwiftUI

/// Floating glass tab bar used by the root view. Renders 5–7 icon-only
/// pills evenly spaced inside a capsule. Pass `centerAccessoryEnabled =
/// true` and a `centerAccessoryAction` to overlay a circular `+` FAB on
/// top of the bar's center; flipping the flag animates it in/out so the
/// host can hide it on tabs where there's no obvious quick-add target.
public struct FloatingTabBar<Tab: Hashable>: View {
    public struct Item: Identifiable {
        /// Tab icons can be either an SF Symbol or the Lumi mascot
        /// (rendered from the DesignSystem asset bundle). Future custom
        /// icons can extend this enum without breaking call sites.
        public enum IconKind: Sendable {
            case system(String)
            case lumi
        }

        public let id: Tab
        public let icon: IconKind
        /// Used for VoiceOver only — the bar itself never renders text.
        public let title: String

        public init(id: Tab, icon: String, title: String) {
            self.id = id
            self.icon = .system(icon)
            self.title = title
        }

        /// Companion-tab init: renders the Lumi mascot in place of an
        /// SF Symbol. Distinct API so it's obvious at the call site.
        public init(id: Tab, lumi _: Void = (), title: String) {
            self.id = id
            self.icon = .lumi
            self.title = title
        }
    }

    @Environment(\.theme) private var theme
    @Binding private var selection: Tab
    private let items: [Item]
    private let centerAccessoryEnabled: Bool
    private let centerAccessoryAction: (() -> Void)?

    public init(
        selection: Binding<Tab>,
        items: [Item],
        centerAccessoryEnabled: Bool = false,
        centerAccessoryAction: (() -> Void)? = nil
    ) {
        _selection = selection
        self.items = items
        self.centerAccessoryEnabled = centerAccessoryEnabled
        self.centerAccessoryAction = centerAccessoryAction
    }

    public var body: some View {
        // Docked bar — spans the full width and sits flush at the
        // bottom of the screen. The glass surface extends through the
        // home-indicator zone (`.ignoresSafeArea(.container, edges:
        // .bottom)` on the background only), while the icon row stays
        // above the safe area so taps don't collide with the home
        // indicator.
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                ForEach(items) { item in
                    tabButton(for: item)
                }
            }
            .padding(.horizontal, Tokens.Spacing.s)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                // Background extends down through the home-indicator
                // area so the bar reads as docked at the very bottom
                // of the screen instead of floating above it.
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea(.container, edges: .bottom)
            )
            .overlay(alignment: .top) {
                // Hairline along the top edge so the bar reads as a
                // distinct surface against the page above it.
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)
            }

            if centerAccessoryEnabled, let centerAccessoryAction {
                centerPlusButton(action: centerAccessoryAction)
                    // FAB still hovers above the docked bar, ~8pt gap.
                    .offset(y: -56)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .animation(Tokens.Easing.glide, value: centerAccessoryEnabled)
    }

    @ViewBuilder
    private func tabButton(for item: Item) -> some View {
        let isSelected = item.id == selection
        let action: () -> Void = {
            HapticEngine.shared.play(.tap)
            withAnimation(Tokens.Easing.pop) { selection = item.id }
        }
        Button(action: action) {
            iconView(for: item.icon)
                .frame(width: 48, height: 44)
                .background(
                    Group {
                        if isSelected {
                            Color(hex: theme.palette.primaryHex).opacity(0.25)
                        }
                    }
                )
                .clipShape(Circle())
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func iconView(for kind: Item.IconKind) -> some View {
        switch kind {
        case .system(let symbol):
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
        case .lumi:
            // The mascot is a colored character — never tint it. Keep the
            // footprint consistent with the 20pt SF Symbols around it.
            Image("Lumi", bundle: .module)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 28, height: 28)
        }
    }

    private func centerPlusButton(action: @escaping () -> Void) -> some View {
        Button {
            HapticEngine.shared.play(.tap)
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
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
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.32), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quick add")
    }
}
