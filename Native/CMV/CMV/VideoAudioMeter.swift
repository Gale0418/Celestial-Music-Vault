import AVFoundation
import MediaToolbox
import Synchronization
import CMVPlayback
import CMVDomain

/// 描述影片 tap 的實際音效路由能力。`dry*` 狀態都代表播放器保留原音，
/// 不會假裝音效已套用。
enum VideoAudioRouteStatus: Equatable, Sendable {
    case pending
    case supported
    case dryNoAudioTrack
    case dryStreamingAsset
    case dryMultipleAudioTracks
    case dryUnsupportedFormat
    case dryTapUnavailable
    case dryProcessingFailed

    var allowsEffects: Bool { self == .pending || self == .supported }
}

/// Mirrors the renderer's active predicate so neutral custom settings wait
/// for an accepted tap buffer, while non-neutral settings require wet proof.
func videoMeterRequiresWetRender(_ settings: AudioEffectsSettings) -> Bool {
    let validated = settings.validated
    let parameters = validated.effectiveParameters.validated
    let isNeutral = parameters.reverb == 0
        && parameters.delay == 0
        && parameters.bass == 0
        && parameters.filter >= 19_999.999
        && parameters.width == 1
        && parameters.distortion == 0
    return validated.intensity > 0 && !isNeutral
}

/// Holds the one audio tap attached to the AVPlayerItem. The audio callback
/// only copies source PCM, renders into preallocated state, and stores the
/// latest meter value atomically. Main-actor UI work is performed by the
/// session's timer.
@MainActor
final class VideoAudioTapHandle {
    private let context: VideoAudioMeterContext
    private(set) var status: VideoAudioRouteStatus = .pending

    fileprivate init(context: VideoAudioMeterContext) { self.context = context }

    var latestLevel: Float { context.latestLevel }

    /// QA and session state use this to distinguish a prepared graph from a
    /// graph that has actually rendered at least one tap buffer.
    var hasProcessedAudio: Bool { context.hasProcessedAudio }

    func prepareIfNeeded(settings: AudioEffectsSettings) -> VideoAudioRouteStatus {
        if context.awaitingPreparation {
            status = .pending
        }
        guard let preparation = context.pendingPreparation() else {
            return status
        }
        if status != .pending { status = .pending }
        guard context.isIdle else { return status }
        guard videoMeterSupports(preparation.asbd) else {
            status = context.discardPending(generation: preparation.generation)
                ? .dryUnsupportedFormat : .pending
            return status
        }
        do {
            // Native taps may unprepare and prepare again during seek/route
            // changes. The old manual graph must be disposed before a new
            // ASBD is handed to prepare, even when the tap object survives.
            context.renderer.unprepare()
            try context.renderer.prepare(
                actualASBD: preparation.asbd,
                maxFrames: preparation.maxFrames
            )
            context.renderer.update(settings: settings)
            context.resetProcessingObservation()
            guard context.markPrepared(generation: preparation.generation) else {
                if context.isIdle {
                    context.renderer.unprepare()
                } else {
                    context.scheduleUnprepareWhenIdle(expectedGeneration: preparation.generation)
                }
                return .pending
            }
            // Keep the user-facing state as "preparing" until processAudio
            // has returned success for a real tap buffer.
        } catch {
            status = context.discardPending(generation: preparation.generation)
                ? .dryUnsupportedFormat : .pending
        }
        return status
    }

    func markSupportedIfProcessed(settings: AudioEffectsSettings) -> VideoAudioRouteStatus {
        let requiresWetRender = videoMeterRequiresWetRender(settings)
        let processed = requiresWetRender ? context.hasWetRendered : hasProcessedAudio
        if status == .pending, processed { status = .supported }
        if status == .pending, context.lastProcessFailed { status = .dryProcessingFailed }
        if status == .supported, context.lastProcessFailed { status = .dryProcessingFailed }
        return status
    }

    func update(settings: AudioEffectsSettings) {
        guard context.isPrepared || status == .supported || status == .dryProcessingFailed else { return }
        context.renderer.update(settings: settings)
        context.resetProcessingObservation()
        if status == .supported || status == .dryProcessingFailed { status = .pending }
    }

    /// Call after removing the tap from the AVPlayerItem's audio mix.
    func detach() {
        context.disable()
        if context.isIdle {
            context.renderer.unprepare()
        } else {
            context.scheduleUnprepareWhenIdle()
        }
        status = .dryTapUnavailable
    }
}

