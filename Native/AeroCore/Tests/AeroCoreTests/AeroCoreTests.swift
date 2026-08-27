import XCTest
import SwiftData
import AeroDomain
import AeroAnalysis
import AeroLibrary
import AeroCache

final class AeroCoreTests: XCTestCase {
    func testQueueClampsIndex() {
        let track = Track(sourceID: UUID(), relativePath: "a.flac", fileIdentifier: "a", title: "A", fileSize: 1, modifiedAt: .now)
        XCTAssertEqual(PlaybackQueue(tracks: [track], currentIndex: 99).current?.id, track.id)
    }

    func testSmartDJIsExplainableAndPenalizesSkips() async {
        let source = UUID()
        let favorite = Track(sourceID: source, relativePath: "favorite.flac", fileIdentifier: "1", title: "Favorite", fileSize: 1, modifiedAt: .now, isFavorite: true, rating: 5)
        let skipped = Track(sourceID: source, relativePath: "skipped.flac", fileIdentifier: "2", title: "Skipped", fileSize: 1, modifiedAt: .now)
        let results = await LocalSmartDJService().makeQueue(from: [skipped, favorite], profiles: [:], history: [skipped.id: ListeningSignal(skipCount: 10)], limit: 2)
        XCTAssertEqual(results.first?.track.id, favorite.id)
        XCTAssertFalse(results.first?.reasons.isEmpty ?? true)
    }

    func testAudioMetadataParserHonorsExplicitReplayGainTags() {
        XCTAssertEqual(
            AudioMetadataParser.replayGainDB(from: ["comment=not gain", "REPLAYGAIN_TRACK_GAIN=-7.20 dB"]),
            -7.2
        )
        let r128Gain = try! XCTUnwrap(AudioMetadataParser.replayGainDB(from: ["R128_TRACK_GAIN=-1792"]))
        XCTAssertEqual(r128Gain, -7, accuracy: 0.001)
        XCTAssertNil(AudioMetadataParser.replayGainDB(from: ["artist=REPLAYGAIN_TRACK_GAIN=-7 dB"]))
        XCTAssertEqual(AudioMetadataParser.integerTag(from: "id3.trackNumber", value: "03/12"), 3)
    }

    func testBatchedScanPreservesStableRecordsAndMarksOnlyUnseenTracksMissing() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MediaSourceRecord.self,
            TrackRecord.self,
            configurations: configuration
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let files = (0..<1_000).map { index in
            ScannedMediaFile(
                relativePath: "Album/\(index).flac",
                fileIdentifier: "file-\(index)",
                fileSize: Int64(index + 1),
                modifiedAt: Date(timeIntervalSince1970: TimeInterval(index)),
                title: "Track \(index)"
            )
        }

        let firstScanID = await repository.beginScan(sourceID: sourceID)
        for start in stride(from: 0, to: files.count, by: 250) {
            try await repository.applyScanBatch(
                Array(files[start..<min(start + 250, files.count)]),
                sourceID: sourceID,
                scanID: firstScanID
            )
        }
        try await repository.finishScan(sourceID: sourceID, scanID: firstScanID, sourceWasReachable: true)

        let imported = try await repository.tracks(matching: "", limit: 1_100, offset: 0)
        XCTAssertEqual(imported.count, 1_000)
        XCTAssertTrue(imported.allSatisfy { $0.availability == .available })

        let secondScanID = await repository.beginScan(sourceID: sourceID)
        try await repository.applyScanBatch(Array(files.prefix(500)), sourceID: sourceID, scanID: secondScanID)
        try await repository.finishScan(sourceID: sourceID, scanID: secondScanID, sourceWasReachable: true)

