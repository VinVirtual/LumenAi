import AVFoundation
import Core
import Foundation

/// Sound packs are bundled JSON manifests + AAC files; users can also download
/// extra packs from Supabase Storage.
public struct SoundPack: Identifiable, Codable, Sendable {
    public let id: String
    public let displayName: String
    public let chimeURL: URL
    public let nudgeURL: URL
}

@MainActor
public final class SoundPackStore: ObservableObject {
    @Published public private(set) var packs: [SoundPack] = []
    @Published public private(set) var activePackID: String

    private let userDefaults: UserDefaults
    private let player = AVAudioPlayer()

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        activePackID = userDefaults.string(forKey: "lumen.soundpack") ?? "default"
        loadBundled()
    }

    private func loadBundled() {
        guard let url = Bundle.main.url(forResource: "soundpacks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([SoundPack].self, from: data)
        else { return }
        packs = decoded
    }

    public func select(_ pack: SoundPack) {
        activePackID = pack.id
        userDefaults.set(pack.id, forKey: "lumen.soundpack")
    }

    public func preview(_ pack: SoundPack) {
        Task { @MainActor in
            do {
                let p = try AVAudioPlayer(contentsOf: pack.chimeURL)
                p.prepareToPlay()
                p.play()
            } catch {
                LumenLog.app.error("preview failed: \(error.localizedDescription)")
            }
        }
    }
}