enum VideoAudioMeter {
    @MainActor
    static func install(
        on item: AVPlayerItem,
        audioTrack: AVAssetTrack
    ) throws -> VideoAudioTapHandle {
        let context = VideoAudioMeterContext()
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
        return VideoAudioTapHandle(context: context)
    }
}

private func videoMeterSupports(_ asbd: AudioStreamBasicDescription) -> Bool {
    let sampleRateSupported = abs(asbd.mSampleRate - 44_100) < 0.5
        || abs(asbd.mSampleRate - 48_000) < 0.5
    return asbd.mFormatID == kAudioFormatLinearPCM
        && asbd.mFormatFlags & kAudioFormatFlagsNativeFloatPacked == kAudioFormatFlagsNativeFloatPacked
        && asbd.mBitsPerChannel == 32
        && (asbd.mChannelsPerFrame == 1 || asbd.mChannelsPerFrame == 2)
        && asbd.mBytesPerFrame > 0
        && asbd.mFramesPerPacket > 0
        && asbd.mBytesPerPacket > 0
        && sampleRateSupported
}

// Internal for the focused lifecycle tests. The type is not part of the app's
// public API; production code reaches it only through VideoAudioTapHandle.
final class VideoAudioMeterContext: @unchecked Sendable {
    let renderer = CMVVideoAudioEffectsRenderer()
    private let latestLevelBits = Atomic<UInt32>(0)
    private let prepared = Atomic<UInt8>(0)
    private let disabled = Atomic<UInt8>(0)
    private let inProcess = Atomic<UInt8>(0)
    private let didProcessAudio = Atomic<UInt8>(0)
    private let lastProcessSucceeded = Atomic<UInt8>(0)
    private let wetRenderBaseline = Atomic<UInt64>(0)
    private let lifecycleGeneration = Atomic<UInt64>(0)
    private let pendingGeneration = Atomic<UInt64>(0)
    private let preparedGeneration = Atomic<UInt64>(0)
    private let needsPreparation = Atomic<UInt8>(0)
    private let asbdSequence = Atomic<UInt64>(0)

    private let sampleRateBits = Atomic<UInt64>(0)
    private let formatID = Atomic<UInt32>(0)
    private let formatFlags = Atomic<UInt32>(0)
    private let bitsPerChannel = Atomic<UInt32>(0)
    private let channelsPerFrame = Atomic<UInt32>(0)
    private let bytesPerPacket = Atomic<UInt32>(0)
    private let framesPerPacket = Atomic<UInt32>(0)
    private let bytesPerFrame = Atomic<UInt32>(0)
    private let reserved = Atomic<UInt32>(0)
    private let maximumFrameCount = Atomic<UInt32>(0)

    var format = AudioStreamBasicDescription()
    var framesUntilUpdate: CMItemCount = 0

    var latestLevel: Float {
        Float(bitPattern: latestLevelBits.load(ordering: .relaxed))
    }

    var hasProcessedAudio: Bool {
        didProcessAudio.load(ordering: .acquiring) != 0
    }

    var hasWetRendered: Bool {
        guard isPrepared,
              preparedGeneration.load(ordering: .acquiring)
                  == lifecycleGeneration.load(ordering: .acquiring),
              hasProcessedAudio else { return false }
        return renderer.successfulWetRenderCount > wetRenderBaseline.load(ordering: .acquiring)
    }

    var lastProcessFailed: Bool {
        lastProcessSucceeded.load(ordering: .acquiring) == 2
    }

    var isPrepared: Bool { prepared.load(ordering: .acquiring) != 0 }
    var awaitingPreparation: Bool {
        needsPreparation.load(ordering: .acquiring) != 0
    }

    var isIdle: Bool { inProcess.load(ordering: .acquiring) == 0 }

