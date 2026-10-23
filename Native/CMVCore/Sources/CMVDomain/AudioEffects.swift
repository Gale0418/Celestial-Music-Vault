import Foundation

/// The effect families exposed by the player. `original` is the neutral
/// baseline and is intentionally separate from `custom` so a malformed custom
/// payload can never change the default playback path.
public enum AudioEffectPreset: String, CaseIterable, Codable, Sendable {
    case original
    case bassBoost
    case vocal
    case electronic
    case saturn
    case orbit
    case sewer
    case deepSpaceRadio
    case cassette
    case underwater
    case cathedral
    case bathroom
    case custom
}

public struct AudioEffectParameters: Codable, Equatable, Sendable {
    public var reverb: Double
    public var delay: Double
    public var bass: Double
    public var filter: Double
    public var width: Double
    public var distortion: Double

    public init(
        reverb: Double = 0,
        delay: Double = 0,
        bass: Double = 0,
        filter: Double = 20_000,
        width: Double = 1,
        distortion: Double = 0
    ) {
        self.reverb = reverb
        self.delay = delay
        self.bass = bass
        self.filter = filter
        self.width = width
        self.distortion = distortion
    }

    /// Returns a finite, bounded value suitable for both AVAudioUnit
    /// parameters and offline DSP. NaN is deliberately replaced with the
    /// neutral value rather than being passed through `min`/`max`.
    public var validated: Self {
        Self(
            reverb: Self.finite(reverb, fallback: 0).clamped(to: 0...100),
            delay: Self.finite(delay, fallback: 0).clamped(to: 0...500),
            bass: Self.finite(bass, fallback: 0).clamped(to: -12...12),
            filter: Self.finite(filter, fallback: 20_000).clamped(to: 150...20_000),
            width: Self.finite(width, fallback: 1).clamped(to: 0...2),
            distortion: Self.finite(distortion, fallback: 0).clamped(to: 0...100)
        )
    }

    private static func finite(_ value: Double, fallback: Double) -> Double {
        value.isFinite ? value : fallback
    }
}

public struct AudioEffectsSettings: Codable, Equatable, Sendable {
    public var preset: AudioEffectPreset
    public var intensity: Double
    public var custom: AudioEffectParameters

    public init(
        preset: AudioEffectPreset = .original,
        intensity: Double = 0.3,
        custom: AudioEffectParameters = AudioEffectParameters()
    ) {
        self.preset = preset
        self.intensity = intensity
        self.custom = custom
    }

    public var validated: Self {
        Self(
            preset: preset,
            intensity: intensity.isFinite ? intensity.clamped(to: 0...1) : 0,
            custom: custom.validated
        )
    }

    /// Parameters selected by the preset. Custom values are used only for
    /// `.custom`; this makes preset restoration deterministic across devices.
    public var effectiveParameters: AudioEffectParameters {
        preset == .custom ? custom.validated : AudioEffectPresetLibrary.parameters(for: preset)
    }
}

private enum AudioEffectPresetLibrary {
    static func parameters(for preset: AudioEffectPreset) -> AudioEffectParameters {
        switch preset {
        case .original:
            return AudioEffectParameters()
        case .bassBoost:
            return AudioEffectParameters(bass: 8, filter: 18_000, width: 1.05)
        case .vocal:
            return AudioEffectParameters(reverb: 4, bass: 2, filter: 10_000)
        case .electronic:
            return AudioEffectParameters(delay: 30, bass: 5, filter: 16_000, width: 1.25, distortion: 5)
        case .saturn:
            return AudioEffectParameters(reverb: 28, delay: 220, bass: 2, filter: 8_000, width: 1.4)
        case .orbit:
            // The live player applies a slow stereo-bus pan; this is movement
            // between left/right speakers, deliberately not 3D positioning.
            return AudioEffectParameters(reverb: 12, delay: 80, filter: 16_000, width: 1.8)
        case .sewer:
            return AudioEffectParameters(reverb: 42, delay: 35, bass: -2, filter: 7_000, width: 0.8)
        case .deepSpaceRadio:
            return AudioEffectParameters(reverb: 18, delay: 160, bass: -3, filter: 3_200, distortion: 12)
        case .cassette:
            // The playback implementation uses short fixed delays and mild
            // saturation. It does not modulate AVAudioPlayerNode's rate.
            return AudioEffectParameters(reverb: 6, delay: 12, bass: 1, filter: 11_000, width: 0.95, distortion: 8)
        case .underwater:
            return AudioEffectParameters(reverb: 22, delay: 55, bass: 4, filter: 1_200, width: 0.9)
        case .cathedral:
            return AudioEffectParameters(reverb: 62, delay: 170, bass: 1, filter: 15_000, width: 1.2)
        case .bathroom:
            return AudioEffectParameters(reverb: 30, delay: 22, filter: 14_000, width: 1.1)
        case .custom:
            return AudioEffectParameters()
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}
