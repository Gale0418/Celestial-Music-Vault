import Foundation
import AVFoundation
import Accelerate
import CMVDomain

public actor LocalAudioAnalyzer: AudioAnalyzer {
    private var cancelled: Set<UUID> = []
    public init() {}

    public func cancel(trackID: UUID) { cancelled.insert(trackID) }

    public func analyze(trackID: UUID, url: URL) async throws -> AnalysisProfile {
        cancelled.remove(trackID)
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let capacity = AVAudioFrameCount(min(16_384, max(1, file.length)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var sumSquares = 0.0
        var sampleCount = 0
        var peak: Float = 0
        while file.framePosition < file.length {
            if cancelled.contains(trackID) || Task.isCancelled { throw CancellationError() }
            try file.read(into: buffer)
            guard let channels = buffer.floatChannelData else { continue }
            let frames = Int(buffer.frameLength)
            for channel in 0..<Int(format.channelCount) {
                var rms: Float = 0
                vDSP_rmsqv(channels[channel], 1, &rms, vDSP_Length(frames))
                sumSquares += Double(rms * rms) * Double(frames)
                var localPeak: Float = 0
                vDSP_maxmgv(channels[channel], 1, &localPeak, vDSP_Length(frames))
                peak = max(peak, localPeak)
                sampleCount += frames
            }
            await Task.yield()
        }
        let rms = sqrt(sumSquares / Double(max(1, sampleCount)))
        let loudness = 20 * log10(max(rms, 0.000_001)) - 0.691
        return AnalysisProfile(integratedLoudnessLUFS: loudness,
                               energy: min(1, max(0, rms * 4)),
                               brightness: min(1, max(0, Double(peak - Float(rms)))))
    }
}
