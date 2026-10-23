import XCTest
import AVFoundation
import SwiftData
import CMVDomain
import CMVLibrary
@testable import CMVPlayback

final class ReliabilityRegressionTests: XCTestCase {
    private func makeRepository() throws -> SwiftDataLibraryRepository {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MediaSourceRecord.self,
            TrackRecord.self,
            PlaylistRecord.self,
            configurations: configuration
        )
        return SwiftDataLibraryRepository(container: container)
    }

    private func makeSilentAudioFile(sampleRate: Double, duration: Double = 1, amplitude: Float = 0) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMV-Reliability-\(UUID().uuidString).caf")
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ), let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(sampleRate * duration)
        ), let samples = buffer.floatChannelData?[0] else {
            throw CocoaError(.fileWriteUnknown)
        }
        buffer.frameLength = buffer.frameCapacity
        samples.initialize(repeating: amplitude, count: Int(buffer.frameLength))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    func testSubstringSearchDoesNotDependOnExactTokensElsewhereInLibrary() async throws {
        let repository = try makeRepository()
        let sourceID = UUID()
        let files = [
            ScannedMediaFile(
                relativePath: "Lovely Song.flac",
                fileIdentifier: "lovely-song",
                fileSize: 10,
                modifiedAt: .now,
                title: "Lovely Song"
            ),
            ScannedMediaFile(
                relativePath: "Love Letter.flac",
                fileIdentifier: "love-letter",
                fileSize: 11,
                modifiedAt: .now,
                title: "Love Letter"
            ),
            ScannedMediaFile(
                relativePath: "Songbook.flac",
                fileIdentifier: "songbook",
                fileSize: 12,
                modifiedAt: .now,
                title: "Songbook"
            )
        ]
        try await repository.applyScan(files, sourceID: sourceID, sourceWasReachable: true)

        let matches = try await repository.tracks(matching: "love song", limit: 20, offset: 0)
        XCTAssertEqual(matches.map(\.title), ["Lovely Song"])
    }

    func testScanCompletionUsesPresenceRatherThanMetadataMutation() {
        let sourceID = UUID()
        let stable = Track(
            sourceID: sourceID,
            relativePath: "stable.flac",
            fileIdentifier: "stable",
            title: "Stable",
            fileSize: 1,
            modifiedAt: .now
        )
        let removed = Track(
            sourceID: sourceID,
            relativePath: "removed.flac",
            fileIdentifier: "removed",
            title: "Removed",
            fileSize: 1,
            modifiedAt: .now
        )
        let alreadyMissing = Track(
            sourceID: sourceID,
            relativePath: "old.flac",
            fileIdentifier: "already-missing",
            title: "Already Missing",
            fileSize: 1,
            modifiedAt: .now,
            availability: .missing
        )
        let existing = [removed, stable, alreadyMissing]

        XCTAssertEqual(
            ScanCompletionPlanner.missingIdentifiers(
                existing: existing,
                seenIdentifiers: ["stable"],
                completedWithoutIssues: true
            ),
            ["removed"]
        )
        XCTAssertTrue(
            ScanCompletionPlanner.missingIdentifiers(
                existing: existing,
                seenIdentifiers: ["stable"],
                completedWithoutIssues: false
            ).isEmpty
        )
    }

    @MainActor
    func testFailedQueueReplacementRestoresPreviousTimelinePosition() async throws {
        let originalURL = try makeSilentAudioFile(sampleRate: 44_100)
        let rejectedURL = try makeSilentAudioFile(sampleRate: 48_000)
        defer {
            try? FileManager.default.removeItem(at: originalURL)
            try? FileManager.default.removeItem(at: rejectedURL)
        }

        let sourceID = UUID()
        let original = Track(
            sourceID: sourceID,
            relativePath: originalURL.lastPathComponent,
            fileIdentifier: "original",
            title: "Original",
            duration: 1,
            fileSize: 1,
            modifiedAt: .now
        )
        let rejected = Track(
            sourceID: sourceID,
            relativePath: rejectedURL.lastPathComponent,
            fileIdentifier: "rejected",
            title: "Rejected",
            duration: 1,
            fileSize: 1,
            modifiedAt: .now
        )
        let engine = NativePlaybackEngine { engineRate, current, _ in
            if current.sampleRateHz == 48_000 {
                throw NativePlaybackError.invalidAudioFormat
            }
            let remaining = current.totalFrames - current.startFrame
            let nextStart = UInt64(
                (Double(remaining) * Double(engineRate) / Double(current.sampleRateHz)).rounded()
            )
            return PlaybackSchedulePlan(
                currentStartFrame: current.startFrame,
                currentFrameCount: remaining,
                nextStartEngineFrame: nextStart,
                currentGainLinear: 1,
                nextGainLinear: 1
            )
        }

        try await engine.load(
            PlaybackQueue(tracks: [original]),
            resolvedURLs: [original.id: originalURL]
        )
        engine.seek(to: 0.25)
        XCTAssertEqual(engine.elapsed, 0.25, accuracy: 0.01)

        do {
            try await engine.load(
                PlaybackQueue(tracks: [rejected]),
                resolvedURLs: [rejected.id: rejectedURL]
            )
            XCTFail("replacement planner failure must escape to the caller")
        } catch {
            XCTAssertEqual(engine.queue.current?.id, original.id)
            XCTAssertEqual(engine.elapsed, 0.25, accuracy: 0.01)
            XCTAssertFalse(engine.isPlaying)
        }
    }

    @MainActor
    func testCurrentItemSeekReadinessFollowsQueueAndPreparedFileLifecycle() async throws {
        let audioURL = try makeSilentAudioFile(sampleRate: 44_100)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let track = Track(sourceID: UUID(), relativePath: audioURL.lastPathComponent,
                          fileIdentifier: "seek-readiness", title: "Seek readiness",
                          duration: 1, fileSize: 1, modifiedAt: .now)
        let engine = NativePlaybackEngine()

        XCTAssertFalse(engine.isCurrentItemPrepared)
        XCTAssertFalse(engine.canSeek)

        // A restored queue can be present while its current file is still
        // unopened. This is the cold-restore state that previously accepted
        // a seek gesture and then returned from the engine guard.
        engine.setQueue(PlaybackQueue(tracks: [track]))
        XCTAssertFalse(engine.isCurrentItemPrepared)
        XCTAssertFalse(engine.canSeek)

        try await engine.load(PlaybackQueue(tracks: [track]),
                              resolvedURLs: [track.id: audioURL])
        XCTAssertTrue(engine.isCurrentItemPrepared)
        XCTAssertTrue(engine.canSeek)

        engine.clearQueue()
        XCTAssertFalse(engine.isCurrentItemPrepared)
        XCTAssertFalse(engine.canSeek)
    }

    @MainActor
    func testAppendSkipsTrackWhoseFileDisappearedBeforeScheduling() async throws {
        let currentURL = try makeSilentAudioFile(sampleRate: 44_100)
        defer { try? FileManager.default.removeItem(at: currentURL) }
        let sourceID = UUID()
        let current = Track(sourceID: sourceID, relativePath: currentURL.lastPathComponent,
                            fileIdentifier: "current", title: "Current", duration: 1,
                            fileSize: 1, modifiedAt: .now)
        let missing = Track(sourceID: sourceID, relativePath: "missing.caf",
                            fileIdentifier: "missing", title: "Missing", duration: 1,
                            fileSize: 1, modifiedAt: .now)
        let engine = NativePlaybackEngine()
        try await engine.load(PlaybackQueue(tracks: [current]), resolvedURLs: [current.id: currentURL])
        let reportedFailure = expectation(description: "unplayable appended track reported")
        engine.onPlaybackError = { _ in reportedFailure.fulfill() }
        engine.appendToQueue([missing], resolvedURLs: [missing.id: currentURL.deletingLastPathComponent()
            .appendingPathComponent("CMV-missing-\(UUID().uuidString).caf")])
        await fulfillment(of: [reportedFailure], timeout: 5)
        XCTAssertEqual(engine.queue.tracks.map(\.id), [current.id])
        XCTAssertEqual(engine.baseQueueSnapshot.tracks.map(\.id), [current.id])
    }

    @MainActor
    func testAppendAfterQueueEndMakesNewTrackCurrent() async throws {
        let audioURL = try makeSilentAudioFile(sampleRate: 44_100)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let sourceID = UUID()
        let first = Track(sourceID: sourceID, relativePath: "first.caf",
                          fileIdentifier: "first", title: "First", duration: 1,
                          fileSize: 1, modifiedAt: .now)
        let second = Track(sourceID: sourceID, relativePath: "second.caf",
                           fileIdentifier: "second", title: "Second", duration: 1,
                           fileSize: 1, modifiedAt: .now)
        let engine = NativePlaybackEngine()
        try await engine.load(PlaybackQueue(tracks: [first]), resolvedURLs: [first.id: audioURL])
        let finished = expectation(description: "first queue finishes")
        engine.onQueueFinished = { finished.fulfill() }
        try engine.play()
        await fulfillment(of: [finished], timeout: 5)

        engine.appendToQueue([second], resolvedURLs: [second.id: audioURL])
        XCTAssertEqual(engine.queue.current?.id, second.id)
        XCTAssertEqual(engine.elapsed, 0, accuracy: 0.01)
    }

    @MainActor
    func testReplacingFutureQueueDuringPlaybackContinuesThroughAllTracks() async throws {
        let audioURL = try makeSilentAudioFile(sampleRate: 44_100)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let sourceID = UUID()
        let tracks = (0..<3).map { index in
            Track(sourceID: sourceID, relativePath: "replacement-\(index).caf",
                  fileIdentifier: "replacement-\(index)", title: "Track \(index)",
                  duration: 1, fileSize: 1, modifiedAt: .now)
        }
        let urls = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, audioURL) })
        let engine = NativePlaybackEngine()
        defer { engine.clearQueue() }
        try await engine.load(PlaybackQueue(tracks: tracks), resolvedURLs: urls)
        let finished = expectation(description: "replaced future route finishes")
        engine.onQueueFinished = { finished.fulfill() }
        try engine.play()
        try await Task.sleep(for: .milliseconds(100))

        engine.replaceFutureQueue([tracks[2], tracks[1]], resolvedURLs: urls)

        await fulfillment(of: [finished], timeout: 6)
        XCTAssertEqual(engine.queue.current?.id, tracks[1].id)
        XCTAssertFalse(engine.isPlaying)
    }

    @MainActor
    func testTrackRepairDuringNextFileOpenDoesNotLeaveQueueStalled() async throws {
        let audioURL = try makeSilentAudioFile(sampleRate: 44_100)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let sourceID = UUID()
        let tracks = (0..<3).map { index in
            Track(sourceID: sourceID, relativePath: "repair-\(index).caf",
                  fileIdentifier: "repair-\(index)", title: "Track \(index)",
                  duration: 1, fileSize: 1, modifiedAt: .now)
        }
        let opener = AudioFileOpener()
        let engine = NativePlaybackEngine(planner: { rate, current, _ in
            let remaining = current.totalFrames - current.startFrame
            return PlaybackSchedulePlan(
                currentStartFrame: current.startFrame, currentFrameCount: remaining,
                nextStartEngineFrame: UInt64((Double(remaining) * Double(rate) / Double(current.sampleRateHz)).rounded()),
                currentGainLinear: 1, nextGainLinear: 1
            )
        }, fileOpener: opener)
        defer { engine.clearQueue() }
        try await engine.load(PlaybackQueue(tracks: [tracks[0]]), resolvedURLs: [tracks[0].id: audioURL])
        await opener.delayNextOpen(by: 300_000_000)
        let finished = expectation(description: "repaired pending route finishes")
        engine.onQueueFinished = { finished.fulfill() }
        try engine.play()
        engine.appendToQueue([tracks[1]], resolvedURLs: [tracks[1].id: audioURL])
        try await Task.sleep(for: .milliseconds(50))

        engine.applyTrackReplacements([tracks[1].id: tracks[2].id], tracksByID: [tracks[2].id: tracks[2]])

        await fulfillment(of: [finished], timeout: 4)
        XCTAssertEqual(engine.queue.current?.id, tracks[2].id)
        XCTAssertFalse(engine.isPlaying)
    }

    @MainActor
    func testPausedFutureReplacementWaitsForResumeAndFinishes() async throws {
        let audioURL = try makeSilentAudioFile(sampleRate: 44_100)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let sourceID = UUID()
        let tracks = (0..<3).map { index in
            Track(sourceID: sourceID, relativePath: "paused-\(index).caf",
                  fileIdentifier: "paused-\(index)", title: "Track \(index)",
                  duration: 1, fileSize: 1, modifiedAt: .now)
        }
        let urls = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, audioURL) })
        let engine = NativePlaybackEngine()
        defer { engine.clearQueue() }
        try await engine.load(PlaybackQueue(tracks: tracks), resolvedURLs: urls)
        try engine.play()
        try await Task.sleep(for: .milliseconds(100))
        engine.pause()
        let pausedElapsed = engine.elapsed
        engine.replaceFutureQueue([tracks[2]], resolvedURLs: urls)
        try await Task.sleep(for: .milliseconds(1_200))
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(engine.queue.current?.id, tracks[0].id)
        XCTAssertEqual(engine.elapsed, pausedElapsed, accuracy: 0.001)
        let finished = expectation(description: "paused replacement finishes after resume")
        engine.onQueueFinished = { finished.fulfill() }

        try engine.play()

        await fulfillment(of: [finished], timeout: 3)
        XCTAssertEqual(engine.queue.current?.id, tracks[2].id)
        XCTAssertFalse(engine.isPlaying)
    }

    @MainActor
    func testLateFutureReplacementKeepsNextAudioRenderDeadline() async throws {
        let silentURL = try makeSilentAudioFile(sampleRate: 44_100, duration: 4)
        let markerURL = try makeSilentAudioFile(sampleRate: 44_100, amplitude: 0.25)
        defer {
            try? FileManager.default.removeItem(at: silentURL)
            try? FileManager.default.removeItem(at: markerURL)
        }
        let sourceID = UUID()
        let current = Track(sourceID: sourceID, relativePath: "current.caf", fileIdentifier: "deadline-current",
                            title: "Current", duration: 4, fileSize: 1, modifiedAt: .now)
        let marker = Track(sourceID: sourceID, relativePath: "marker.caf", fileIdentifier: "deadline-marker",
                           title: "Marker", duration: 1, fileSize: 1, modifiedAt: .now)
        let tail = Track(sourceID: sourceID, relativePath: "tail.caf", fileIdentifier: "deadline-tail",
                         title: "Tail", duration: 4, fileSize: 1, modifiedAt: .now)
        let urls = [current.id: silentURL, marker.id: markerURL, tail.id: silentURL]
        for seekOffset in [0.0, 2.0] {
            let engine = NativePlaybackEngine()
            defer { engine.clearQueue() }
            try await engine.load(PlaybackQueue(tracks: [current, marker, tail]), resolvedURLs: urls)
            if seekOffset > 0 { engine.seek(to: seekOffset) }
            engine.setVolume(0) // The tap observes the marker before the final output mute.
            let rendered = expectation(description: "next file actually renders near the original deadline")
            let clock = ContinuousClock()
            let start = clock.now
            var markerStart: Duration?
            engine.onOutputLevelChanged = { level in
                if level > 0.5, markerStart == nil {
                    markerStart = start.duration(to: clock.now)
                    rendered.fulfill()
                }
            }
            try engine.play()
            try await Task.sleep(for: .seconds(seekOffset == 0 ? 2 : 0.5))

            engine.replaceFutureQueue([marker], resolvedURLs: urls)

            await fulfillment(of: [rendered], timeout: 3)
            let actualStart = try XCTUnwrap(markerStart)
            XCTAssertGreaterThan(actualStart, .seconds(4 - seekOffset - 0.2))
            XCTAssertLessThan(actualStart, .seconds(4 - seekOffset + 0.4))
        }
    }

    @MainActor
    func testDelayedAppendedTrackDoesNotReportQueueFinished() async throws {
        let audioURL = try makeSilentAudioFile(sampleRate: 44_100)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let sourceID = UUID()
        let first = Track(sourceID: sourceID, relativePath: "first.caf",
                          fileIdentifier: "first-delayed", title: "First", duration: 1,
                          fileSize: 1, modifiedAt: .now)
        let second = Track(sourceID: sourceID, relativePath: "second.caf",
                           fileIdentifier: "second-delayed", title: "Second", duration: 1,
                           fileSize: 1, modifiedAt: .now)
        let third = Track(sourceID: sourceID, relativePath: "third.caf",
                          fileIdentifier: "third-delayed", title: "Third", duration: 1,
                          fileSize: 1, modifiedAt: .now)
        let opener = AudioFileOpener()
        let engine = NativePlaybackEngine(
            planner: { engineRate, current, _ in
                let remaining = current.totalFrames - current.startFrame
                let nextStart = UInt64(
                    (Double(remaining) * Double(engineRate) / Double(current.sampleRateHz)).rounded()
                )
                return PlaybackSchedulePlan(
                    currentStartFrame: current.startFrame,
                    currentFrameCount: remaining,
                    nextStartEngineFrame: nextStart,
                    currentGainLinear: 1,
                    nextGainLinear: 1
                )
            },
            fileOpener: opener
        )
        try await engine.load(PlaybackQueue(tracks: [first]), resolvedURLs: [first.id: audioURL])
        await opener.delayNextOpen(by: 2_000_000_000)

        var didReportQueueFinished = false
        let advanced = expectation(description: "delayed appended track becomes current")
        let continued = expectation(description: "following appended track becomes current")
        engine.onQueueFinished = { didReportQueueFinished = true }
        engine.onCurrentTrackChanged = { track in
            if track?.id == second.id { advanced.fulfill() }
            if track?.id == third.id { continued.fulfill() }
        }

        try engine.play()
        engine.appendToQueue([second, third], resolvedURLs: [second.id: audioURL, third.id: audioURL])
        await fulfillment(of: [advanced, continued], timeout: 6)

        XCTAssertFalse(didReportQueueFinished)
        XCTAssertEqual(engine.queue.current?.id, third.id)
        XCTAssertTrue(engine.isPlaying)
    }

    @MainActor
    func testMissingResolvedURLAfterCurrentTrackFinishesDoesNotHang() async throws {
        let audioURL = try makeSilentAudioFile(sampleRate: 44_100)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let sourceID = UUID()
        let first = Track(sourceID: sourceID, relativePath: "first.caf",
                          fileIdentifier: "first-unresolved", title: "First", duration: 1,
                          fileSize: 1, modifiedAt: .now)
        let second = Track(sourceID: sourceID, relativePath: "second.caf",
                           fileIdentifier: "second-unresolved", title: "Second", duration: 1,
                           fileSize: 1, modifiedAt: .now)
        let engine = NativePlaybackEngine()
        try await engine.load(PlaybackQueue(tracks: [first]), resolvedURLs: [first.id: audioURL])
        engine.setQueue(PlaybackQueue(tracks: [first, second]))

        let reportedFailure = expectation(description: "unresolved next track reported")
        let finished = expectation(description: "queue finishes after unresolved next track is removed")
        engine.onPlaybackError = { error in
            if case NativePlaybackError.unresolvedTrack = error { reportedFailure.fulfill() }
        }
        engine.onQueueFinished = { finished.fulfill() }

        try engine.play()
        await fulfillment(of: [reportedFailure, finished], timeout: 5)

        XCTAssertEqual(engine.queue.tracks.map(\.id), [first.id])
        XCTAssertEqual(engine.baseQueueSnapshot.tracks.map(\.id), [first.id])
    }

    @MainActor
    func testInitialLoadKeepsSelectedTrackWhenFutureFileCannotOpen() async throws {
        let audioURL = try makeSilentAudioFile(sampleRate: 44_100)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let sourceID = UUID()
        let current = Track(sourceID: sourceID, relativePath: "current-initial.caf",
                            fileIdentifier: "current-initial", title: "Current",
                            duration: 1, fileSize: 1, modifiedAt: .now)
        let future = Track(sourceID: sourceID, relativePath: "future-initial.caf",
                           fileIdentifier: "future-initial", title: "Future",
                           duration: 1, fileSize: 1, modifiedAt: .now)
        let invalidURL = audioURL.deletingLastPathComponent()
            .appendingPathComponent("CMV-invalid-initial-\(UUID().uuidString).caf")
        try Data([0x00, 0x01, 0x02]).write(to: invalidURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: invalidURL) }
        let engine = NativePlaybackEngine()

        try await engine.load(
            PlaybackQueue(tracks: [current, future]),
            resolvedURLs: [current.id: audioURL, future.id: invalidURL]
        )

        XCTAssertEqual(engine.queue.tracks.map(\.id), [current.id, future.id])
        XCTAssertEqual(engine.queue.current?.id, current.id)
        XCTAssertFalse(engine.isPlaying)
    }

    @MainActor
    func testFailedFutureOpenPreservesDuplicateBaseOccurrencesAndSnapshotValidity() async throws {
        let audioURL = try makeSilentAudioFile(sampleRate: 44_100)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let sourceID = UUID()
        let current = Track(sourceID: sourceID, relativePath: "current-duplicate.caf",
                            fileIdentifier: "current-duplicate", title: "Current",
                            duration: 1, fileSize: 1, modifiedAt: .now)
        let missing = Track(sourceID: sourceID, relativePath: "missing-duplicate.caf",
                            fileIdentifier: "missing-duplicate", title: "Missing",
                            duration: 1, fileSize: 1, modifiedAt: .now)
        let engine = NativePlaybackEngine()
        try await engine.load(PlaybackQueue(tracks: [current]), resolvedURLs: [current.id: audioURL])
        engine.toggleShuffle()

        let reportedFailure = expectation(description: "unplayable duplicate route entry reported")
        engine.onPlaybackError = { _ in reportedFailure.fulfill() }
        engine.appendToQueue(
            [missing, current],
            resolvedURLs: [
                missing.id: audioURL.deletingLastPathComponent()
                    .appendingPathComponent("CMV-missing-duplicate-\(UUID().uuidString).caf"),
                current.id: audioURL
            ]
        )
        await fulfillment(of: [reportedFailure], timeout: 5)

        XCTAssertEqual(engine.queue.tracks.map(\.id), [current.id, current.id])
        XCTAssertEqual(engine.baseQueueSnapshot.tracks.map(\.id), [current.id, current.id])
        XCTAssertEqual(engine.baseQueueSnapshot.currentIndex, 0)

        var occurrencePool: [UUID: [UUID]] = [:]
        let entries = engine.queue.tracks.map { track in
            let occurrence = PlaybackQueueOccurrence(trackID: track.id)
            occurrencePool[track.id, default: []].append(occurrence.occurrenceID)
            return occurrence
        }
        var unmatchedBaseOccurrence = false
        let baseEntries = engine.baseQueueSnapshot.tracks.map { track in
            guard var occurrences = occurrencePool[track.id], !occurrences.isEmpty else {
                unmatchedBaseOccurrence = true
                return PlaybackQueueOccurrence(trackID: track.id)
            }
            let occurrenceID = occurrences.removeFirst()
            occurrencePool[track.id] = occurrences
            return PlaybackQueueOccurrence(occurrenceID: occurrenceID, trackID: track.id)
        }
        XCTAssertFalse(unmatchedBaseOccurrence)
        let snapshot = PlaybackQueueSnapshot(
            entries: entries,
            baseEntries: baseEntries,
            currentIndex: engine.queue.currentIndex
        )
        XCTAssertTrue(PlaybackQueuePlanner.isWellFormed(snapshot))

        engine.toggleShuffle()
        XCTAssertEqual(engine.queue.tracks.map(\.id), [current.id, current.id])
        XCTAssertEqual(engine.baseQueueSnapshot.tracks.map(\.id), [current.id, current.id])
    }

    @MainActor
    func testManualSkipReachesNewlyAppendedPageWithoutStartingPausedPlayer() async throws {
        let audioURL = try makeSilentAudioFile(sampleRate: 44_100)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let sourceID = UUID()
        let first = Track(sourceID: sourceID, relativePath: "first.caf",
                          fileIdentifier: "first", title: "First", duration: 1,
                          fileSize: 1, modifiedAt: .now)
        let second = Track(sourceID: sourceID, relativePath: "second.caf",
                           fileIdentifier: "second", title: "Second", duration: 1,
                           fileSize: 1, modifiedAt: .now)
        let engine = NativePlaybackEngine()
        try await engine.load(PlaybackQueue(tracks: [first]), resolvedURLs: [first.id: audioURL])

        engine.appendToQueue([second], resolvedURLs: [second.id: audioURL])
        try engine.skipForward()

        XCTAssertEqual(engine.queue.current?.id, second.id)
        XCTAssertFalse(engine.isPlaying)
    }

    @MainActor
    func testShuffledTransitionDoesNotReusePreparedFileForDifferentTrack() throws {
        let audioURL = try makeSilentAudioFile(sampleRate: 44_100)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let file = try AVAudioFile(forReading: audioURL)
        let sourceID = UUID()
        let tracks = (0..<3).map { index in
            Track(sourceID: sourceID, relativePath: "\(index).caf",
                  fileIdentifier: "track-\(index)", title: "Track \(index)",
                  fileSize: 1, modifiedAt: .now)
        }
        let original = PlaybackQueue(tracks: tracks)
        let shuffled = PlaybackQueue(tracks: [tracks[0], tracks[2], tracks[1]])
        let reusable = NativePlaybackEngine.reusablePreparedFiles(
            [0: file, 1: file], from: original, for: shuffled
        )
        XCTAssertEqual(Set(reusable.keys), [0])
        XCTAssertEqual(Set(NativePlaybackEngine.reusablePreparedFiles(
            [0: file, 1: file], from: original, for: original
        ).keys), [0, 1])
    }

    func testMissingTrackMutationFailsInsteadOfReportingFalseSuccess() async throws {
        let repository = try makeRepository()
        let missingID = UUID()

        do {
            try await repository.setFavorite(trackID: missingID, isFavorite: true)
            XCTFail("missing track mutation must fail")
        } catch let error as LibraryRepositoryError {
            XCTAssertEqual(error, .trackNotFound(missingID))
        }
    }

    func testPlaylistRejectsMissingTracksAndMissingPlaylistMutations() async throws {
        let repository = try makeRepository()
        let playlist = try await repository.createPlaylist(name: "可靠性")
        let missingTrackID = UUID()

        do {
            try await repository.addTrack(trackID: missingTrackID, toPlaylist: playlist.id)
            XCTFail("playlist must not accept an orphan track id")
        } catch let error as LibraryRepositoryError {
            XCTAssertEqual(error, .trackNotFound(missingTrackID))
        }

        try await repository.deletePlaylist(id: playlist.id)
        do {
            try await repository.renamePlaylist(id: playlist.id, name: "不存在")
            XCTFail("missing playlist mutation must fail")
        } catch let error as LibraryRepositoryError {
            XCTAssertEqual(error, .playlistNotFound(playlist.id))
        }
    }
}