    func prepare(format: AudioStreamBasicDescription, maxFrames: CMItemCount) {
        self.format = format
        framesUntilUpdate = 0
        let generation = lifecycleGeneration.load(ordering: .relaxed) &+ 1
        lifecycleGeneration.store(generation, ordering: .relaxed)
        let sequence = asbdSequence.load(ordering: .relaxed) &+ 1
        asbdSequence.store(sequence | 1, ordering: .releasing)
        sampleRateBits.store(format.mSampleRate.bitPattern, ordering: .relaxed)
        formatID.store(format.mFormatID, ordering: .relaxed)
        formatFlags.store(format.mFormatFlags, ordering: .relaxed)
        bitsPerChannel.store(format.mBitsPerChannel, ordering: .relaxed)
        channelsPerFrame.store(format.mChannelsPerFrame, ordering: .relaxed)
        bytesPerPacket.store(format.mBytesPerPacket, ordering: .relaxed)
        framesPerPacket.store(format.mFramesPerPacket, ordering: .relaxed)
        bytesPerFrame.store(format.mBytesPerFrame, ordering: .relaxed)
        reserved.store(format.mReserved, ordering: .relaxed)
        maximumFrameCount.store(UInt32(clamping: maxFrames), ordering: .relaxed)
        pendingGeneration.store(generation, ordering: .relaxed)
        needsPreparation.store(0, ordering: .relaxed)
        asbdSequence.store((sequence | 1) &+ 1, ordering: .releasing)
    }

    func pendingPreparation() -> (asbd: AudioStreamBasicDescription, maxFrames: AVAudioFrameCount, generation: UInt64)? {
        guard pendingGeneration.load(ordering: .acquiring) != 0,
              disabled.load(ordering: .acquiring) == 0 else { return nil }
        for _ in 0..<3 {
            let firstSequence = asbdSequence.load(ordering: .acquiring)
            guard firstSequence & 1 == 0 else { continue }
            var asbd = AudioStreamBasicDescription()
            asbd.mSampleRate = Double(bitPattern: sampleRateBits.load(ordering: .relaxed))
            asbd.mFormatID = formatID.load(ordering: .relaxed)
            asbd.mFormatFlags = formatFlags.load(ordering: .relaxed)
            asbd.mBitsPerChannel = bitsPerChannel.load(ordering: .relaxed)
            asbd.mChannelsPerFrame = channelsPerFrame.load(ordering: .relaxed)
            asbd.mBytesPerPacket = bytesPerPacket.load(ordering: .relaxed)
            asbd.mFramesPerPacket = framesPerPacket.load(ordering: .relaxed)
            asbd.mBytesPerFrame = bytesPerFrame.load(ordering: .relaxed)
            asbd.mReserved = reserved.load(ordering: .relaxed)
            let frameCount = maximumFrameCount.load(ordering: .relaxed)
            let generation = pendingGeneration.load(ordering: .relaxed)
            let secondSequence = asbdSequence.load(ordering: .acquiring)
            guard firstSequence == secondSequence,
                  frameCount > 0,
                  generation != 0,
                  generation == pendingGeneration.load(ordering: .acquiring),
                  generation == lifecycleGeneration.load(ordering: .acquiring),
                  disabled.load(ordering: .acquiring) == 0 else { continue }
            return (asbd, AVAudioFrameCount(frameCount), generation)
        }
        return nil
    }

    func markPrepared(generation: UInt64) -> Bool {
        guard lifecycleGeneration.load(ordering: .acquiring) == generation,
              disabled.load(ordering: .acquiring) == 0,
              pendingGeneration.compareExchange(
                  expected: generation,
                  desired: 0,
                  ordering: .acquiringAndReleasing
              ).exchanged else { return false }
        guard lifecycleGeneration.load(ordering: .acquiring) == generation,
              disabled.load(ordering: .acquiring) == 0 else { return false }
        needsPreparation.store(0, ordering: .relaxed)
        preparedGeneration.store(generation, ordering: .relaxed)
        prepared.store(1, ordering: .releasing)
        return true
    }

    func markDry(requiresPreparation: Bool = false) {
        let generation = lifecycleGeneration.load(ordering: .relaxed) &+ 1
        lifecycleGeneration.store(generation, ordering: .relaxed)
        pendingGeneration.store(0, ordering: .releasing)
        prepared.store(0, ordering: .releasing)
        needsPreparation.store(requiresPreparation ? 1 : 0, ordering: .relaxed)
        preparedGeneration.store(0, ordering: .relaxed)
        didProcessAudio.store(0, ordering: .relaxed)
        lastProcessSucceeded.store(0, ordering: .relaxed)
        latestLevelBits.store(0, ordering: .relaxed)
    }

