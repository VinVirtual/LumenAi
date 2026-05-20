import Intents

/// Stub handler for the legacy intents extension. App Intents (above) handle
/// the modern flow; this exists so the extension's principal class can be
/// resolved.
final class IntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        self
    }
}
