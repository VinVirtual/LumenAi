import SwiftUI

/// Accessibility convenience modifiers for Lumen's frosted UI. Ensures that
/// glass surfaces remain legible under Reduce Transparency, that Aurora
/// animations honor Reduce Motion, and that decorative elements are hidden
/// from VoiceOver.
public extension View {
    /// Wraps a glass background with an opaque fallback when Reduce
    /// Transparency is enabled.
    @ViewBuilder
    func reduceTransparencyFallback(_ fallback: Color) -> some View {
        if UIAccessibility.isReduceTransparencyEnabled {
            background(fallback)
        } else {
            self
        }
    }

    /// Hide a decorative view from VoiceOver / accessibility tooling.
    func decorative() -> some View {
        accessibilityHidden(true)
            .accessibilityElement(children: .ignore)
    }

    /// Apply a baseline of accessibility metadata to interactive cards.
    func cardAccessibility(label: String, hint: String? = nil) -> some View {
        accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
}
