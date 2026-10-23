import XCTest
import AVFoundation
import Darwin
import CMVDomain
@testable import CMVPlayback

final class AudioEffectsTests: XCTestCase {
    func testMalformedSettingsAreSanitizedToFiniteBounds() {
        let settings = AudioEffectsSettings(
            preset: .custom,
            intensity: .nan,
            custom: AudioEffectParameters(
                reverb: .infinity,
                delay: -.infinity,
                bass: .nan,
                filter: .nan,
                width: .infinity,
                distortion: -.infinity
            )
        ).validated

        XCTAssertEqual(settings.intensity, 0)
        XCTAssertEqual(settings.custom, AudioEffectParameters())
    }

    @MainActor
    func testNativeEngineManualRenderCoversEveryPresetAndZeroIntensity() throws {
        let input = (0..<1_024).map { Float(sin(Double($0) * 0.13) * 0.16) }
        let dry = try NativePlaybackEngine().renderEffectsForTests(
            input: input, settings: AudioEffectsSettings(preset: .original, intensity: 0)
        )
        XCTAssertTrue(dry.left.contains { abs($0) > 0.001 })
        XCTAssertEqual(dry.left.count, input.count)
        XCTAssertEqual(dry.right.count, input.count)
        for preset in AudioEffectPreset.allCases {
            let output = try NativePlaybackEngine().renderEffectsForTests(
                input: input, settings: AudioEffectsSettings(preset: preset, intensity: 0.3)
            )
            XCTAssertEqual(output.left.count, input.count, "\(preset) frame count")
            XCTAssertTrue(output.left.allSatisfy(\.isFinite), "\(preset) left finite")
            XCTAssertTrue(output.right.allSatisfy(\.isFinite), "\(preset) right finite")
            let energy = output.left.reduce(Float.zero) { $0 + abs($1) }
            XCTAssertGreaterThan(energy, 0.001, "\(preset) must remain non-silent")
            if preset != .original && preset != .custom {
                let difference = zip(dry.left, output.left).reduce(Float.zero) { partial, pair in
                    partial + abs(pair.0 - pair.1)
                }
                XCTAssertGreaterThan(difference, 0.0001, "\(preset) must differ from original")
            }
        }
        let zero = try NativePlaybackEngine().renderEffectsForTests(
            input: input,
            settings: AudioEffectsSettings(
                preset: .custom,
                intensity: 0,
                custom: AudioEffectParameters(reverb: 100, delay: 500, bass: 12,
                                               filter: 150, width: 0, distortion: 100)
            )
        )
        XCTAssertTrue(zip(zero.left, dry.left).allSatisfy { abs($0 - $1) <= 0.0005 })
        XCTAssertTrue(zip(zero.right, dry.right).allSatisfy { abs($0 - $1) <= 0.0005 })
    }

    @MainActor
    func testNativeEngineManualRenderCustomParametersChangeLiveOutput() throws {
        let input = (0..<1_024).map { Float(sin(Double($0) * 0.17) * 0.14) }
        let rightInput = (0..<1_024).map { Float(cos(Double($0) * 0.11) * 0.12) }
        let baseline = try NativePlaybackEngine().renderEffectsForTests(
            input: input, rightInput: rightInput,
            settings: AudioEffectsSettings(preset: .custom, intensity: 1)
        )
        let values: [AudioEffectParameters] = [
            AudioEffectParameters(reverb: 60),
            AudioEffectParameters(delay: 240),
            AudioEffectParameters(bass: 10),
            AudioEffectParameters(filter: 900),
            AudioEffectParameters(width: 1.8),
            AudioEffectParameters(distortion: 70)
        ]
        for parameters in values {
            let output = try NativePlaybackEngine().renderEffectsForTests(
                input: input,
                rightInput: rightInput,
                settings: AudioEffectsSettings(preset: .custom, intensity: 1, custom: parameters)
            )
            let difference = zip(baseline.left, output.left).reduce(Float.zero) { partial, pair in
                partial + abs(pair.0 - pair.1)
            }
            XCTAssertGreaterThan(difference, 0.0001, "custom parameter \(parameters) must affect live chain")
        }
    }

    @MainActor
    func testNativeEngineManualRenderMonoInputProducesStereoFiniteFrames() throws {
        let input = (0..<1_024).map { Float(($0 % 11) - 5) / 40 }
        let output = try NativePlaybackEngine().renderEffectsForTests(
            input: input, settings: AudioEffectsSettings(preset: .orbit, intensity: 0.3)
        )
        XCTAssertEqual(output.left.count, input.count)
        XCTAssertEqual(output.right.count, input.count)
        XCTAssertTrue(output.left.allSatisfy(\.isFinite) && output.right.allSatisfy(\.isFinite))
    }

