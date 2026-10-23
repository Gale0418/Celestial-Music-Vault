import XCTest
import AVFoundation
import CMVDomain
import CMVPlayback
@testable import CMV

#if DEBUG && CMV_STOREKIT_TEST_HOST
@MainActor
final class AudioEffectsPreferencesTests: XCTestCase {
    func testSettingsSurviveModelRelaunchWithoutTouchingTheQueue() throws {
        let suite = "CMVAudioEffectsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = AppModel(audioEffectsDefaults: defaults)
        var settings = AudioEffectsSettings()
        settings.preset = .sewer
        settings.intensity = 0.42
        settings.custom.width = 1.25
        first.updateAudioEffects(settings)

        let relaunched = AppModel(audioEffectsDefaults: defaults)
        XCTAssertEqual(relaunched.audioEffects, settings.validated)
        XCTAssertEqual(relaunched.playback.audioEffectsSettings, settings.validated)
        XCTAssertTrue(relaunched.playback.queue.tracks.isEmpty)
        XCTAssertFalse(relaunched.playback.isPlaying)

        relaunched.updateAudioEffects(AudioEffectsSettings())
        XCTAssertEqual(AudioEffectsPreferences.load(from: defaults).preset, .original)
    }

    func testCorruptSavedSettingsRecoverToOriginalSound() throws {
        let suite = "CMVAudioEffectsCorrupt-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("corrupt settings".utf8), forKey: AudioEffectsPreferences.key)
        XCTAssertEqual(AudioEffectsPreferences.load(from: defaults), AudioEffectsSettings())
    }

    func testOriginalComparisonPreservesSavedSoundAndNonemptyQueue() async throws {
        let suite = "CMVAudioComparison-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVAudioComparison-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: snapshotURL) }
        let model = AppModel(queueSnapshotStore: PlaybackQueueSnapshotStore(url: snapshotURL),
                             audioEffectsDefaults: defaults)
        let track = Track(sourceID: UUID(), relativePath: "compare.caf", fileIdentifier: "compare",
                          title: "Compare", fileSize: 1, modifiedAt: .now)
        model.playback.setQueue(PlaybackQueue(tracks: [track, track], currentIndex: 1))
        let settings = AudioEffectsSettings(preset: .custom, intensity: 0.42,
                                           custom: AudioEffectParameters(reverb: 23, width: 1.25))
        model.updateAudioEffects(settings)
        let saved = defaults.data(forKey: AudioEffectsPreferences.key)

        model.setOriginalSoundComparison(true)
        XCTAssertTrue(model.isComparingOriginalSound)
        XCTAssertEqual(model.playback.audioEffectsSettings.preset, .original)
        XCTAssertEqual(model.audioEffects, settings)
        XCTAssertEqual(defaults.data(forKey: AudioEffectsPreferences.key), saved)
        XCTAssertEqual(model.playback.queue.tracks.map(\.id), [track.id, track.id])
        XCTAssertEqual(model.playback.queue.currentIndex, 1)
        XCTAssertFalse(model.playback.isPlaying)

        model.setOriginalSoundComparison(false)
        XCTAssertFalse(model.isComparingOriginalSound)
        XCTAssertEqual(model.playback.audioEffectsSettings, settings)
        XCTAssertEqual(defaults.data(forKey: AudioEffectsPreferences.key), saved)
        XCTAssertEqual(model.playback.queue.currentIndex, 1)
        _ = await model.flushPlaybackQueueSnapshot()
    }

    func testVideoOriginalComparisonPreservesSavedSoundQueueAndBothRoutes() throws {
        let suite = "CMVVideoAudioComparison-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVVideoAudioComparison-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: snapshotURL) }

        let model = AppModel(queueSnapshotStore: PlaybackQueueSnapshotStore(url: snapshotURL),
                             audioEffectsDefaults: defaults)
        let track = Track(sourceID: UUID(), relativePath: "video-compare.mov", fileIdentifier: "video-compare",
                          title: "Video compare", fileSize: 1, modifiedAt: .now)
        model.seedVideoPlaybackForTesting(tracks: [track, track], currentIndex: 1)
        model.videoSession.setVideoAudioStatusForTesting(.supported)

        let settings = AudioEffectsSettings(preset: .custom, intensity: 0.55,
                                            custom: AudioEffectParameters(reverb: 18, width: 1.2))
        model.updateAudioEffects(settings)
        let saved = defaults.data(forKey: AudioEffectsPreferences.key)
        let queueIDs = model.playback.queue.tracks.map(\.id)

        model.setOriginalSoundComparison(true)
        XCTAssertTrue(model.isComparingOriginalSound)
        XCTAssertEqual(model.playback.audioEffectsSettings, AudioEffectsSettings())
        XCTAssertEqual(model.videoSession.audioEffectsSettings, AudioEffectsSettings())
        XCTAssertEqual(model.audioEffects, settings)
        XCTAssertEqual(defaults.data(forKey: AudioEffectsPreferences.key), saved)
        XCTAssertEqual(model.playback.queue.tracks.map(\.id), queueIDs)
        XCTAssertEqual(model.playback.queue.currentIndex, 1)

        model.setOriginalSoundComparison(false)
        XCTAssertFalse(model.isComparingOriginalSound)
        XCTAssertEqual(model.playback.audioEffectsSettings, settings)
        XCTAssertEqual(model.videoSession.audioEffectsSettings, settings)
        XCTAssertEqual(model.playback.queue.tracks.map(\.id), queueIDs)
        XCTAssertEqual(model.playback.queue.currentIndex, 1)
    }

