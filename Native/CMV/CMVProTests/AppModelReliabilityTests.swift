import XCTest
import SwiftData
import CMVDomain
import CMVLibrary
import CMVPlayback
import CMVCache
@testable import CMV

#if DEBUG && CMV_STOREKIT_TEST_HOST
@MainActor
final class AppModelReliabilityTests: XCTestCase {
    func testPlaybackAccessLeasesDeduplicateRootsAndClear() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("CMVPlaybackLeaseDedup-\(UUID().uuidString)", isDirectory: true)
        let first = root.appendingPathComponent("first", isDirectory: true)
        let second = root.appendingPathComponent("second", isDirectory: true)
        try fileManager.createDirectory(at: first, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: second, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let payload = Data(repeating: 0x5A, count: 64 * 1024)
        let fixture = first.appendingPathComponent("fixture.bin")
        try payload.write(to: fixture, options: .atomic)
        XCTAssertEqual(try Data(contentsOf: fixture).count, payload.count)

        let snapshot = PlaybackQueueSnapshotStore(
            url: root.appendingPathComponent("queue.json")
        )
        let model = AppModel(queueSnapshotStore: snapshot)
        let coordinator = SourceAccessCoordinator()
        var firstLease: SecurityScopedResourceLease?
        weak var weakFirstLease: SecurityScopedResourceLease?
        for _ in 0..<1_000 {
            var lease: SecurityScopedResourceLease? = try await coordinator.lease(for: first)
            if firstLease == nil {
                firstLease = lease
                weakFirstLease = lease
            }
            model.retainPlaybackAccessLeasesForTesting([try XCTUnwrap(lease)])
            lease = nil
            XCTAssertEqual(model.playbackAccessLeaseCountForTesting, 1)
        }
        XCTAssertNotNil(weakFirstLease)

        var duplicateLease: SecurityScopedResourceLease? = try await coordinator.lease(for: first)
        weak var weakDuplicateLease: SecurityScopedResourceLease? = duplicateLease
        model.retainPlaybackAccessLeasesForTesting([try XCTUnwrap(duplicateLease)])
        duplicateLease = nil
        XCTAssertEqual(model.playbackAccessLeaseCountForTesting, 1)
        XCTAssertNil(weakDuplicateLease)

        var secondLease: SecurityScopedResourceLease? = try await coordinator.lease(for: second)
        weak var weakSecondLease: SecurityScopedResourceLease? = secondLease
        model.retainPlaybackAccessLeasesForTesting([try XCTUnwrap(secondLease)])
        secondLease = nil

        XCTAssertEqual(model.playbackAccessLeaseCountForTesting, 2)
        XCTAssertNotNil(weakFirstLease)
        XCTAssertNotNil(weakSecondLease)

        // The test's initial strong reference must not mask the production
        // clear/deinit assertion below.
        firstLease = nil
        model.clearPlaybackAccessLeasesForTesting()
        XCTAssertEqual(model.playbackAccessLeaseCountForTesting, 0)
        XCTAssertNil(weakFirstLease)
        XCTAssertNil(weakSecondLease)
    }

