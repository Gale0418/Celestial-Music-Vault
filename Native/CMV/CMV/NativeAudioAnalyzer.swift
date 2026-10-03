import AVFoundation
import CMVDomain

/// Apple-only PCM acquisition adapter. Feature calculation is delegated to the
/// Rust value core through CMVCoreRSClient so analysis is reproducible offline.
actor NativeAudioAnalyzer: AudioAnalyzer {
    private let rust = CMVCoreRSClient()
    private var cancelled: Set<UUID> = []
    private var inFlight: [UUID: Set<UUID>] = [:]

    func cancel(trackID: UUID) {
        guard let requests = inFlight[trackID] else { return }
        cancelled.formUnion(requests)
    }

    func analyze(trackID: UUID, url: URL) async throws -> AnalysisProfile {
        try Task.checkCancellation()
        let requestID = UUID()
        inFlight[trackID, default: []].insert(requestID)
        defer {
            inFlight[trackID]?.remove(requestID)
            if inFlight[trackID]?.isEmpty == true { inFlight.removeValue(forKey: trackID) }
            cancelled.remove(requestID)
        }
        let ownsSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if ownsSecurityScope { url.stopAccessingSecurityScopedResource() }
        }
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let rawChannelCount = format.channelCount
        let rawSampleRate = format.sampleRate
        guard rawChannelCount > 0,
              rawChannelCount <= AVAudioChannelCount(UInt16.max),
              rawSampleRate.isFinite,
              rawSampleRate > 0,
              rawSampleRate <= Double(UInt32.max),
              file.length >= 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let channels = UInt16(rawChannelCount)
        let channelCount = Int(channels)
        let sampleRateHz = UInt32(rawSampleRate.rounded())
        // Bound the interleaved sample window as well as frames. A large
        // channel count must not turn the frame limit into an unbounded
        // reserve or buffer allocation.
        let maxAnalysisFrames = max(1, min(2_000_000, 4_000_000 / channelCount))
        let frameCapacity = AVAudioFrameCount(
            min(16_384, min(Int64(maxAnalysisFrames), max(1, file.length)))
        )
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity),
              let channelData = buffer.floatChannelData else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Keep analysis bounded for very long recordings. We retain the first
        // bounded PCM window at its original rate; unlike frame dropping this
        // never introduces aliasing into BPM, key, or loudness features.
        var samples: [Float] = []
        samples.reserveCapacity(Int(min(file.length, Int64(maxAnalysisFrames))) * channelCount)
        var globalFrame = 0
        while file.framePosition < file.length {
            try Task.checkCancellation()
            if cancelled.contains(requestID) { throw CancellationError() }
            try file.read(into: buffer)
            let frames = min(Int(buffer.frameLength), maxAnalysisFrames - globalFrame)
            guard frames > 0 else { break }
            for frame in 0..<frames {
                for channel in 0..<channelCount {
                    let sample = channelData[channel][frame]
                    guard sample.isFinite else { throw CocoaError(.fileReadCorruptFile) }
                    samples.append(sample)
                }
                globalFrame += 1
            }
            await Task.yield()
            if globalFrame >= maxAnalysisFrames { break }
        }
        guard !samples.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        try Task.checkCancellation()
        if cancelled.contains(requestID) { throw CancellationError() }
        let result = try rust.analyzePCM(samples: samples, sampleRateHz: sampleRateHz, channels: channels)
        try Task.checkCancellation()
        if cancelled.contains(requestID) { throw CancellationError() }
        let key = result.musicalKey.map(Self.keyName)
        return AnalysisProfile(version: Int(result.version), bpm: result.bpm, musicalKey: key,
                               integratedLoudnessLUFS: result.integratedLoudnessLUFS,
                               energy: result.energy, brightness: result.brightness)
    }

    private static func keyName(_ value: UInt8) -> String {
        ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"][Int(value) % 12]
    }
}
