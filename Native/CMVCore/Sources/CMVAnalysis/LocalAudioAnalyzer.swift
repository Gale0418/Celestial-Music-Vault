import Foundation
import AVFoundation
import Accelerate
import CMVDomain

public actor LocalAudioAnalyzer: AudioAnalyzer {
    private var cancelled: Set<UUID> = []
    private var inFlight: Set<UUID> = []
    public init() {}

    public func cancel(trackID: UUID) {
        guard inFlight.contains(trackID) else { return }
        cancelled.insert(trackID)
    }

    public func analyze(trackID: UUID, url: URL) async throws -> AnalysisProfile {
        inFlight.insert(trackID)
        defer {
            inFlight.remove(trackID)
            cancelled.remove(trackID)
        }
        guard cancelled.remove(trackID) == nil else { throw CancellationError() }
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard format.sampleRate.isFinite, format.sampleRate > 0,
              format.channelCount > 0, file.length > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let capacity = AVAudioFrameCount(min(16_384, file.length))
        guard capacity > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var sumSquares = 0.0
        var sampleCount = 0
        var peak: Float = 0
        while file.framePosition < file.length {
            if cancelled.remove(trackID) != nil || Task.isCancelled { throw CancellationError() }
            try file.read(into: buffer)
            guard let channels = buffer.floatChannelData else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let frames = Int(buffer.frameLength)
            guard frames > 0 else { throw CocoaError(.fileReadCorruptFile) }
            for channel in 0..<Int(format.channelCount) {
                var rms: Float = 0
                vDSP_rmsqv(channels[channel], 1, &rms, vDSP_Length(frames))
                var localPeak: Float = 0
                vDSP_maxmgv(channels[channel], 1, &localPeak, vDSP_Length(frames))
                guard rms.isFinite, localPeak.isFinite else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                sumSquares += Double(rms * rms) * Double(frames)
                peak = max(peak, localPeak)
                sampleCount += frames
            }
            await Task.yield()
        }
        guard sampleCount > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let rms = sqrt(sumSquares / Double(sampleCount))
        guard rms.isFinite else { throw CocoaError(.fileReadCorruptFile) }
        let loudness = 20 * log10(max(rms, 0.000_001)) - 0.691
        guard loudness.isFinite else { throw CocoaError(.fileReadCorruptFile) }
        return AnalysisProfile(integratedLoudnessLUFS: loudness,
                               energy: min(1, max(0, rms * 4)),
                               brightness: min(1, max(0, Double(peak) - rms)))
    }
}