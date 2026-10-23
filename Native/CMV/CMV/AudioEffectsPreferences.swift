import Foundation
import CMVDomain

enum AudioEffectsPreferences {
    static let key = "CMV.audioEffects.v1"

    static func load(from defaults: UserDefaults) -> AudioEffectsSettings {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(AudioEffectsSettings.self, from: data) else {
            return AudioEffectsSettings()
        }
        return saved.validated
    }

    static func save(_ settings: AudioEffectsSettings, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(settings.validated) else { return }
        defaults.set(data, forKey: key)
    }
}
