import AVFoundation
import AudioToolbox
import Synchronization
import CMVDomain

/// Errors reported while preparing the video tap renderer.
public enum CMVVideoAudioEffectsRendererError: LocalizedError, Sendable, Equatable {
    case unsupportedFormat
    case invalidFrameCount
    case alreadyPrepared
    case engineSetupFailed

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "影片音訊只支援 44.1/48 kHz、Float32、mono/stereo 線性 PCM。"
        case .invalidFrameCount:
            return "影片音訊的最大 frame count 必須大於零。"
        case .alreadyPrepared:
            return "影片音效 renderer 已準備完成，請先 unprepare。"
        case .engineSetupFailed:
            return "影片音效 renderer 的即時 manual engine 無法啟動。"
        }
    }
}

/// A lock-free handoff for the source PCM currently owned by the tap callback.
/// The owner must serialize prepare/unprepare with the tap lifecycle. The
/// process callback itself only touches this preallocated state and never
/// allocates, locks, hops to an actor, performs I/O, or schedules a Task.
private final class CMVVideoAudioEffectsRenderState: @unchecked Sendable {
    var engine: AVAudioEngine?
    var sourceNode: AVAudioSourceNode?
    var internalBuffer: AVAudioPCMBuffer?
    var internalAudioBufferList: UnsafeMutablePointer<AudioBufferList>?
    var manualRenderBlock: AVAudioEngineManualRenderingBlock?
    var internalFormat: AVAudioFormat?
    var maximumFrameCount: Int = 0

    var sourceAudioBufferList: UnsafeMutablePointer<AudioBufferList>?
    var sourceChannelCount = 0
    var sourceFrameCount = 0
    var sourceFrameCursor = 0

    var liveEffects: AVAudioUnitEffect?
    var reverb: AVAudioUnitReverb?
    var delay: AVAudioUnitDelay?
    var distortion: AVAudioUnitDistortion?
    var effectsEqualizer: AVAudioUnitEQ?
    var userEqualizer: AVAudioUnitEQ?

    let active = Atomic<UInt8>(0)
    let prepared = Atomic<UInt8>(0)
    let successfulWetRenderCount = Atomic<UInt64>(0)
    let presetIndex = Atomic<UInt8>(0)
    let intensityBits = Atomic<UInt64>(Double(0.3).bitPattern)
    let reverbBits = Atomic<UInt64>(Double(0).bitPattern)
    let delayBits = Atomic<UInt64>(Double(0).bitPattern)
    let bassBits = Atomic<UInt64>(Double(0).bitPattern)
    let filterBits = Atomic<UInt64>(Double(20_000).bitPattern)
    let widthBits = Atomic<UInt64>(Double(1).bitPattern)
    let distortionBits = Atomic<UInt64>(Double(0).bitPattern)

    func store(settings: AudioEffectsSettings) {
        let validated = settings.validated
        let parameters = validated.effectiveParameters.validated
        let index = UInt8(AudioEffectPreset.allCases.firstIndex(of: validated.preset) ?? 0)
        presetIndex.store(index, ordering: .relaxed)
        intensityBits.store(validated.intensity.bitPattern, ordering: .relaxed)
        reverbBits.store(parameters.reverb.bitPattern, ordering: .relaxed)
        delayBits.store(parameters.delay.bitPattern, ordering: .relaxed)
        bassBits.store(parameters.bass.bitPattern, ordering: .relaxed)
        filterBits.store(parameters.filter.bitPattern, ordering: .relaxed)
        widthBits.store(parameters.width.bitPattern, ordering: .relaxed)
        distortionBits.store(parameters.distortion.bitPattern, ordering: .relaxed)
    }

    func loadSettings() -> AudioEffectsSettings {
        let allPresets = AudioEffectPreset.allCases
        let rawIndex = Int(presetIndex.load(ordering: .relaxed))
        let preset = allPresets.indices.contains(rawIndex) ? allPresets[rawIndex] : .original
        let parameters = AudioEffectParameters(
            reverb: Double(bitPattern: reverbBits.load(ordering: .relaxed)),
            delay: Double(bitPattern: delayBits.load(ordering: .relaxed)),
            bass: Double(bitPattern: bassBits.load(ordering: .relaxed)),
            filter: Double(bitPattern: filterBits.load(ordering: .relaxed)),
            width: Double(bitPattern: widthBits.load(ordering: .relaxed)),
            distortion: Double(bitPattern: distortionBits.load(ordering: .relaxed))
        )
        return AudioEffectsSettings(
            preset: preset,
            intensity: Double(bitPattern: intensityBits.load(ordering: .relaxed)),
            custom: parameters
        ).validated
    }