    func testMixedRouteFinalAudioKeepsWellFormedFullRouteSnapshot() async throws {
        let sourceID = UUID()
        let audioBeforePath = "Source-B/12_background-背景測試-180s-🕯️.m4a"
        let videoPath = "Source-B/13_video-星座圖案-簡易聲音-🎞️.mov"
        let audioAfterPath = "Source-B/07_夢の反射-Dream-✨.m4a"
        let audioBefore = Track(sourceID: sourceID, relativePath: audioBeforePath,
                                fileIdentifier: "before", title: "Before", duration: 180,
                                fileSize: 1, modifiedAt: .now)
        let video = Track(sourceID: sourceID, relativePath: videoPath,
                          fileIdentifier: "middle", title: "Middle", duration: 30,
                          fileSize: 1, modifiedAt: .now, mediaKind: .video)
        let audioAfter = Track(sourceID: sourceID, relativePath: audioAfterPath,
                               fileIdentifier: "after", title: "After", duration: 54,
                               fileSize: 1, modifiedAt: .now)
        let route = [audioBefore, video, audioAfter]

        XCTAssertTrue(AppModel.shouldRetainMixedQueue(tracks: route, nextVideoIndex: route.count))
        XCTAssertTrue(AppModel.shouldRetainMixedQueue(tracks: route, nextVideoIndex: 1))
        XCTAssertFalse(AppModel.shouldRetainMixedQueue(tracks: [audioAfter], nextVideoIndex: 1))

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVMixedRoute-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = try FileOfflineCacheStore(
            pinnedRoot: root.appendingPathComponent("Pinned", isDirectory: true),
            smartRoot: root.appendingPathComponent("Smart", isDirectory: true)
        )
        let snapshotURL = root.appendingPathComponent("queue-\(UUID().uuidString).json")
        let store = PlaybackQueueSnapshotStore(url: snapshotURL)
        let model = AppModel(queueSnapshotStore: store, offlineCacheStore: cache)
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        model.seedVideoPlaybackForTesting(tracks: route, currentIndex: 1)
        model.finishVideoToTerminalAudioForTesting(context: context)
        model.finishAudioQueueForTesting()
        XCTAssertEqual(model.displayQueue.tracks.map(\.id), route.map(\.id))
        XCTAssertEqual(model.displayQueue.currentIndex, 2)
        let flushed = await model.flushPlaybackQueueSnapshot()
        XCTAssertTrue(flushed)

        let loaded = await store.load()
        let restored = try XCTUnwrap(loaded)
        XCTAssertTrue(PlaybackQueuePlanner.isWellFormed(restored))
        XCTAssertEqual(restored.entries.map(\.trackID), route.map(\.id))
        XCTAssertEqual(restored.baseEntries.map(\.trackID), route.map(\.id))
        XCTAssertEqual(restored.currentIndex, 2)
        XCTAssertGreaterThanOrEqual(restored.history.count, 2)
        let expectedHistory = Array(restored.entries.prefix(2).map(\.occurrenceID))
        XCTAssertEqual(Array(restored.history.prefix(2)), expectedHistory)
        XCTAssertFalse(restored.shuffleEnabled)
        XCTAssertEqual(restored.repeatMode, .off)
    }