    @MainActor
    func testNativeEngineManualRenderAccepts44100StereoSource() throws {
        let input = (0..<1_024).map { Float(sin(Double($0) * 0.11) * 0.16) }
        let output = try NativePlaybackEngine().renderEffectsForTests(
            input: input,
            settings: AudioEffectsSettings(preset: .original, intensity: 0),
            sampleRate: 44_100
        )
        XCTAssertEqual(output.left.count, input.count)
        XCTAssertEqual(output.right.count, input.count)
        XCTAssertTrue(output.left.allSatisfy(\.isFinite) && output.right.allSatisfy(\.isFinite))
        XCTAssertGreaterThan(output.left.reduce(Float.zero) { $0 + abs($1) }, 0.001)
        XCTAssertGreaterThan(output.right.reduce(Float.zero) { $0 + abs($1) }, 0.001)
    }

    @MainActor
    func testOrbitPreservesAntiPhaseStereoAtFullIntensity() throws {
        let input = (0..<4_096).map { Float(sin(Double($0) * 0.13) * 0.16) }
        let output = try NativePlaybackEngine().renderEffectsForTests(
            input: input, rightInput: input.map { -$0 },
            settings: AudioEffectsSettings(preset: .orbit, intensity: 1)
        )
        XCTAssertTrue(output.left.allSatisfy(\.isFinite) && output.right.allSatisfy(\.isFinite))
        XCTAssertGreaterThan(output.left.reduce(0) { $0 + abs($1) }, 0.01)
        XCTAssertGreaterThan(output.right.reduce(0) { $0 + abs($1) }, 0.01)
    }

    @MainActor
    func testEngineStoresValidatedEffectsWithoutReschedulingPlayback() {
        let engine = NativePlaybackEngine()
        let malformed = AudioEffectsSettings(
            preset: .underwater,
            intensity: 99,
            custom: AudioEffectParameters(filter: -.infinity)
        )
        engine.setAudioEffects(malformed)
        XCTAssertEqual(engine.audioEffectsSettings.intensity, 1)
        XCTAssertEqual(engine.audioEffectsSettings.preset, .underwater)
        XCTAssertFalse(engine.requiresTimelineReschedule)
    }

    @MainActor
    func testPauseMutesEffectTailAndRestoresStoredVolumeOnPlay() throws {
        let engine = NativePlaybackEngine()
        XCTAssertEqual(engine.mainMixerOutputVolumeForTests, 1, accuracy: 0.001)

        engine.pause()
        XCTAssertEqual(engine.mainMixerOutputVolumeForTests, 0, accuracy: 0.001)
        engine.setVolume(0.42)
        XCTAssertEqual(engine.outputVolume, 0.42, accuracy: 0.001)
        XCTAssertEqual(engine.mainMixerOutputVolumeForTests, 0, accuracy: 0.001)

        try engine.play()
        XCTAssertTrue(engine.isPlaying)
        XCTAssertEqual(engine.mainMixerOutputVolumeForTests, 0.42, accuracy: 0.001)
        engine.pause()
    }