    /// Drops only the candidate observed by the current main-actor poll. A
    /// newer native prepare wins the CAS and remains pending for the next poll.
    func discardPending(generation: UInt64) -> Bool {
        guard pendingGeneration.compareExchange(
            expected: generation,
            desired: 0,
            ordering: .acquiringAndReleasing
        ).exchanged,
        lifecycleGeneration.load(ordering: .acquiring) == generation else { return false }
        prepared.store(0, ordering: .releasing)
        preparedGeneration.store(0, ordering: .relaxed)
        didProcessAudio.store(0, ordering: .relaxed)
        lastProcessSucceeded.store(0, ordering: .relaxed)
        latestLevelBits.store(0, ordering: .relaxed)
        return true
    }

    func resetProcessingObservation() {
        didProcessAudio.store(0, ordering: .relaxed)
        lastProcessSucceeded.store(0, ordering: .relaxed)
        wetRenderBaseline.store(renderer.successfulWetRenderCount, ordering: .releasing)
    }

    func disable() {
        disabled.store(1, ordering: .releasing)
        pendingGeneration.store(0, ordering: .releasing)
        prepared.store(0, ordering: .releasing)
        needsPreparation.store(0, ordering: .relaxed)
        didProcessAudio.store(0, ordering: .relaxed)
        lastProcessSucceeded.store(0, ordering: .relaxed)
        latestLevelBits.store(0, ordering: .relaxed)
    }

    func scheduleUnprepareWhenIdle(expectedGeneration: UInt64? = nil) {
        let context = self
        let timer = Timer(timeInterval: 0.001, repeats: true) { timer in
            if let expectedGeneration,
               context.preparedGeneration.load(ordering: .acquiring) > expectedGeneration {
                timer.invalidate()
                return
            }
            guard context.isIdle else { return }
            MainActor.assumeIsolated {
                context.renderer.unprepare()
            }
            timer.invalidate()
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    func process(
        audioBufferList: UnsafeMutablePointer<AudioBufferList>,
        frames: CMItemCount
    ) {
        guard inProcess.exchange(1, ordering: .acquiringAndReleasing) == 0 else { return }
        defer { inProcess.store(0, ordering: .releasing) }
        guard disabled.load(ordering: .acquiring) == 0 else { return }
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let lifecycle = lifecycleGeneration.load(ordering: .acquiring)
        let preparedToken = preparedGeneration.load(ordering: .acquiring)
        if prepared.load(ordering: .acquiring) != 0,
           preparedToken != 0,
           preparedToken == lifecycle {
            let processed = renderer.processAudioBufferList(
                frameCount: AVAudioFrameCount(frames),
                audioBufferList: audioBufferList
            )
            lastProcessSucceeded.store(processed ? 1 : 2, ordering: .releasing)
            if processed { didProcessAudio.store(1, ordering: .releasing) }
        }
        consume(buffers, frames: frames)
    }

    private func consume(
        _ buffers: UnsafeMutableAudioBufferListPointer,
        frames: CMItemCount
    ) {
        framesUntilUpdate -= frames
        guard framesUntilUpdate <= 0 else { return }
        framesUntilUpdate = max(1, CMItemCount(format.mSampleRate / 30))

        guard format.mFormatID == kAudioFormatLinearPCM,
              format.mFormatFlags & kAudioFormatFlagsNativeFloatPacked == kAudioFormatFlagsNativeFloatPacked,
              format.mBitsPerChannel == 32 else { return }

        var sumOfSquares: Float = 0
        var sampleCount = 0
        for buffer in buffers {
            guard let data = buffer.mData else { continue }
            let channelCount = max(1, Int(buffer.mNumberChannels))
            let frameLimit = Int(frames) * channelCount
            let count = min(Int(buffer.mDataByteSize) / MemoryLayout<Float>.stride, frameLimit)
            let samples = data.assumingMemoryBound(to: Float.self)
            for index in 0..<count {
                let sample = samples[index]
                guard sample.isFinite else { continue }
                sumOfSquares += sample * sample
            }
            sampleCount += count
        }
        guard sampleCount > 0 else { return }
        let rms = sqrt(sumOfSquares / Float(sampleCount))
        let decibels = 20 * log10(max(rms, 0.000_001))
        let normalized = min(1, max(0, (decibels + 60) / 60))
        latestLevelBits.store(normalized.bitPattern, ordering: .relaxed)
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
    context.prepare(format: processingFormat.pointee, maxFrames: maxFrames)
}

private func videoMeterUnprepare(_ tap: MTAudioProcessingTap) {
    let context = Unmanaged<VideoAudioMeterContext>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    context.markDry(requiresPreparation: true)
}

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
    context.process(
        audioBufferList: bufferListInOut,
        frames: numberFramesOut.pointee
    )
}