    @inline(__always)
    func copySource(
        to outputData: UnsafeMutablePointer<AudioBufferList>,
        frameCount: Int
    ) -> OSStatus {
        let output = UnsafeMutableAudioBufferListPointer(outputData)
        guard frameCount >= 0,
              output.count >= 2,
              let leftOutput = output[0].mData?.assumingMemoryBound(to: Float.self),
              let rightOutput = output[1].mData?.assumingMemoryBound(to: Float.self),
              let inputData = sourceAudioBufferList else {
            return kAudio_ParamError
        }
        // AVAudioSourceNode may hand the callback fresh output buffers whose
        // byte size is zero even though the engine allocated their capacity.
        // The tap input below is the buffer whose capacity we must enforce.
        let outputBytes = UInt32(frameCount * MemoryLayout<Float>.stride)
        output[0].mDataByteSize = outputBytes
        output[1].mDataByteSize = outputBytes

        let input = UnsafeMutableAudioBufferListPointer(inputData)
        let start = sourceFrameCursor
        let channels = sourceChannelCount
        guard channels == 1 || channels == 2,
              input.count > 0,
              start >= 0,
              start <= sourceFrameCount,
              frameCount <= sourceFrameCount - start else {
            return kAudio_ParamError
        }
        let bytesPerFrame = UInt32(channels * MemoryLayout<Float>.stride)
        if input.count >= channels {
            guard (0..<channels).allSatisfy({
                input[$0].mData != nil && input[$0].mNumberChannels == 1
                    && input[$0].mDataByteSize >= UInt32(frameCount * MemoryLayout<Float>.stride)
            }) else { return kAudio_ParamError }
        } else {
            guard input[0].mData != nil,
                  input[0].mNumberChannels == UInt32(channels),
                  input[0].mDataByteSize >= UInt32(frameCount) * bytesPerFrame else {
                return kAudio_ParamError
            }
        }

        for frame in 0..<frameCount {
            let inputFrame = start + frame
            let left = Self.finite(Self.sample(from: input, frame: inputFrame, channel: 0, channelCount: channels))
            let right = channels == 1
                ? left
                : Self.finite(Self.sample(from: input, frame: inputFrame, channel: 1, channelCount: channels))
            leftOutput[frame] = left
            rightOutput[frame] = right
        }
        sourceFrameCursor += frameCount
        return noErr
    }

    @inline(__always)
    private static func sample(
        from buffers: UnsafeMutableAudioBufferListPointer,
        frame: Int,
        channel: Int,
        channelCount: Int
    ) -> Float {
        guard frame >= 0 else { return 0 }
        if buffers.count >= channelCount {
            guard let data = buffers[channel].mData?.assumingMemoryBound(to: Float.self) else { return 0 }
            return data[frame]
        }
        guard let data = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return 0 }
        return data[frame * channelCount + channel]
    }

    @inline(__always)
    private static func finite(_ sample: Float) -> Float {
        sample.isFinite ? sample : 0
    }

    @inline(__always)
    func copyOutput(
        from buffer: AVAudioPCMBuffer,
        to outputData: UnsafeMutablePointer<AudioBufferList>,
        frameOffset: Int,
        frameCount: Int,
        outputChannelCount: Int
    ) -> Bool {
        guard let channels = buffer.floatChannelData else { return false }
        let output = UnsafeMutableAudioBufferListPointer(outputData)
        guard output.count > 0,
              outputChannelCount == 1 || outputChannelCount == 2 else { return false }

        let left = channels[0]
        let right = channels[1]
        if output.count >= outputChannelCount {
            guard let leftOutput = output[0].mData?.assumingMemoryBound(to: Float.self) else { return false }
            let rightOutput = outputChannelCount == 2
                ? output[1].mData?.assumingMemoryBound(to: Float.self)
                : nil
            for frame in 0..<frameCount {
                let outputFrame = frameOffset + frame
                leftOutput[outputFrame] = Self.finite(left[frame])
                if let rightOutput { rightOutput[outputFrame] = Self.finite(right[frame]) }
            }
            return true
        }

        guard let interleaved = output[0].mData?.assumingMemoryBound(to: Float.self) else { return false }
        for frame in 0..<frameCount {
            let outputFrame = frameOffset + frame
            if outputChannelCount == 1 {
                interleaved[outputFrame] = (Self.finite(left[frame]) + Self.finite(right[frame])) * 0.5
            } else {
                interleaved[outputFrame * outputChannelCount] = Self.finite(left[frame])
                interleaved[outputFrame * outputChannelCount + 1] = Self.finite(right[frame])
            }
        }
        return true
    }
}