    @MainActor
    func testLiveUnitManualRenderHasDrySignalAndStereoOrbit() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let engine = AVAudioEngine()
        let liveAV = CMVLiveAudioEffectsUnit.makeAVAudioUnit()
        let live = try XCTUnwrap(liveAV.auAudioUnit as? CMVLiveAudioEffectsUnit)
        let source = AVAudioSourceNode { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for bufferIndex in 0..<buffers.count {
                guard let data = buffers[bufferIndex].mData?.assumingMemoryBound(to: Float.self) else { continue }
                for frame in 0..<Int(frameCount) {
                    data[frame] = 0.2
                }
            }
            return noErr
        }
        engine.attach(source)
        engine.attach(liveAV)
        engine.connect(source, to: liveAV, format: format)
        engine.connect(liveAV, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4_096)
        engine.prepare()
        try engine.start()
        defer { engine.stop() }

        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_096))
        live.update(settings: AudioEffectsSettings(preset: .original, intensity: 0))
        XCTAssertEqual(try engine.renderOffline(4_096, to: buffer), .success)
        let dryLeft = try XCTUnwrap(buffer.floatChannelData?[0])
        XCTAssertGreaterThan(dryLeft[0], 0.01)
        XCTAssertEqual(dryLeft[0], buffer.floatChannelData?[1][0] ?? 0, accuracy: 0.0001)

        live.update(settings: AudioEffectsSettings(preset: .orbit, intensity: 1))
        XCTAssertEqual(try engine.renderOffline(4_096, to: buffer), .success)
        let orbitLeft = try XCTUnwrap(buffer.floatChannelData?[0])
        let orbitRight = try XCTUnwrap(buffer.floatChannelData?[1])
        let leftSamples = Array(UnsafeBufferPointer(start: orbitLeft, count: 4_096))
        let rightSamples = Array(UnsafeBufferPointer(start: orbitRight, count: 4_096))
        XCTAssertTrue(zip(leftSamples, rightSamples).contains { abs($0 - $1) > 0.0001 })
        XCTAssertTrue(leftSamples.allSatisfy(\.isFinite) && rightSamples.allSatisfy(\.isFinite))

        live.update(settings: AudioEffectsSettings(preset: .cassette, intensity: 1))
        XCTAssertEqual(try engine.renderOffline(4_096, to: buffer), .success)
        let cassetteLeft = try XCTUnwrap(buffer.floatChannelData?[0])
        let cassetteRight = try XCTUnwrap(buffer.floatChannelData?[1])
        XCTAssertTrue(Array(UnsafeBufferPointer(start: cassetteLeft, count: 4_096)).allSatisfy(\.isFinite))
        XCTAssertTrue(Array(UnsafeBufferPointer(start: cassetteRight, count: 4_096)).allSatisfy(\.isFinite))
    }

    @MainActor
    func testVideoRendererProcessesAllPresetsInPlaceAndKeepsZeroIntensityDry() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let renderer = CMVVideoAudioEffectsRenderer()
        try renderer.prepare(format: format, maxFrames: 512)
        defer { renderer.unprepare() }

        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512))
        buffer.frameLength = 512
        let left = try XCTUnwrap(buffer.floatChannelData?[0])
        let right = try XCTUnwrap(buffer.floatChannelData?[1])
        for frame in 0..<512 {
            left[frame] = Float(sin(Double(frame) * 0.17) * 0.2)
            right[frame] = Float(cos(Double(frame) * 0.11) * 0.16)
        }
        let originalLeft = Array(UnsafeBufferPointer(start: left, count: 512))
        let originalRight = Array(UnsafeBufferPointer(start: right, count: 512))

        renderer.update(settings: AudioEffectsSettings(preset: .original, intensity: 0))
        XCTAssertTrue(renderer.processAudioBufferList(
            frameCount: 512,
            audioBufferList: buffer.mutableAudioBufferList
        ), "original should be accepted as dry")
        XCTAssertEqual(renderer.successfulWetRenderCount, 0)
        XCTAssertEqual(Array(UnsafeBufferPointer(start: left, count: 512)), originalLeft)
        XCTAssertEqual(Array(UnsafeBufferPointer(start: right, count: 512)), originalRight)

        let customParameters = AudioEffectParameters(
            reverb: 80, delay: 300, bass: 12, filter: 800, width: 1.8, distortion: 90
        )
        var expectedWetRenderCount: UInt64 = 0
        for preset in AudioEffectPreset.allCases where preset != .original {
            renderer.update(settings: AudioEffectsSettings(
                preset: preset,
                intensity: 0.8,
                custom: preset == .custom ? customParameters : AudioEffectParameters()
            ))
            for frame in 0..<512 {
                left[frame] = originalLeft[frame]
                right[frame] = originalRight[frame]
            }
            XCTAssertTrue(renderer.processAudioBufferList(
                frameCount: 512,
                audioBufferList: buffer.mutableAudioBufferList
            ), "renderer should process \(preset)")
            let outputLeft = Array(UnsafeBufferPointer(start: left, count: 512))
            let outputRight = Array(UnsafeBufferPointer(start: right, count: 512))
            XCTAssertTrue(outputLeft.allSatisfy(\.isFinite), "\(preset) left finite")
            XCTAssertTrue(outputRight.allSatisfy(\.isFinite), "\(preset) right finite")
            XCTAssertGreaterThan(outputLeft.reduce(Float.zero) { $0 + abs($1) }, 0.001, "\(preset) remains audible")
            let difference = zip(originalLeft, outputLeft).reduce(Float.zero) { $0 + abs($1.0 - $1.1) }
            XCTAssertGreaterThan(difference, 0.0001, "\(preset) changes PCM")
            expectedWetRenderCount += 1
            XCTAssertEqual(renderer.successfulWetRenderCount, expectedWetRenderCount,
                           "\(preset) must produce one successful wet render")
        }
        let wetRenderCount = renderer.successfulWetRenderCount
        XCTAssertEqual(wetRenderCount, expectedWetRenderCount)

        renderer.update(settings: AudioEffectsSettings(
            preset: .custom,
            intensity: 0,
            custom: AudioEffectParameters(reverb: 80, delay: 300, bass: 12,
                                          filter: 800, width: 0, distortion: 90)
        ))
        for frame in 0..<512 {
            left[frame] = originalLeft[frame]
            right[frame] = originalRight[frame]
        }
        XCTAssertTrue(renderer.processAudioBufferList(
            frameCount: 512,
            audioBufferList: buffer.mutableAudioBufferList
        ))
        XCTAssertEqual(renderer.successfulWetRenderCount, wetRenderCount)
        XCTAssertEqual(Array(UnsafeBufferPointer(start: left, count: 512)), originalLeft)
        XCTAssertEqual(Array(UnsafeBufferPointer(start: right, count: 512)), originalRight)
    }

    @MainActor
    func testVideoRendererSupportsMono44100AndRejectsThreeChannels() throws {
        let monoFormat = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let renderer = CMVVideoAudioEffectsRenderer()
        try renderer.prepare(format: monoFormat, maxFrames: 128)
        defer { renderer.unprepare() }

        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: 128))
        buffer.frameLength = 128
        let mono = try XCTUnwrap(buffer.floatChannelData?[0])
        for frame in 0..<128 { mono[frame] = Float(sin(Double(frame) * 0.2) * 0.2) }
        renderer.update(settings: AudioEffectsSettings(preset: .orbit, intensity: 0.5))
        XCTAssertTrue(renderer.processAudioBufferList(
            frameCount: 128,
            audioBufferList: buffer.mutableAudioBufferList
        ))
        XCTAssertTrue(Array(UnsafeBufferPointer(start: mono, count: 128)).allSatisfy(\.isFinite))

        var threeChannel = monoFormat.streamDescription.pointee
        threeChannel.mChannelsPerFrame = 3
        XCTAssertThrowsError(try CMVVideoAudioEffectsRenderer().prepare(actualASBD: threeChannel, maxFrames: 128)) { error in
            XCTAssertEqual(error as? CMVVideoAudioEffectsRendererError, .unsupportedFormat)
        }
        var bigEndian = monoFormat.streamDescription.pointee
        bigEndian.mFormatFlags |= kAudioFormatFlagIsBigEndian
        XCTAssertThrowsError(try CMVVideoAudioEffectsRenderer().prepare(actualASBD: bigEndian, maxFrames: 128)) { error in
            XCTAssertEqual(error as? CMVVideoAudioEffectsRendererError, .unsupportedFormat)
        }
        var padded = monoFormat.streamDescription.pointee
        padded.mBytesPerFrame = 8
        padded.mBytesPerPacket = 8
        XCTAssertThrowsError(try CMVVideoAudioEffectsRenderer().prepare(actualASBD: padded, maxFrames: 128)) { error in
            XCTAssertEqual(error as? CMVVideoAudioEffectsRendererError, .unsupportedFormat)
        }
    }

    @MainActor
    func testVideoRendererLifecycleAndFrameCountAreSafe() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let renderer = CMVVideoAudioEffectsRenderer()
        XCTAssertThrowsError(try renderer.prepare(format: format, maxFrames: 0)) { error in
            XCTAssertEqual(error as? CMVVideoAudioEffectsRendererError, .invalidFrameCount)
        }
        try renderer.prepare(format: format, maxFrames: 64)
        XCTAssertThrowsError(try renderer.prepare(format: format, maxFrames: 64)) { error in
            XCTAssertEqual(error as? CMVVideoAudioEffectsRendererError, .alreadyPrepared)
        }
        renderer.unprepare()
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 64))
        buffer.frameLength = 64
        XCTAssertFalse(renderer.processAudioBufferList(
            frameCount: 64,
            audioBufferList: buffer.mutableAudioBufferList
        ))
    }

    @MainActor
    func testVideoRendererProcessesInterleavedFramesInPlace() throws {
        let format = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44_100,
            channels: 2,
            interleaved: true
        ))
        let renderer = CMVVideoAudioEffectsRenderer()
        try renderer.prepare(format: format, maxFrames: 512)
        defer { renderer.unprepare() }

        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512))
        buffer.frameLength = 512
        let buffers = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        let samples = try XCTUnwrap(buffers[0].mData?.assumingMemoryBound(to: Float.self))
        for frame in 0..<512 {
            samples[frame * 2] = Float(sin(Double(frame) * 0.09) * 0.16)
            samples[frame * 2 + 1] = Float(cos(Double(frame) * 0.07) * 0.13)
        }
        samples[3] = .nan
        let before = Array(UnsafeBufferPointer(start: samples, count: 1_024))
        renderer.update(settings: AudioEffectsSettings(preset: .cassette, intensity: 0.7))
        XCTAssertTrue(renderer.processAudioBufferList(
            frameCount: 512,
            audioBufferList: buffer.mutableAudioBufferList
        ))
        let after = Array(UnsafeBufferPointer(start: samples, count: 1_024))
        XCTAssertTrue(after.allSatisfy(\.isFinite))
        let finiteDifference = zip(before, after).reduce(Float.zero) { partial, pair in
            pair.0.isFinite ? partial + abs(pair.0 - pair.1) : partial
        }
        XCTAssertGreaterThan(finiteDifference, 0.0001)

        let oversized = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 513))
        oversized.frameLength = 513
        let oversizedSamples = try XCTUnwrap(
            UnsafeMutableAudioBufferListPointer(oversized.mutableAudioBufferList)[0]
                .mData?.assumingMemoryBound(to: Float.self)
        )
        for index in 0..<1_026 { oversizedSamples[index] = Float(index % 17) / 100 }
        let oversizedBefore = Array(UnsafeBufferPointer(start: oversizedSamples, count: 1_026))
        XCTAssertFalse(renderer.processAudioBufferList(
            frameCount: 513,
            audioBufferList: oversized.mutableAudioBufferList
        ))
        XCTAssertEqual(Array(UnsafeBufferPointer(start: oversizedSamples, count: 1_026)), oversizedBefore)

        let truncated = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512))
        truncated.frameLength = 512
        let truncatedABL = truncated.mutableAudioBufferList
        let truncatedBuffers = UnsafeMutableAudioBufferListPointer(truncatedABL)
        let truncatedSamples = try XCTUnwrap(truncatedBuffers[0].mData?.assumingMemoryBound(to: Float.self))
        truncatedSamples[0] = 0.25
        let truncatedBefore = Array(UnsafeBufferPointer(start: truncatedSamples, count: 1_024))
        truncatedBuffers[0].mDataByteSize = 4
        XCTAssertFalse(renderer.processAudioBufferList(
            frameCount: 512,
            audioBufferList: truncatedABL
        ))
        XCTAssertEqual(Array(UnsafeBufferPointer(start: truncatedSamples, count: 1_024)), truncatedBefore)
    }

    func testVideoRendererWetRenderRunsFromBackgroundTask() async throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let renderer = CMVVideoAudioEffectsRenderer()
        try await MainActor.run {
            try renderer.prepare(format: format, maxFrames: 512)
            renderer.update(settings: AudioEffectsSettings(preset: .bassBoost, intensity: 0.8))
        }

        let result = await Task.detached(priority: .userInitiated) {
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)
            guard let buffer else { return (rendered: false, ranOnMain: pthread_main_np() != 0, finite: false) }
            buffer.frameLength = 512
            guard let left = buffer.floatChannelData?[0],
                  let right = buffer.floatChannelData?[1] else {
                return (rendered: false, ranOnMain: pthread_main_np() != 0, finite: false)
            }
            for frame in 0..<512 {
                left[frame] = Float(sin(Double(frame) * 0.17) * 0.2)
                right[frame] = Float(cos(Double(frame) * 0.11) * 0.16)
            }
            let rendered = renderer.processAudioBufferList(
                frameCount: 512,
                audioBufferList: buffer.mutableAudioBufferList
            )
            let finite = (0..<512).allSatisfy { left[$0].isFinite && right[$0].isFinite }
            return (rendered: rendered, ranOnMain: pthread_main_np() != 0, finite: finite)
        }.value

        let wetRenderCount = renderer.successfulWetRenderCount
        await MainActor.run { renderer.unprepare() }
        XCTAssertTrue(result.rendered)
        XCTAssertFalse(result.ranOnMain)
        XCTAssertTrue(result.finite)
        XCTAssertEqual(wetRenderCount, 1)
    }
}