    func testColdRestoreVideoToTerminalAudioKeepsFullRouteSnapshot() async throws {
        let sourceID = UUID()
        let fixtureRootPath = ProcessInfo.processInfo.environment["CMV_RICH_FIXTURE_ROOT"] ?? ""
        try XCTSkipUnless(!fixtureRootPath.isEmpty,
                          "Set CMV_RICH_FIXTURE_ROOT to run the rich media fixture test")
        let fixtureRoot = URL(fileURLWithPath: fixtureRootPath)
        try XCTSkipUnless(FileManager.default.fileExists(atPath: fixtureRoot.path),
                          "CMV_RICH_FIXTURE_ROOT is unavailable in this environment")
        let files = [
            ScannedMediaFile(relativePath: "Source-B/12_background-背景測試-180s-🕯️.m4a",
                             fileIdentifier: "cold-before", fileSize: 1, modifiedAt: .now,
                             title: "Before", duration: 180),
            ScannedMediaFile(relativePath: "Source-B/13_video-星座圖案-簡易聲音-🎞️.mov",
                             fileIdentifier: "cold-video", fileSize: 1, modifiedAt: .now,
                             title: "Video", duration: 180, mediaKind: .video),
            ScannedMediaFile(relativePath: "Source-B/07_夢の反射-Dream-✨.m4a",
                             fileIdentifier: "cold-after", fileSize: 1, modifiedAt: .now,
                             title: "Dream", duration: 54)
        ]
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVColdVideoEOF-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = try FileOfflineCacheStore(
            pinnedRoot: root.appendingPathComponent("Pinned", isDirectory: true),
            smartRoot: root.appendingPathComponent("Smart", isDirectory: true)
        )
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let repository = SwiftDataLibraryRepository(container: container)
        try await repository.applyReconciliation(upserts: files, missingIdentifiers: [], sourceID: sourceID)
        let byPath = Dictionary(uniqueKeysWithValues: try await repository.tracks(sourceID: sourceID)
            .map { ($0.relativePath, $0) })
        let route = try files.map { file in
            try XCTUnwrap(byPath[file.relativePath])
        }
        for track in route {
            XCTAssertTrue(FileManager.default.fileExists(
                atPath: fixtureRoot.appendingPathComponent(track.relativePath).path
            ))
        }
        let occurrences = route.map { PlaybackQueueOccurrence(trackID: $0.id) }
        let expectedOccurrenceIDs = occurrences.map(\.occurrenceID)
        let snapshotURL = root.appendingPathComponent("queue.json")
        let store = PlaybackQueueSnapshotStore(url: snapshotURL)
        try await store.save(PlaybackQueueSnapshot(
            revision: 1,
            entries: occurrences,
            baseEntries: occurrences,
            currentIndex: 1,
            history: [],
            shuffleEnabled: false,
            repeatMode: .off
        ))

        let model = AppModel(queueSnapshotStore: store, offlineCacheStore: cache)
        await model.restorePlaybackQueueIfNeeded(context: context)
        XCTAssertEqual(model.displayQueue.tracks.map(\.id), route.map(\.id))
        XCTAssertEqual(model.displayQueue.currentIndex, 1)

        model.seedVideoPlaybackForTesting(tracks: route, currentIndex: 1)
        XCTAssertNotNil(model.videoURL)
        model.finishVideoToTerminalAudioForTesting(context: context)
        XCTAssertNil(model.videoURL)
        XCTAssertEqual(model.playback.queue.current?.id, route[2].id)
        XCTAssertEqual(model.displayQueue.tracks.map(\.id), route.map(\.id))
        XCTAssertEqual(model.queuePanelDisplayQueue.tracks.map(\.id), route.map(\.id))
        XCTAssertEqual(model.displayQueue.currentIndex, 2)
        XCTAssertEqual(model.queuePanelDisplayQueue.currentIndex, 2)
        XCTAssertTrue(model.canShuffleQueue)

        model.finishAudioQueueForTesting()
        let flushed = await model.flushPlaybackQueueSnapshot()
        XCTAssertTrue(flushed)
        let loaded = await store.load()
        let saved = try XCTUnwrap(loaded)
        XCTAssertTrue(PlaybackQueuePlanner.isWellFormed(saved))
        XCTAssertEqual(saved.entries.map(\.trackID), route.map(\.id))
        XCTAssertEqual(saved.baseEntries.map(\.trackID), route.map(\.id))
        XCTAssertEqual(saved.entries.map(\.occurrenceID), expectedOccurrenceIDs)
        XCTAssertEqual(saved.baseEntries.map(\.occurrenceID), expectedOccurrenceIDs)
        XCTAssertEqual(saved.currentIndex, 2)
        XCTAssertEqual(saved.shuffleEnabled, false)
        XCTAssertEqual(saved.repeatMode, .off)
        XCTAssertTrue(Set(saved.history).isSubset(of: Set(saved.entries.map(\.occurrenceID))))
        XCTAssertTrue(saved.history.contains(saved.entries[2].occurrenceID))

        model.clearPlaybackQueue()
        XCTAssertTrue(model.displayQueue.tracks.isEmpty)
        XCTAssertTrue(model.queuePanelDisplayQueue.tracks.isEmpty)
    }