    func testNeutralCustomVideoSettingsUseTapProofWithoutWetRender() {
        XCTAssertFalse(videoMeterRequiresWetRender(
            AudioEffectsSettings(preset: .custom, intensity: 0.8)
        ))
        XCTAssertTrue(videoMeterRequiresWetRender(
            AudioEffectsSettings(preset: .custom, intensity: 0.8,
                                 custom: AudioEffectParameters(delay: 1))
        ))
    }

    func testVideoMeterGenerationCASKeepsNewestPendingPreparation() throws {
        let context = VideoAudioMeterContext()
        let oldFormat = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        let newFormat = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))

        context.prepare(format: oldFormat.streamDescription.pointee, maxFrames: 256)
        let old = try XCTUnwrap(context.pendingPreparation())
        context.markDry(requiresPreparation: true)
        context.prepare(format: newFormat.streamDescription.pointee, maxFrames: 128)
        let newest = try XCTUnwrap(context.pendingPreparation())

        XCTAssertNotEqual(old.generation, newest.generation)
        XCTAssertFalse(context.markPrepared(generation: old.generation),
                       "a stale prepare must not claim the newer pending generation")
        XCTAssertFalse(context.discardPending(generation: old.generation),
                       "a stale failure must not discard the newer pending generation")

        let retained = try XCTUnwrap(context.pendingPreparation())
        XCTAssertEqual(retained.generation, newest.generation)
        XCTAssertEqual(retained.asbd.mSampleRate, 48_000, accuracy: 0.5)
        XCTAssertEqual(retained.asbd.mChannelsPerFrame, 1)
        XCTAssertEqual(retained.asbd.mBytesPerFrame, newFormat.streamDescription.pointee.mBytesPerFrame)
        XCTAssertTrue(context.markPrepared(generation: newest.generation))

        context.prepare(format: oldFormat.streamDescription.pointee, maxFrames: 64)
        context.disable()
        XCTAssertNil(context.pendingPreparation(), "disable must drop a newly queued prepare")
        XCTAssertFalse(context.markPrepared(generation: newest.generation))
    }

    func testVideoMeterDeferredUnprepareKeepsNewerPreparedGeneration() throws {
        let context = VideoAudioMeterContext()
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let asbd = format.streamDescription.pointee

        // A failed markPrepared leaves preparedGeneration at zero. Deferred
        // cleanup must still release the native graph once the context is idle.
        context.prepare(format: asbd, maxFrames: 256)
        let failed = try XCTUnwrap(context.pendingPreparation())
        try context.renderer.prepare(actualASBD: asbd, maxFrames: 256)
        context.scheduleUnprepareWhenIdle(expectedGeneration: failed.generation)
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        XCTAssertNoThrow(try context.renderer.prepare(actualASBD: asbd, maxFrames: 256))
        context.renderer.unprepare()

        // A newer successful generation must prevent an older deferred timer
        // from tearing down the graph it now owns.
        context.prepare(format: asbd, maxFrames: 256)
        let old = try XCTUnwrap(context.pendingPreparation())
        try context.renderer.prepare(actualASBD: asbd, maxFrames: 256)
        XCTAssertTrue(context.markPrepared(generation: old.generation))
        context.renderer.unprepare()
        context.prepare(format: asbd, maxFrames: 256)
        let newest = try XCTUnwrap(context.pendingPreparation())
        try context.renderer.prepare(actualASBD: asbd, maxFrames: 256)
        XCTAssertTrue(context.markPrepared(generation: newest.generation))
        context.scheduleUnprepareWhenIdle(expectedGeneration: old.generation)
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        XCTAssertThrowsError(try context.renderer.prepare(actualASBD: asbd, maxFrames: 256))
        context.disable()
        context.renderer.unprepare()
    }

    func testVideoMeterLifecycleTokenBlocksStaleRenderAndProvesFreshWetRender() throws {
        let context = VideoAudioMeterContext()
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let asbd = format.streamDescription.pointee
        let settings = AudioEffectsSettings(preset: .sewer, intensity: 0.8)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512))
        buffer.frameLength = 512
        for channel in 0..<2 {
            let samples = try XCTUnwrap(buffer.floatChannelData?[channel])
            for frame in 0..<512 {
                samples[frame] = Float(sin(Double(frame) * 0.11) * 0.2)
            }
        }
        defer {
            context.disable()
            context.renderer.unprepare()
        }

        context.prepare(format: asbd, maxFrames: 512)
        let old = try XCTUnwrap(context.pendingPreparation())
        try context.renderer.prepare(actualASBD: asbd, maxFrames: 512)
        context.renderer.update(settings: settings)
        XCTAssertTrue(context.markPrepared(generation: old.generation))

        // Simulate a late native prepare while the old graph still reports
        // prepared. The old prepared token must fail the lifecycle check even
        // before the native unprepare callback clears the prepared bit.
        context.prepare(format: asbd, maxFrames: 512)
        XCTAssertFalse(context.hasWetRendered,
                       "a new native generation invalidates the old wet proof")
        context.process(audioBufferList: buffer.mutableAudioBufferList, frames: 512)
        XCTAssertEqual(context.renderer.successfulWetRenderCount, 0,
                       "an invalidated prepared token must not render stale audio")

        context.markDry(requiresPreparation: true)
        context.renderer.unprepare()
        context.prepare(format: asbd, maxFrames: 512)
        let fresh = try XCTUnwrap(context.pendingPreparation())
        try context.renderer.prepare(actualASBD: asbd, maxFrames: 512)
        context.renderer.update(settings: settings)
        XCTAssertTrue(context.markPrepared(generation: fresh.generation))
        context.process(audioBufferList: buffer.mutableAudioBufferList, frames: 512)
        XCTAssertGreaterThan(context.renderer.successfulWetRenderCount, 0,
                             "a current token must prove an actual wet tap render")
    }

    func testEditingSoundExitsComparisonAndRelaunchKeepsEditedSound() throws {
        let suite = "CMVAudioComparisonEdit-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(audioEffectsDefaults: defaults)
        let first = AudioEffectsSettings(preset: .sewer, intensity: 0.42)
        model.updateAudioEffects(first)
        let saved = defaults.data(forKey: AudioEffectsPreferences.key)
        model.setOriginalSoundComparison(true)
        // Even selecting the same preset should return from temporary original sound.
        model.updateAudioEffects(first)
        XCTAssertFalse(model.isComparingOriginalSound)
        XCTAssertEqual(model.playback.audioEffectsSettings, first)
        XCTAssertEqual(defaults.data(forKey: AudioEffectsPreferences.key), saved)

        model.setOriginalSoundComparison(true)
        let edited = AudioEffectsSettings(preset: .custom, intensity: 0.25,
                                         custom: AudioEffectParameters(delay: 140, filter: 6_000))
        model.updateAudioEffects(edited)
        XCTAssertFalse(model.isComparingOriginalSound)
        XCTAssertEqual(model.playback.audioEffectsSettings, edited)
        model.setOriginalSoundComparison(true)
        let relaunched = AppModel(audioEffectsDefaults: defaults)
        XCTAssertFalse(relaunched.isComparingOriginalSound)
        XCTAssertEqual(relaunched.audioEffects, edited)
        XCTAssertEqual(relaunched.playback.audioEffectsSettings, edited)
    }

    func testNeutralSoundCannotEnterComparison() throws {
        let suite = "CMVNeutral-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(audioEffectsDefaults: defaults)
        model.setOriginalSoundComparison(true)
        XCTAssertFalse(model.isComparingOriginalSound)
        model.updateAudioEffects(AudioEffectsSettings(preset: .sewer, intensity: 0))
        model.setOriginalSoundComparison(true)
        XCTAssertFalse(model.isComparingOriginalSound)
        XCTAssertEqual(model.playback.audioEffectsSettings.intensity, 0)
        XCTAssertFalse(model.playback.isPlaying)
    }
}
#endif
