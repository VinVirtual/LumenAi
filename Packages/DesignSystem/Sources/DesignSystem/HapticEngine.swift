import CoreHaptics
import UIKit

/// Wraps `CHHapticEngine` to provide consistent, warm haptic feedback throughout
/// the app. Falls back to `UIImpactFeedbackGenerator` on devices without Core
/// Haptics support.
public final class HapticEngine: @unchecked Sendable {
    public static let shared = HapticEngine()

    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if supportsHaptics {
            do {
                let e = try CHHapticEngine()
                try e.start()
                e.resetHandler = { [weak e] in try? e?.start() }
                e.stoppedHandler = { _ in }
                engine = e
            } catch {
                engine = nil
            }
        }
    }

    public enum Cue {
        case tap
        case success
        case warmGreeting
        case rippleAck
        case error
    }

    public func play(_ cue: Cue) {
        guard supportsHaptics, let engine else {
            fallback(cue)
            return
        }
        do {
            let pattern = try pattern(for: cue)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            fallback(cue)
        }
    }

    private func fallback(_ cue: Cue) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = switch cue {
        case .tap: .light
        case .success: .medium
        case .warmGreeting: .soft
        case .rippleAck: .rigid
        case .error: .heavy
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func pattern(for cue: Cue) throws -> CHHapticPattern {
        switch cue {
        case .tap:
            try CHHapticPattern(events: [
                .init(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.45),
                    .init(parameterID: .hapticSharpness, value: 0.4)
                ], relativeTime: 0)
            ], parameters: [])
        case .success:
            try CHHapticPattern(events: [
                .init(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.6),
                    .init(parameterID: .hapticSharpness, value: 0.3)
                ], relativeTime: 0),
                .init(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.9),
                    .init(parameterID: .hapticSharpness, value: 0.45)
                ], relativeTime: 0.12)
            ], parameters: [])
        case .warmGreeting:
            try CHHapticPattern(events: [
                .init(eventType: .hapticContinuous, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.35),
                    .init(parameterID: .hapticSharpness, value: 0.15)
                ], relativeTime: 0, duration: 0.45)
            ], parameters: [])
        case .rippleAck:
            try CHHapticPattern(events: [
                .init(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.5),
                    .init(parameterID: .hapticSharpness, value: 0.7)
                ], relativeTime: 0),
                .init(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.3),
                    .init(parameterID: .hapticSharpness, value: 0.5)
                ], relativeTime: 0.08)
            ], parameters: [])
        case .error:
            try CHHapticPattern(events: [
                .init(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: 1.0),
                    .init(parameterID: .hapticSharpness, value: 0.85)
                ], relativeTime: 0)
            ], parameters: [])
        }
    }
}