    func testMixedShuffleReorderWithDuplicateOccurrencesKeepsSnapshotWellFormed() async throws {
        let snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVMixedShuffleDuplicate-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: snapshotURL) }
        let store = PlaybackQueueSnapshotStore(url: snapshotURL)
        let sourceID = UUID()
        let video = Track(sourceID: sourceID, relativePath: "video.mov",
                          fileIdentifier: "shuffle-video", title: "Video", duration: 30,
                          fileSize: 1, modifiedAt: .now, mediaKind: .video)
        let duplicate = Track(sourceID: sourceID, relativePath: "duplicate.m4a",
                              fileIdentifier: "shuffle-duplicate", title: "Duplicate",
                              duration: 30, fileSize: 1, modifiedAt: .now)
        let tailA = Track(sourceID: sourceID, relativePath: "tail-a.m4a",
                          fileIdentifier: "shuffle-tail-a", title: "Tail A", duration: 30,
                          fileSize: 1, modifiedAt: .now)
        let tailB = Track(sourceID: sourceID, relativePath: "tail-b.m4a",
                          fileIdentifier: "shuffle-tail-b", title: "Tail B", duration: 30,
                          fileSize: 1, modifiedAt: .now)
        let tailC = Track(sourceID: sourceID, relativePath: "tail-c.m4a",
                          fileIdentifier: "shuffle-tail-c", title: "Tail C", duration: 30,
                          fileSize: 1, modifiedAt: .now)
        let route = [video, duplicate, duplicate, tailA, tailB, tailC]
        let model = AppModel(queueSnapshotStore: store)
        model.seedVideoPlaybackForTesting(tracks: route)

        model.toggleShuffle()
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        model.movePlaybackQueueItem(from: 3, to: 5, context: context)
        let flushed = await model.flushPlaybackQueueSnapshot()
        XCTAssertTrue(flushed)
        let loaded = await store.load()
        let saved = try XCTUnwrap(loaded)
        XCTAssertTrue(PlaybackQueuePlanner.isWellFormed(saved))
        XCTAssertEqual(saved.entries.count, route.count)
        XCTAssertEqual(saved.baseEntries.count, route.count)
        XCTAssertEqual(Set(saved.entries.map(\.occurrenceID)), Set(saved.baseEntries.map(\.occurrenceID)))
        XCTAssertEqual(
            Dictionary(grouping: saved.baseEntries, by: \.trackID).mapValues(\.count),
            Dictionary(grouping: route, by: \.id).mapValues(\.count)
        )
        XCTAssertEqual(saved.entries.filter { $0.trackID == duplicate.id }.count, 2)
        XCTAssertEqual(Set(saved.entries.filter { $0.trackID == duplicate.id }.map(\.occurrenceID)).count, 2)
        XCTAssertTrue(saved.shuffleEnabled)
    }

    func testMixedShufflePreservesDuplicateOccurrenceOrdinalsInBaseSnapshot() async throws {
        let snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVMixedShuffleOccurrenceOrdinals-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: snapshotURL) }
        let store = PlaybackQueueSnapshotStore(url: snapshotURL)
        let sourceID = UUID()
        let video = Track(sourceID: sourceID, relativePath: "ordinal-video.mov",
                          fileIdentifier: "ordinal-video", title: "Video", duration: 30,
                          fileSize: 1, modifiedAt: .now, mediaKind: .video)
        let duplicate = Track(sourceID: sourceID, relativePath: "ordinal-duplicate.m4a",
                              fileIdentifier: "ordinal-duplicate", title: "Duplicate", duration: 30,
                              fileSize: 1, modifiedAt: .now)
        let tailA = Track(sourceID: sourceID, relativePath: "ordinal-tail-a.m4a",
                          fileIdentifier: "ordinal-tail-a", title: "Tail A", duration: 30,
                          fileSize: 1, modifiedAt: .now)
        let tailB = Track(sourceID: sourceID, relativePath: "ordinal-tail-b.m4a",
                          fileIdentifier: "ordinal-tail-b", title: "Tail B", duration: 30,
                          fileSize: 1, modifiedAt: .now)
        let route = [video, duplicate, duplicate, tailA, tailB]
        let model = AppModel(queueSnapshotStore: store)
        model.seedVideoPlaybackForTesting(tracks: route)

        model.toggleShuffle()
        let initialFlushed = await model.flushPlaybackQueueSnapshot()
        XCTAssertTrue(initialFlushed)
        let initialSnapshot = await store.load()
        let initial = try XCTUnwrap(initialSnapshot)
        let expectedBaseOccurrenceIDs = Dictionary(grouping: initial.baseEntries, by: \.trackID)
            .mapValues { $0.map(\.occurrenceID) }
        let expectedDuplicateOccurrenceIDs = initial.baseEntries
            .filter { $0.trackID == duplicate.id }
            .map(\.occurrenceID)
        XCTAssertEqual(expectedDuplicateOccurrenceIDs.count, 2)

        let context = ModelContext(try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        ))
        model.movePlaybackQueueItem(from: 3, to: 5, context: context)
        let savedFlushed = await model.flushPlaybackQueueSnapshot()
        XCTAssertTrue(savedFlushed)
        let savedSnapshot = await store.load()
        let saved = try XCTUnwrap(savedSnapshot)

        XCTAssertTrue(PlaybackQueuePlanner.isWellFormed(saved))
        XCTAssertEqual(
            saved.baseEntries.filter { $0.trackID == duplicate.id }.map(\.occurrenceID),
            expectedDuplicateOccurrenceIDs
        )
        for (trackID, occurrenceIDs) in expectedBaseOccurrenceIDs {
            XCTAssertEqual(
                saved.baseEntries.filter { $0.trackID == trackID }.map(\.occurrenceID),
                occurrenceIDs
            )
        }
    }

    func testTerminalVideoEndAndNextPreserveDuplicateOccurrences() async throws {
        for manualSkip in [false, true] {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("CMVTerminalVideo-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let store = PlaybackQueueSnapshotStore(url: root.appendingPathComponent("queue.json"))
            let model = AppModel(queueSnapshotStore: store)
            let sourceID = UUID()
            let audio = Track(sourceID: sourceID, relativePath: "audio.wav",
                              fileIdentifier: "audio", title: "Audio", duration: 20,
                              fileSize: 1, modifiedAt: .now)
            let video = Track(sourceID: sourceID, relativePath: "video.mov",
                              fileIdentifier: "video", title: "Video", duration: 12,
                              fileSize: 1, modifiedAt: .now, mediaKind: .video)
            let route = [audio, video, video]
            let container = try ModelContainer(
                for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let context = ModelContext(container)
            model.seedVideoPlaybackForTesting(tracks: route, currentIndex: 2)
            model.toggleShuffle()
            model.toggleShuffle()
            let initialFlushed = await model.flushPlaybackQueueSnapshot()
            XCTAssertTrue(initialFlushed)
            let initialLoaded = await store.load()
            let initial = try XCTUnwrap(initialLoaded)

            model.advanceAfterVideo(context: context, manualSkip: manualSkip)

            XCTAssertNotNil(model.videoURL)
            XCTAssertEqual(model.currentTrackID, video.id)
            XCTAssertEqual(model.displayQueue.tracks.map(\.id), route.map(\.id))
            XCTAssertEqual(model.displayQueue.currentIndex, 2)
            XCTAssertFalse(model.videoSession.isPlaying)
            let finalFlushed = await model.flushPlaybackQueueSnapshot()
            XCTAssertTrue(finalFlushed)
            let finalLoaded = await store.load()
            let saved = try XCTUnwrap(finalLoaded)
            XCTAssertTrue(PlaybackQueuePlanner.isWellFormed(saved))
            XCTAssertEqual(saved.entries, initial.entries)
            XCTAssertEqual(saved.baseEntries, initial.baseEntries)
            XCTAssertEqual(saved.currentIndex, 2)
            XCTAssertEqual(Set(saved.entries.map(\.occurrenceID)).count, route.count)
        }
    }

    func testExplicitVideoStopClearsPlaybackQueue() async throws {
        let snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVExplicitVideoStop-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: snapshotURL) }
        let store = PlaybackQueueSnapshotStore(url: snapshotURL)
        let model = AppModel(queueSnapshotStore: store)
        let track = Track(sourceID: UUID(), relativePath: "test.mov",
                          fileIdentifier: "test-video", title: "Test Video",
                          duration: 30, fileSize: 1, modifiedAt: .now,
                          mediaKind: .video)
        model.seedVideoPlaybackForTesting(tracks: [track])
        XCTAssertFalse(model.playback.queue.tracks.isEmpty)

        model.stopVideoPlayback()

        XCTAssertTrue(model.playback.queue.tracks.isEmpty)
        XCTAssertTrue(model.displayQueue.tracks.isEmpty)
        let flushed = await model.flushPlaybackQueueSnapshot()
        XCTAssertTrue(flushed)
        let loaded = await store.load()
        let snapshot = try XCTUnwrap(loaded)
        XCTAssertTrue(snapshot.entries.isEmpty)
        XCTAssertTrue(snapshot.baseEntries.isEmpty)
    }

    func testNewPlaybackRequestSupersedesSuspendedQueueRestore() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        try await repository.applyReconciliation(upserts: [
            ScannedMediaFile(relativePath: "saved.caf", fileIdentifier: "saved", fileSize: 1,
                             modifiedAt: .now, title: "Saved")
        ], missingIdentifiers: [], sourceID: sourceID)
        let savedTracks = try await repository.tracks(sourceID: sourceID)
        let savedTrack = try XCTUnwrap(savedTracks.first)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVRestoreRace-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = PlaybackQueueSnapshotStore(url: url)
        try await store.save(PlaybackQueueSnapshot(
            revision: 1, entries: [PlaybackQueueOccurrence(trackID: savedTrack.id)]
        ))
        let model = AppModel(queueSnapshotStore: store)
        let context = ModelContext(container)
        let suspended = expectation(description: "restore suspended after loading snapshot")
        var continuation: CheckedContinuation<Void, Never>?
        model.queueRestoreTestAfterSnapshot = {
            await withCheckedContinuation { resume in
                continuation = resume
                suspended.fulfill()
            }
        }
        let restoration = Task { await model.restorePlaybackQueueIfNeeded(context: context) }
        await fulfillment(of: [suspended], timeout: 5)
        // Source resolution is asynchronous and this source is unavailable.
        // The new explicit request still supersedes startup restoration.
        let selected = Track(sourceID: UUID(), relativePath: "selected.caf",
                             fileIdentifier: "selected", title: "Selected",
                             fileSize: 1, modifiedAt: .now)
        model.play(track: selected, context: context)
        continuation?.resume()
        await restoration.value
        XCTAssertFalse(model.playback.queue.tracks.contains { $0.id == savedTrack.id })
        XCTAssertFalse(model.playback.isPlaying)
        // A second panel task must not resurrect the persisted selection either.
        await model.restorePlaybackQueueIfNeeded(context: context)
        XCTAssertFalse(model.playback.queue.tracks.contains { $0.id == savedTrack.id })
    }

    func testQueueSnapshotWriteFailureIsObservableAndFlushRetriesLatestSnapshot() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVQueueWriteFailure-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }

        let store = PlaybackQueueSnapshotStore(url: url)
        let model = AppModel(queueSnapshotStore: store)
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        await model.restorePlaybackQueueIfNeeded(context: context)

        let track = Track(sourceID: UUID(), relativePath: "queue.caf",
                          fileIdentifier: "queue", title: "Queue",
                          fileSize: 1, modifiedAt: .now)
        model.playback.setQueue(PlaybackQueue(tracks: [track]))
        let failed = await model.flushPlaybackQueueSnapshot()
        XCTAssertFalse(failed)
        let expectedErrorPrefix = String(format: AppLanguage.localized("無法保存播放佇列：%@"), "")
        XCTAssertTrue(model.errorMessage?.hasPrefix(expectedErrorPrefix) == true)

        try FileManager.default.removeItem(at: url)
        let recovered = await model.flushPlaybackQueueSnapshot()
        XCTAssertTrue(recovered)
        let saved = await store.load()
        XCTAssertEqual(saved?.entries.map(\.trackID), [track.id])
    }

    func testDuplicateRepairCacheIOFailurePreservesDatabaseQueueAndLoserCache() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("CMVDuplicateRepairCacheIO-\(UUID().uuidString)", isDirectory: true)
        let sourceRoot = root.appendingPathComponent("Source", isDirectory: true)
        let sourceURL = sourceRoot.appendingPathComponent("duplicate.caf")
        let pinnedRoot = root.appendingPathComponent("Pinned", isDirectory: true)
        let smartRoot = root.appendingPathComponent("Smart", isDirectory: true)
        let snapshotURL = root.appendingPathComponent("queue.json")
        let manifestURL = smartRoot.appendingPathComponent("manifest.json")
        defer { try? fileManager.removeItem(at: root) }
        try fileManager.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        try Data("duplicate media".utf8).write(to: sourceURL)

        let sourceID = UUID()
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        try await repository.applyReconciliation(upserts: [
            ScannedMediaFile(relativePath: "duplicate.caf", fileIdentifier: "nas-old",
                             fileSize: 15, modifiedAt: .now, title: "Old", mediaKind: .audio),
            ScannedMediaFile(relativePath: "duplicate.caf", fileIdentifier: "nas-new",
                             fileSize: 15, modifiedAt: .now, title: "New", mediaKind: .audio)
        ], missingIdentifiers: [], sourceID: sourceID)
        let plan = try await repository.prepareDuplicateTrackRepair(sourceIDs: [sourceID])
        let loser = try XCTUnwrap(plan.replacements.keys.first)
        let keeper = try XCTUnwrap(plan.replacements[loser])

        let cache = try FileOfflineCacheStore(pinnedRoot: pinnedRoot, smartRoot: smartRoot)
        let loserCacheURL = try await cache.prefetch(trackID: loser, sourceURL: sourceURL)
        XCTAssertTrue(fileManager.fileExists(atPath: loserCacheURL.path))

        let snapshotStore = PlaybackQueueSnapshotStore(url: snapshotURL)
        try await snapshotStore.save(PlaybackQueueSnapshot(
            revision: 1,
            entries: [PlaybackQueueOccurrence(trackID: loser)]
        ))

        // Keep this repair gate isolated to the dedicated test host and restore
        // the one standard-default key when the test exits.
        let repairDefaultsKey = "CMV.duplicatePathRepairVersion"
        let defaults = UserDefaults.standard
        let previousRepairVersion = defaults.object(forKey: repairDefaultsKey)
        defaults.set(0, forKey: repairDefaultsKey)
        defer {
            if let previousRepairVersion {
                defaults.set(previousRepairVersion, forKey: repairDefaultsKey)
            } else {
                defaults.removeObject(forKey: repairDefaultsKey)
            }
        }

        // The destination collision is real filesystem state. The manifest
        // directory makes the later durable cache write fail with an I/O error.
        let keeperDestination = smartRoot
            .appendingPathComponent("\(keeper.uuidString).caf", isDirectory: true)
        try fileManager.createDirectory(at: keeperDestination, withIntermediateDirectories: false)
        try fileManager.removeItem(at: manifestURL)
        try fileManager.createDirectory(at: manifestURL, withIntermediateDirectories: false)

        let model = AppModel(
            queueSnapshotStore: snapshotStore,
            offlineCacheStore: cache
        )
        let context = ModelContext(container)
        await model.refreshSourceStatuses([], context: context)

        let recordsAfterFailure = try await repository.tracks(sourceID: sourceID)
        XCTAssertEqual(Set(recordsAfterFailure.map(\.id)), Set([loser, keeper]))
        let snapshotAfterFailure = await snapshotStore.load()
        XCTAssertEqual(snapshotAfterFailure?.entries.map(\.trackID), [loser])
        let loserAfterFailure = await cache.cachedURL(trackID: loser)
        XCTAssertEqual(loserAfterFailure?.standardizedFileURL, loserCacheURL.standardizedFileURL)
        XCTAssertTrue(fileManager.fileExists(atPath: loserCacheURL.path))
        let expectedErrorPrefix = String(format: AppLanguage.localized("無法整理重複曲目：%@"), "")
        XCTAssertTrue(model.errorMessage?.hasPrefix(expectedErrorPrefix) == true)

        // Once the real cache fault is removed, the same public caller can
        // retry and complete the prepared repair.
        try fileManager.removeItem(at: manifestURL)
        await model.refreshSourceStatuses([], context: context)

        let recordsAfterRetry = try await repository.tracks(sourceID: sourceID)
        XCTAssertEqual(recordsAfterRetry.map(\.id), [keeper])
        let snapshotAfterRetry = await snapshotStore.load()
        XCTAssertEqual(snapshotAfterRetry?.entries.map(\.trackID), [keeper])
    }
}
#endif
