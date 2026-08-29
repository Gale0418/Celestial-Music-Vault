import AVFoundation
import CMVDomain

/// Apple-only PCM acquisition adapter. Feature calculation is delegated to the
/// Rust value core through CMVCoreRSClient so analysis is reproducible offline.
actor NativeAudioAnalyzer: AudioAnalyzer {
    private let rust = CMVCoreRSClient()
    private var cancelled: Set<UUID> = []

    func cancel(trackID: UUID) {
        cancelled.insert(trackID)
    }

    func analyze(trackID: UUID, url: URL) async throws -> AnalysisProfile {
        cancelled.remove(trackID)
        let ownsSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if ownsSecurityScope { url.stopAccessingSecurityScopedResource() }
        }
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let channels = UInt16(format.channelCount)
        guard channels > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let frameCapacity = AVAudioFrameCount(min(16_384, max(1, file.length)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity),
              let channelData = buffer.floatChannelData else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Keep analysis bounded for very long recordings. We retain the first
        // bounded PCM window at its original rate; unlike frame dropping this
        // never introduces aliasing into BPM, key, or loudness features.
        let maxAnalysisFrames = 2_000_000
        var samples: [Float] = []
        samples.reserveCapacity(Int(min(file.length, Int64(maxAnalysisFrames))) * Int(channels))
        var globalFrame = 0
        while file.framePosition < file.length {
            try Task.checkCancellation()
            if cancelled.contains(trackID) { throw CancellationError() }
            try file.read(into: buffer)
            let frames = min(Int(buffer.frameLength), maxAnalysisFrames - globalFrame)
            guard frames > 0 else { break }
            for frame in 0..<frames {
                for channel in 0..<Int(channels) {
                    samples.append(channelData[channel][frame])
                }
                globalFrame += 1
            }
            await Task.yield()
            if globalFrame >= maxAnalysisFrames { break }
        }
        let result = try rust.analyzePCM(samples: samples, sampleRateHz: UInt32(format.sampleRate.rounded()), channels: channels)
        let key = result.musicalKey.map(Self.keyName)
        return AnalysisProfile(version: Int(result.version), bpm: result.bpm, musicalKey: key,
                               integratedLoudnessLUFS: result.integratedLoudnessLUFS,
                               energy: result.energy, brightness: result.brightness)
    }

    private static func keyName(_ value: UInt8) -> String {
        ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"][Int(value) % 12]
    }
}
