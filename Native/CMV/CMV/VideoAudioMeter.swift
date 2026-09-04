import AVFoundation
import MediaToolbox

/// Reads decoded PCM from an AVPlayerItem without altering the movie's audio.
/// The realtime callback only calculates RMS; observable state is published on
/// the main actor so the moon ring can share the audio player's visual model.
enum VideoAudioMeter {
    @MainActor
    static func install(
        on item: AVPlayerItem,
        audioTrack: AVAssetTrack,
        onLevel: @escaping @MainActor @Sendable (Float) -> Void
    ) throws {
        let context = VideoAudioMeterContext(onLevel: onLevel)
        let retainedContext = Unmanaged.passRetained(context)
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: retainedContext.toOpaque(),
            init: videoMeterInitialize,
            finalize: videoMeterFinalize,
            prepare: videoMeterPrepare,
            unprepare: videoMeterUnprepare,
            process: videoMeterProcess
        )
        var tap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tap
        )
        guard status == noErr, let tap else {
            // Creation failed before the tap assumed ownership of clientInfo.
            retainedContext.release()
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }

        let parameters = AVMutableAudioMixInputParameters(track: audioTrack)
        parameters.audioTapProcessor = tap
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        item.audioMix = mix
    }
}

private final class VideoAudioMeterContext: @unchecked Sendable {
    let onLevel: @MainActor @Sendable (Float) -> Void
    var format = AudioStreamBasicDescription()
    var framesUntilUpdate: CMItemCount = 0

    init(onLevel: @escaping @MainActor @Sendable (Float) -> Void) {
        self.onLevel = onLevel
    }

    func prepare(format: AudioStreamBasicDescription) {
        self.format = format
        framesUntilUpdate = 0
    }

    func consume(_ buffers: UnsafeMutableAudioBufferListPointer, frames: CMItemCount) {
        framesUntilUpdate -= frames
        guard framesUntilUpdate <= 0 else { return }
        framesUntilUpdate = max(1, CMItemCount(format.mSampleRate / 30))

        guard format.mFormatID == kAudioFormatLinearPCM,
              format.mFormatFlags & kAudioFormatFlagIsFloat != 0 else { return }

        var sumOfSquares: Float = 0
        var sampleCount = 0
        for buffer in buffers {
            guard let data = buffer.mData else { continue }
            if format.mBitsPerChannel == 64 {
                let count = Int(buffer.mDataByteSize) / MemoryLayout<Double>.stride
                let samples = data.assumingMemoryBound(to: Double.self)
                for index in 0..<count {
                    let sample = Float(samples[index])
                    sumOfSquares += sample * sample
                }
                sampleCount += count
            } else {
                let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.stride
                let samples = data.assumingMemoryBound(to: Float.self)
                for index in 0..<count {
                    let sample = samples[index]
                    sumOfSquares += sample * sample
                }
                sampleCount += count
            }
        }
        guard sampleCount > 0 else { return }
        let rms = sqrt(sumOfSquares / Float(sampleCount))
        let decibels = 20 * log10(max(rms, 0.000_001))
        let normalized = min(1, max(0, (decibels + 60) / 60))
        Task { @MainActor [onLevel] in onLevel(normalized) }
    }
}

private func videoMeterInitialize(
    _ tap: MTAudioProcessingTap,
    _ clientInfo: UnsafeMutableRawPointer?,
    _ tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) {
    tapStorageOut.pointee = clientInfo
}

private func videoMeterFinalize(_ tap: MTAudioProcessingTap) {
    let storage = MTAudioProcessingTapGetStorage(tap)
    Unmanaged<VideoAudioMeterContext>.fromOpaque(storage).release()
}

private func videoMeterPrepare(
    _ tap: MTAudioProcessingTap,
    _ maxFrames: CMItemCount,
    _ processingFormat: UnsafePointer<AudioStreamBasicDescription>
) {
    let context = Unmanaged<VideoAudioMeterContext>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    context.prepare(format: processingFormat.pointee)
}

private func videoMeterUnprepare(_ tap: MTAudioProcessingTap) {}

private func videoMeterProcess(
    _ tap: MTAudioProcessingTap,
    _ numberFrames: CMItemCount,
    _ flags: MTAudioProcessingTapFlags,
    _ bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
    _ numberFramesOut: UnsafeMutablePointer<CMItemCount>,
    _ flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    let status = MTAudioProcessingTapGetSourceAudio(
        tap,
        numberFrames,
        bufferListInOut,
        flagsOut,
        nil,
        numberFramesOut
    )
    guard status == noErr, numberFramesOut.pointee > 0 else { return }
    let context = Unmanaged<VideoAudioMeterContext>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    context.consume(
        UnsafeMutableAudioBufferListPointer(bufferListInOut),
        frames: numberFramesOut.pointee
    )
}