        let rescanned = try await repository.tracks(matching: "", limit: 1_100, offset: 0)
        XCTAssertEqual(rescanned.filter { $0.availability == .available }.count, 500)
        XCTAssertEqual(rescanned.filter { $0.availability == .missing }.count, 500)
    }

    func testSwiftRepositoryMatchesSharedRustReconciliationFixture() async throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AeroCoreRS/tests/fixtures/reconciliation.tsv")
        let fixture = try String(contentsOf: fixtureURL, encoding: .utf8)
        let rows = fixture.split(separator: "\n").filter { !$0.starts(with: "#") }.map {
            $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        }
        XCTAssertTrue(rows.allSatisfy { $0.count == 7 })

        func mediaFile(from row: [String]) -> ScannedMediaFile {
            ScannedMediaFile(
                relativePath: row[2],
                fileIdentifier: row[1],
                fileSize: Int64(row[3])!,
                modifiedAt: Date(timeIntervalSince1970: Double(row[4])! / 1_000),
                title: row[5]
            )
        }

        let existingRows = rows.filter { $0[0] == "existing" }
        let scannedRows = rows.filter { $0[0] == "scanned" }
        let expected = rows
            .filter { $0[0] == "expected" }
            .map { "\($0[1]):\($0[6])" }
            .sorted()

        let container = try ModelContainer(
            for: MediaSourceRecord.self,
            TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()

        let seedID = await repository.beginScan(sourceID: sourceID)
        try await repository.applyScanBatch(existingRows.map(mediaFile), sourceID: sourceID, scanID: seedID)
        try await repository.finishScan(sourceID: sourceID, scanID: seedID, sourceWasReachable: true)

        let preconditionID = await repository.beginScan(sourceID: sourceID)
        try await repository.applyScanBatch(
            existingRows.filter { $0[1] != "c" }.map(mediaFile),
            sourceID: sourceID,
            scanID: preconditionID
        )
        try await repository.finishScan(sourceID: sourceID, scanID: preconditionID, sourceWasReachable: true)

        let fixtureScanID = await repository.beginScan(sourceID: sourceID)
        try await repository.applyScanBatch(scannedRows.map(mediaFile), sourceID: sourceID, scanID: fixtureScanID)
        try await repository.finishScan(sourceID: sourceID, scanID: fixtureScanID, sourceWasReachable: true)

        let originalIdentifiers = Set(existingRows.map { $0[1] })
        let actual = try await repository.tracks(matching: "", limit: 100, offset: 0)
            .map { track in
                if track.availability == .missing { return "\(track.fileIdentifier):missing" }
                return "\(track.fileIdentifier):\(originalIdentifiers.contains(track.fileIdentifier) ? "update" : "insert")"
            }
            .sorted()
        XCTAssertEqual(actual, expected)
    }

    func testFiftyThousandTrackReconciliationPersistsInBatches() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self,
            TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let files = (0..<50_000).map { index in
            ScannedMediaFile(
                relativePath: "Library/track-\(index).flac",
                fileIdentifier: "track-\(index)",
                fileSize: Int64(index + 1),
                modifiedAt: Date(timeIntervalSince1970: TimeInterval(index)),
                title: "Track \(index)"
            )
        }

        try await repository.applyReconciliation(
            upserts: files,
            missingIdentifiers: [],
            sourceID: sourceID
        )
        try await repository.applyReconciliation(
            upserts: [],
            missingIdentifiers: (49_000..<50_000).map { "track-\($0)" },
            sourceID: sourceID
        )

        let tracks = try await repository.tracks(sourceID: sourceID)
        XCTAssertEqual(tracks.count, 50_000)
        XCTAssertEqual(tracks.filter { $0.availability == .available }.count, 49_000)
        XCTAssertEqual(tracks.filter { $0.availability == .missing }.count, 1_000)

        _ = try await repository.tracks(matching: "Track 49999", limit: 20, offset: 0)
        let searchStart = ContinuousClock.now
        let result = try await repository.tracks(matching: "Track 49999", limit: 20, offset: 0)
        let searchElapsed = searchStart.duration(to: .now)
        XCTAssertEqual(result.first?.title, "Track 49999")
        XCTAssertLessThan(searchElapsed, .milliseconds(150))
    }

    func testMetadataFieldsSurviveReconciliation() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self,
            TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let file = ScannedMediaFile(
            relativePath: "Albums/Dream/song.flac", fileIdentifier: "metadata-song",
            fileSize: 1024, modifiedAt: .now, title: "夢境", artist: "星塵",
            album: "雲海", albumArtist: "星塵合奏", artworkData: Data([0xFF, 0xD8, 0xFF]),
            duration: 241.5, replayGainDB: -7.2
        )
        try await repository.applyReconciliation(upserts: [file], missingIdentifiers: [], sourceID: sourceID)
        let track = try await repository.tracks(sourceID: sourceID).first
        XCTAssertEqual(track?.title, "夢境")
        XCTAssertEqual(track?.artist, "星塵")
        XCTAssertEqual(track?.album, "雲海")
        XCTAssertEqual(track?.albumArtist, "星塵合奏")
        XCTAssertEqual(track?.duration, 241.5)
        XCTAssertEqual(track?.replayGainDB, -7.2)
        XCTAssertEqual(track?.artworkData, Data([0xFF, 0xD8, 0xFF]))

        let refreshed = ScannedMediaFile(
            relativePath: file.relativePath, fileIdentifier: file.fileIdentifier,
            fileSize: 2048, modifiedAt: .now, title: "夢境（重製版）", artist: file.artist,
            album: file.album, albumArtist: file.albumArtist, artworkData: Data([0x89, 0x50, 0x4E, 0x47]),
            duration: file.duration, replayGainDB: file.replayGainDB
        )
        try await repository.applyReconciliation(upserts: [refreshed], missingIdentifiers: [], sourceID: sourceID)
        let updatedTrack = try await repository.tracks(sourceID: sourceID).first
        XCTAssertEqual(updatedTrack?.title, "夢境（重製版）")
        XCTAssertEqual(updatedTrack?.artworkData, Data([0x89, 0x50, 0x4E, 0x47]))
    }

    func testSearchSnapshotReflectsTrackMutations() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        try await repository.applyReconciliation(
            upserts: [ScannedMediaFile(relativePath: "song.flac", fileIdentifier: "song",
                                       fileSize: 1, modifiedAt: .now, title: "星河")],
            missingIdentifiers: [], sourceID: sourceID
        )
        let imported = try await repository.tracks(sourceID: sourceID)
        let track = try XCTUnwrap(imported.first)

        try await repository.setFavorite(trackID: track.id, isFavorite: true)
        try await repository.setRating(trackID: track.id, rating: 5)
        try await repository.recordPlayback(trackID: track.id, skipped: false)
        try await repository.setAnalysis(
            trackID: track.id,
            profile: AnalysisProfile(version: 2, bpm: 96, musicalKey: "C", integratedLoudnessLUFS: -23,
                                     energy: 0.8, brightness: 0.4)
        )

        let result = try await repository.tracks(matching: "星河", limit: 1, offset: 0)
        XCTAssertEqual(result.first?.id, track.id)
        XCTAssertEqual(result.first?.isFavorite, true)
        XCTAssertEqual(result.first?.rating, 5)
    }

    func testLibraryOperationsPersistFavoritesRatingsHistoryAndPlaylists() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let file = ScannedMediaFile(relativePath: "song.flac", fileIdentifier: "song",
                                    fileSize: 1, modifiedAt: .now, title: "星河")
        try await repository.applyReconciliation(upserts: [file], missingIdentifiers: [], sourceID: sourceID)
        let imported = try await repository.tracks(sourceID: sourceID)
        let track = try XCTUnwrap(imported.first)

        try await repository.setFavorite(trackID: track.id, isFavorite: true)
        try await repository.setRating(trackID: track.id, rating: 7)
        try await repository.setAnalysis(trackID: track.id, profile: AnalysisProfile(
            version: 1, bpm: 120, musicalKey: "C", integratedLoudnessLUFS: -23,
            energy: 0.8, brightness: 0.4
        ))
        try await repository.recordPlayback(trackID: track.id, skipped: false)
        let favorite = try await repository.favoriteTracks(limit: 20, offset: 0)
        XCTAssertEqual(favorite.first?.id, track.id)
        XCTAssertEqual(favorite.first?.rating, 5)
        XCTAssertEqual(favorite.first?.analysis?.bpm, 120)
        XCTAssertEqual(favorite.first?.analysis?.musicalKey, "C")

        let playlist = try await repository.createPlaylist(name: "夜航")
        try await repository.addTrack(trackID: track.id, toPlaylist: playlist.id)
        try await repository.addTrack(trackID: track.id, toPlaylist: playlist.id)
        let persisted = try await repository.playlists()
        XCTAssertEqual(persisted.first?.name, "夜航")
        XCTAssertEqual(persisted.first?.trackIDs, [track.id])
        try await repository.renamePlaylist(id: playlist.id, name: "夜航收藏")
        let renamed = try await repository.playlists()
        XCTAssertEqual(renamed.first?.name, "夜航收藏")
        try await repository.deletePlaylist(id: playlist.id)
        let afterDelete = try await repository.playlists()
        XCTAssertTrue(afterDelete.isEmpty)
    }

    func testOfflineCacheVerifiesContentAndNeverTrimsPinnedMedia() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID().uuidString).bin")
        try Data(repeating: 7, count: 32).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let store = try FileOfflineCacheStore()
        let pinnedID = UUID()
        let smartID = UUID()
        let pinnedURL = try await store.pin(trackID: pinnedID, sourceURL: source)
        let pinnedBeforeTrim = await store.isPinned(trackID: pinnedID)
        XCTAssertTrue(pinnedBeforeTrim)
        let smartURL = try await store.prefetch(trackID: smartID, sourceURL: source)
        let resolvedPinnedURL = await store.cachedURL(trackID: pinnedID)
        let resolvedSmartURL = await store.cachedURL(trackID: smartID)
        XCTAssertEqual(resolvedPinnedURL, pinnedURL)
        XCTAssertEqual(resolvedSmartURL, smartURL)
        let pinnedVerified = await store.verify(trackID: pinnedID)
        let smartVerified = await store.verify(trackID: smartID)
        XCTAssertTrue(pinnedVerified)
        XCTAssertTrue(smartVerified)
        try await store.trim(to: 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pinnedURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: smartURL.path))
        let missingSmartURL = await store.cachedURL(trackID: smartID)
        XCTAssertNil(missingSmartURL)
        try await store.unpin(trackID: pinnedID)
        let pinnedAfterUnpin = await store.isPinned(trackID: pinnedID)
        XCTAssertFalse(pinnedAfterUnpin)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pinnedURL.path))
    }

    func testCorruptedOfflineMediaIsRejectedBeforePlayback() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("cache-corrupt-\(UUID().uuidString).bin")
        try Data(repeating: 3, count: 64).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let store = try FileOfflineCacheStore()
        let trackID = UUID()
        let cachedURL = try await store.pin(trackID: trackID, sourceURL: source)
        try Data(repeating: 9, count: 64).write(to: cachedURL, options: .atomic)

        let resolvedURL = await store.cachedURL(trackID: trackID)
        let verified = await store.verify(trackID: trackID)
        XCTAssertNil(resolvedURL)
        XCTAssertFalse(verified)
        try await store.unpin(trackID: trackID)
    }

    func testUnreachableSourceDoesNotClearExistingLibrary() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self,
            TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let file = ScannedMediaFile(
            relativePath: "Album/kept.flac",
            fileIdentifier: "kept",
            fileSize: 1,
            modifiedAt: .now,
            title: "Kept"
        )
        try await repository.applyScan([file], sourceID: sourceID, sourceWasReachable: true)
        try await repository.applyScan([], sourceID: sourceID, sourceWasReachable: false)

        let tracks = try await repository.tracks(sourceID: sourceID)
        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks.first?.availability, .available)
    }

    func testCancelledScannerStopsBeforePublishingBatch() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AeroScanner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data([0]).write(to: directory.appendingPathComponent("track.mp3"))
        let scanner = IncrementalScanner()
        let task = Task {
            try await scanner.scan(
                url: directory,
                accessAlreadyGranted: true,
                onBatch: { _ in XCTFail("取消後不得發布批次") },
                onProgress: { _ in }
            )
        }
        task.cancel()
        do {
            try await task.value
            XCTFail("取消掃描應拋出 CancellationError")
        } catch is CancellationError {
            // Expected.
        }
    }

    func testMediaSourceSurvivesPersistentStoreReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AeroStore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Library.store")
        let sourceID = UUID()

        do {
            let container = try ModelContainer(
                for: MediaSourceRecord.self,
                TrackRecord.self,
                configurations: ModelConfiguration(url: storeURL)
            )
            let context = ModelContext(container)
            context.insert(MediaSourceRecord(
                id: sourceID,
                displayName: "NAS Music",
                bookmarkData: Data([1, 2, 3]),
                status: .available
            ))
            try context.save()
        }

        let reopened = try ModelContainer(
            for: MediaSourceRecord.self,
            TrackRecord.self,
            configurations: ModelConfiguration(url: storeURL)
        )
        let records = try ModelContext(reopened).fetch(FetchDescriptor<MediaSourceRecord>())
        XCTAssertEqual(records.map(\.id), [sourceID])
        XCTAssertEqual(records.first?.displayName, "NAS Music")
        XCTAssertEqual(records.first?.bookmarkData, Data([1, 2, 3]))
    }
}