/// Realtime effects renderer for an `MTAudioProcessingTap` video track.
///
/// The renderer owns a separate manual-rendering graph, so the video tap
/// remains the only audio source and A/V timing stays with the `AVPlayerItem`.
/// Call `prepare` and `unprepare` on the main actor while attaching/detaching
/// the tap. Call `update(settings:)` on the main actor. Call
/// `processAudioBufferList` synchronously from the tap callback; it leaves the
/// supplied buffer untouched when the format or engine is unsupported.
public final class CMVVideoAudioEffectsRenderer: @unchecked Sendable {
    private let state = CMVVideoAudioEffectsRenderState()

    public init() {}

    /// Number of successful wet manual renders since the last prepare. Dry
    /// bypasses and failed renders do not increment this diagnostic counter.
    public var successfulWetRenderCount: UInt64 {
        state.successfulWetRenderCount.load(ordering: .acquiring)
    }

    /// Prepares an isolated realtime graph for the tap's actual stream format.
    @MainActor
    public func prepare(
        actualASBD: AudioStreamBasicDescription,
        maxFrames: AVAudioFrameCount
    ) throws {
        guard state.prepared.load(ordering: .acquiring) == 0 else {
            throw CMVVideoAudioEffectsRendererError.alreadyPrepared
        }
        guard maxFrames > 0,
              Self.isSupported(actualASBD) else {
            throw maxFrames == 0
                ? CMVVideoAudioEffectsRendererError.invalidFrameCount
                : CMVVideoAudioEffectsRendererError.unsupportedFormat
        }
        var normalizedASBD = actualASBD
        guard AVAudioFormat(streamDescription: &normalizedASBD) != nil,
              let internalFormat = AVAudioFormat(
                standardFormatWithSampleRate: actualASBD.mSampleRate,
                channels: 2
              ),
              let internalBuffer = AVAudioPCMBuffer(
                pcmFormat: internalFormat,
                frameCapacity: maxFrames
              ) else {
            throw CMVVideoAudioEffectsRendererError.unsupportedFormat
        }

        let engine = AVAudioEngine()
        let sourceNode = Self.makeSourceNode(format: internalFormat, state: state)
        let liveEffects = CMVLiveAudioEffectsUnit.makeAVAudioUnit()
        guard let liveAU = liveEffects.auAudioUnit as? CMVLiveAudioEffectsUnit else {
            throw CMVVideoAudioEffectsRendererError.engineSetupFailed
        }
        try liveAU.setProcessingFormat(internalFormat)

        let reverb = AVAudioUnitReverb()
        let delay = AVAudioUnitDelay()
        let distortion = AVAudioUnitDistortion()
        let effectsEqualizer = AVAudioUnitEQ(numberOfBands: 4)
        let userEqualizer = AVAudioUnitEQ(numberOfBands: 10)
        let limiter = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        ))

        engine.attach(sourceNode)
        engine.attach(liveEffects)
        engine.attach(reverb)
        engine.attach(delay)
        engine.attach(distortion)
        engine.attach(effectsEqualizer)
        engine.attach(userEqualizer)
        engine.attach(limiter)
        engine.connect(sourceNode, to: liveEffects, format: internalFormat)
        engine.connect(liveEffects, to: reverb, format: internalFormat)
        engine.connect(reverb, to: delay, format: internalFormat)
        engine.connect(delay, to: distortion, format: internalFormat)
        engine.connect(distortion, to: effectsEqualizer, format: internalFormat)
        engine.connect(effectsEqualizer, to: userEqualizer, format: internalFormat)
        engine.connect(userEqualizer, to: limiter, format: internalFormat)
        engine.connect(limiter, to: engine.mainMixerNode, format: internalFormat)
        engine.mainMixerNode.outputVolume = 1

        try engine.enableManualRenderingMode(
            .realtime,
            format: internalFormat,
            maximumFrameCount: maxFrames
        )
        engine.prepare()
        do {
            try engine.start()
        } catch {
            engine.disableManualRenderingMode()
            throw CMVVideoAudioEffectsRendererError.engineSetupFailed
        }

        state.engine = engine
        state.sourceNode = sourceNode
        state.internalBuffer = internalBuffer
        state.internalAudioBufferList = internalBuffer.mutableAudioBufferList
        state.manualRenderBlock = engine.manualRenderingBlock
        state.internalFormat = internalFormat
        state.maximumFrameCount = Int(maxFrames)
        state.sourceChannelCount = Int(actualASBD.mChannelsPerFrame)
        state.sourceFrameCount = 0
        state.sourceAudioBufferList = nil
        state.successfulWetRenderCount.store(0, ordering: .relaxed)
        state.sourceFrameCursor = 0
        state.liveEffects = liveEffects
        state.reverb = reverb
        state.delay = delay
        state.distortion = distortion
        state.effectsEqualizer = effectsEqualizer
        state.userEqualizer = userEqualizer

        configure(
            settings: state.loadSettings(),
            liveEffects: liveEffects,
            reverb: reverb,
            delay: delay,
            distortion: distortion,
            effectsEqualizer: effectsEqualizer,
            userEqualizer: userEqualizer
        )
        state.prepared.store(1, ordering: .releasing)
    }

    /// Builds the source callback outside the main-actor `prepare` context.
    /// AVAudioSourceNode invokes this block from the audio render queue; if it
    /// is created while inheriting `@MainActor`, Swift's runtime executor
    /// check traps when Core Audio pulls the block off-main-thread.
    private nonisolated static func makeSourceNode(
        format: AVAudioFormat,
        state: CMVVideoAudioEffectsRenderState
    ) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) {
            _, _, frameCount, outputData in
            state.copySource(to: outputData, frameCount: Int(frameCount))
        }
    }

    /// Convenience overload for callers that already hold an AVAudioFormat.
    @MainActor
    public func prepare(format: AVAudioFormat, maxFrames: AVAudioFrameCount) throws {
        let asbd = format.streamDescription.pointee
        try prepare(actualASBD: asbd, maxFrames: maxFrames)
    }

    /// Updates all 13 preset mappings without changing the video timeline.
    /// This control operation is main-actor isolated so it cannot race
    /// teardown; the tap callback remains nonisolated and synchronous.
    @MainActor
    public func update(settings: AudioEffectsSettings) {
        let validated = settings.validated
        state.store(settings: validated)
        guard let liveEffects = state.liveEffects,
              let reverb = state.reverb,
              let delay = state.delay,
              let distortion = state.distortion,
              let effectsEqualizer = state.effectsEqualizer,
              let userEqualizer = state.userEqualizer else {
            state.active.store(0, ordering: .releasing)
            return
        }
        configure(
            settings: validated,
            liveEffects: liveEffects,
            reverb: reverb,
            delay: delay,
            distortion: distortion,
            effectsEqualizer: effectsEqualizer,
            userEqualizer: userEqualizer
        )
    }

    /// Stops and releases all render resources. Call only after tap removal.
    @MainActor
    public func unprepare() {
        state.sourceAudioBufferList = nil
        state.active.store(0, ordering: .releasing)
        state.prepared.store(0, ordering: .releasing)
        state.engine?.stop()
        state.engine?.disableManualRenderingMode()
        state.manualRenderBlock = nil
        state.internalAudioBufferList = nil
        state.engine = nil
        state.sourceNode = nil
        state.internalBuffer = nil
        state.internalFormat = nil
        state.maximumFrameCount = 0
        state.sourceChannelCount = 0
        state.sourceFrameCount = 0
        state.sourceFrameCursor = 0
        state.successfulWetRenderCount.store(0, ordering: .relaxed)
        state.liveEffects = nil
        state.reverb = nil
        state.delay = nil
        state.distortion = nil
        state.effectsEqualizer = nil
        state.userEqualizer = nil
    }

    /// Processes the tap's current PCM in place. Returning false means the
    /// input was intentionally left dry because the renderer is unprepared,
    /// the ABL shape is unsupported, or manual rendering failed.
    @discardableResult
    public func processAudioBufferList(
        frameCount: AVAudioFrameCount,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>
    ) -> Bool {
        let frames = Int(frameCount)
        guard frames >= 0,
              frames == 0 || audioBufferList.pointee.mNumberBuffers > 0,
              state.prepared.load(ordering: .acquiring) != 0 else { return false }
        guard state.active.load(ordering: .acquiring) != 0 else { return true }
        guard let buffer = state.internalBuffer,
              let internalAudioBufferList = state.internalAudioBufferList,
              let manualRenderBlock = state.manualRenderBlock,
              state.maximumFrameCount > 0,
              frames <= state.maximumFrameCount,
              state.sourceChannelCount == 1 || state.sourceChannelCount == 2 else {
            return false
        }
        let external = UnsafeMutableAudioBufferListPointer(audioBufferList)
        guard Self.isSupportedBufferList(
            external,
            channelCount: state.sourceChannelCount,
            frameCount: frames
        ) else {
            return false
        }

        state.sourceAudioBufferList = audioBufferList
        state.sourceFrameCount = frames
        state.sourceFrameCursor = 0
        buffer.frameLength = frameCount
        let internalBuffers = UnsafeMutableAudioBufferListPointer(internalAudioBufferList)
        guard internalBuffers.count >= 2 else { return false }
        let internalBytes = UInt32(frames * MemoryLayout<Float>.stride)
        internalBuffers[0].mDataByteSize = internalBytes
        internalBuffers[1].mDataByteSize = internalBytes
        var error: OSStatus = noErr
        let status = manualRenderBlock(frameCount, internalAudioBufferList, &error)
        guard status == .success, error == noErr,
              state.copyOutput(
                from: buffer,
                to: audioBufferList,
                frameOffset: 0,
                frameCount: frames,
                outputChannelCount: state.sourceChannelCount
              ) else {
            state.sourceAudioBufferList = nil
            state.sourceFrameCount = 0
            return false
        }
        state.sourceAudioBufferList = nil
        state.sourceFrameCount = 0
        state.successfulWetRenderCount.wrappingAdd(1, ordering: .relaxed)
        return true
    }

    private func configure(
        settings: AudioEffectsSettings,
        liveEffects: AVAudioUnitEffect,
        reverb: AVAudioUnitReverb,
        delay: AVAudioUnitDelay,
        distortion: AVAudioUnitDistortion,
        effectsEqualizer: AVAudioUnitEQ,
        userEqualizer: AVAudioUnitEQ
    ) {
        let validated = settings.validated
        let intensity = validated.intensity
        let parameters = validated.effectiveParameters.validated
        let active = intensity > 0 && !Self.isNeutral(parameters)
        (liveEffects.auAudioUnit as? CMVLiveAudioEffectsUnit)?.update(settings: validated)

        reverb.loadFactoryPreset(Self.reverbPreset(for: validated.preset))
        reverb.wetDryMix = Float(parameters.reverb * intensity).clamped(to: 0...100)
        reverb.bypass = false

        delay.delayTime = min(0.5, max(0.001, parameters.delay / 1_000))
        delay.feedback = Float(min(35, 10 + parameters.reverb * 0.25))
        let effectiveFilter = 20_000 - (20_000 - parameters.filter) * intensity
        delay.lowPassCutoff = Float(effectiveFilter).clamped(to: 10...20_000)
        delay.wetDryMix = Float(parameters.delay / 500 * 60 * intensity).clamped(to: 0...60)
        delay.bypass = false

        distortion.preGain = Float(-12 + parameters.distortion * 0.06 * intensity).clamped(to: -12...0)
        distortion.wetDryMix = Float(parameters.distortion * intensity).clamped(to: 0...100)
        distortion.bypass = false

        let bass = effectsEqualizer.bands[0]
        bass.filterType = .lowShelf
        bass.frequency = 180
        bass.bandwidth = 0.7
        bass.gain = Float(parameters.bass * intensity).clamped(to: -12...12)
        bass.bypass = !active || abs(parameters.bass) < 0.001

        let mid = effectsEqualizer.bands[1]
        mid.filterType = .parametric
        mid.frequency = 1_600
        mid.bandwidth = 1.1
        mid.gain = Float(Self.midGain(for: validated) * intensity).clamped(to: -12...12)
        mid.bypass = !active || abs(Self.midGain(for: validated)) < 0.001

        let high = effectsEqualizer.bands[2]
        high.filterType = .highShelf
        high.frequency = 7_000
        high.bandwidth = 0.8
        high.gain = Float(Self.highGain(for: validated) * intensity).clamped(to: -12...12)
        high.bypass = !active || abs(Self.highGain(for: validated)) < 0.001

        let filter = effectsEqualizer.bands[3]
        filter.filterType = .lowPass
        filter.frequency = Float(effectiveFilter).clamped(to: 150...20_000)
        filter.bandwidth = 1
        filter.gain = 0
        filter.bypass = !active || parameters.filter >= 19_999.999
        effectsEqualizer.bypass = false
        userEqualizer.bypass = true
        state.active.store(active ? 1 : 0, ordering: .releasing)
    }

    private static func isSupported(_ asbd: AudioStreamBasicDescription) -> Bool {
        let flags = asbd.mFormatFlags
        let isFloat = flags & kAudioFormatFlagIsFloat != 0
        let isBigEndian = flags & kAudioFormatFlagIsBigEndian != 0
        let isPacked = flags & kAudioFormatFlagIsPacked != 0
        let isNonInterleaved = flags & kAudioFormatFlagIsNonInterleaved != 0
        let isLinearPCM = asbd.mFormatID == kAudioFormatLinearPCM
        let is32Bit = asbd.mBitsPerChannel == 32
        let sampleRate = asbd.mSampleRate
        let rateSupported = abs(sampleRate - 44_100) < 0.5 || abs(sampleRate - 48_000) < 0.5
        let channelCountSupported = asbd.mChannelsPerFrame == 1 || asbd.mChannelsPerFrame == 2
        let bytesPerFrame = isNonInterleaved
            ? MemoryLayout<Float>.stride
            : Int(asbd.mChannelsPerFrame) * MemoryLayout<Float>.stride
        return isLinearPCM && isFloat && !isBigEndian && isPacked && is32Bit && rateSupported
            && channelCountSupported && asbd.mFramesPerPacket == 1
            && asbd.mBytesPerFrame == UInt32(bytesPerFrame)
            && asbd.mBytesPerPacket == UInt32(bytesPerFrame)
    }

    private static func isSupportedBufferList(
        _ buffers: UnsafeMutableAudioBufferListPointer,
        channelCount: Int,
        frameCount: Int
    ) -> Bool {
        guard channelCount == 1 || channelCount == 2,
              buffers.count > 0 else { return false }
        if buffers.count >= channelCount {
            return (0..<channelCount).allSatisfy {
                buffers[$0].mData != nil && buffers[$0].mNumberChannels == 1
                    && buffers[$0].mDataByteSize >= UInt32(frameCount * MemoryLayout<Float>.stride)
            }
        }
        return buffers[0].mData != nil
            && buffers[0].mNumberChannels == UInt32(channelCount)
            && buffers[0].mDataByteSize >= UInt32(frameCount * channelCount * MemoryLayout<Float>.stride)
    }

    private static func isNeutral(_ parameters: AudioEffectParameters) -> Bool {
        parameters.reverb == 0 && parameters.delay == 0 && parameters.bass == 0
            && parameters.filter >= 19_999.999 && parameters.width == 1
            && parameters.distortion == 0
    }

    private static func midGain(for settings: AudioEffectsSettings) -> Double {
        switch settings.preset {
        case .vocal: return 4
        case .deepSpaceRadio: return -2
        default: return 0
        }
    }

    private static func highGain(for settings: AudioEffectsSettings) -> Double {
        switch settings.preset {
        case .electronic: return 4
        case .deepSpaceRadio: return -3
        default: return 0
        }
    }

    private static func reverbPreset(for preset: AudioEffectPreset) -> AVAudioUnitReverbPreset {
        switch preset {
        case .cathedral: return .cathedral
        case .bathroom, .sewer: return .smallRoom
        case .underwater, .vocal: return .mediumRoom
        case .saturn, .orbit, .deepSpaceRadio: return .largeHall2
        case .cassette, .electronic: return .plate
        case .original, .bassBoost, .custom: return .mediumHall
        }
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(range.upperBound, max(range.lowerBound, self))
    }
}
