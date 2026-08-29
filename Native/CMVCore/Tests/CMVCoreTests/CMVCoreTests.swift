import XCTest
import SwiftData
import CMVDomain
import CMVAnalysis
import CMVLibrary
import CMVCache

final class CMVCoreTests: XCTestCase {
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
            .appendingPathComponent("CMVCoreRS/tests/fixtures/reconciliation.tsv")
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

    func testLibrarySortingIsStableAcrossPagesAndSearch() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let files = [
            ScannedMediaFile(relativePath: "b-2.flac", fileIdentifier: "b-2", fileSize: 1,
                             modifiedAt: Date(timeIntervalSince1970: 30), title: "第二首", artist: "乙",
                             album: "星河", albumArtist: "乙", trackNumber: 2, discNumber: 1),
            ScannedMediaFile(relativePath: "a.flac", fileIdentifier: "a", fileSize: 1,
                             modifiedAt: Date(timeIntervalSince1970: 10), title: "晨光", artist: "甲",
                             album: "雲海", albumArtist: "甲", trackNumber: 1, discNumber: 1),
            ScannedMediaFile(relativePath: "b-1.flac", fileIdentifier: "b-1", fileSize: 1,
                             modifiedAt: Date(timeIntervalSince1970: 20), title: "第一首", artist: "乙",
                             album: "星河", albumArtist: "乙", trackNumber: 1, discNumber: 1)
        ]
        try await repository.applyReconciliation(upserts: files, missingIdentifiers: [], sourceID: sourceID)

        let albumFirstPage = try await repository.tracks(
            matching: "", sort: .album, ascending: true, limit: 2, offset: 0
        )
        let albumSecondPage = try await repository.tracks(
            matching: "", sort: .album, ascending: true, limit: 2, offset: 2
        )
        XCTAssertEqual((albumFirstPage + albumSecondPage).map(\.fileIdentifier), ["b-1", "b-2", "a"])

        let newestFirst = try await repository.trackIDs(matching: "", sort: .modifiedAt, ascending: false)
        let newestTracks = try await repository.tracks(ids: newestFirst)
        XCTAssertEqual(newestTracks.map(\.fileIdentifier), ["b-2", "b-1", "a"])

        let searched = try await repository.trackIDs(matching: "星河", sort: .title, ascending: true)
        let searchedTracks = try await repository.tracks(ids: searched)
        XCTAssertEqual(searchedTracks.map(\.title), ["第一首", "第二首"])

        let identicalTimestamp = Date(timeIntervalSince1970: 40)
        let identical = (0..<3).map { index in
            ScannedMediaFile(
                relativePath: "identical-\(index).flac", fileIdentifier: "identical-\(index)", fileSize: 1,
                modifiedAt: identicalTimestamp, title: "同名", artist: "同人", album: "同輯",
                albumArtist: "同人", trackNumber: 1, discNumber: 1
            )
        }
        try await repository.applyReconciliation(upserts: files + identical, missingIdentifiers: [], sourceID: sourceID)
        let identicalIDs = try await repository.trackIDs(matching: "同名", sort: .album, ascending: true)
        var pagedIDs: [UUID] = []
        for offset in identicalIDs.indices {
            let page = try await repository.tracks(
                matching: "同名", sort: .album, ascending: true, limit: 1, offset: offset
            )
            if let id = page.first?.id { pagedIDs.append(id) }
        }
        XCTAssertEqual(pagedIDs, identicalIDs)
        XCTAssertEqual(Set(pagedIDs).count, identical.count)
    }

    func testMediaKindSurvivesReconciliationAndLegacyDefaultsToAudio() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let video = ScannedMediaFile(
            relativePath: "Concert/星河.mov", fileIdentifier: "video",
            fileSize: 2, modifiedAt: .now, title: "星河現場", mediaKind: .video
        )
        try await repository.applyReconciliation(upserts: [video], missingIdentifiers: [], sourceID: sourceID)
        let imported = try await repository.tracks(sourceID: sourceID)
        XCTAssertEqual(imported.first?.mediaKind, .video)

        let legacy = TrackRecord(
            sourceID: sourceID,
            file: ScannedMediaFile(relativePath: "legacy.flac", fileIdentifier: "legacy",
                                   fileSize: 1, modifiedAt: .now, title: "舊曲目")
        )
        XCTAssertEqual(legacy.domain.mediaKind, .audio)
    }

    func testExcludedTracksStayHiddenAfterRescanAndLeavePlaylists() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let files = [
            ScannedMediaFile(relativePath: "keep.flac", fileIdentifier: "keep", fileSize: 1,
                             modifiedAt: .now, title: "保留"),
            ScannedMediaFile(relativePath: "remove.flac", fileIdentifier: "remove", fileSize: 1,
                             modifiedAt: .now, title: "移出")
        ]
        try await repository.applyReconciliation(upserts: files, missingIdentifiers: [], sourceID: sourceID)
        let imported = try await repository.tracks(matching: "", limit: 10, offset: 0)
        let removed = try XCTUnwrap(imported.first(where: { $0.fileIdentifier == "remove" }))
        let playlist = try await repository.createPlaylist(name: "測試")
        let kept = try XCTUnwrap(imported.first(where: { $0.fileIdentifier == "keep" }))
        try await repository.addTracks(trackIDs: [removed.id, kept.id, removed.id], toPlaylist: playlist.id)
        let playlistAfterBatchAdd = try await repository.playlists()
        XCTAssertEqual(playlistAfterBatchAdd.first?.trackIDs, [removed.id, kept.id])

        try await repository.excludeTracks(ids: [removed.id])
        let visibleIDs = try await repository.trackIDs(matching: "")
        let playlistsAfterRemoval = try await repository.playlists()
        XCTAssertEqual(visibleIDs, [kept.id])
        XCTAssertEqual(playlistsAfterRemoval.first?.trackIDs, [kept.id])

        try await repository.applyReconciliation(upserts: files, missingIdentifiers: [], sourceID: sourceID)
        let rescanned = try await repository.tracks(matching: "", limit: 10, offset: 0)
        let matchingRemoved = try await repository.trackIDs(matching: "移出")
        let sourceTracks = try await repository.tracks(sourceID: sourceID)
        XCTAssertEqual(rescanned.map(\.fileIdentifier), ["keep"])
        XCTAssertTrue(matchingRemoved.isEmpty)
        XCTAssertEqual(sourceTracks.count, 2)

        try await repository.restoreTracks(
            ids: [removed.id],
            playlistTrackIDs: [playlist.id: [removed.id, kept.id]]
        )
        let restored = try await repository.trackIDs(matching: "移出")
        let playlistsAfterRestore = try await repository.playlists()
        XCTAssertEqual(restored, [removed.id])
        XCTAssertEqual(playlistsAfterRestore.first?.trackIDs, [removed.id, kept.id])
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

    func testIncompleteReachableScanPreservesTracksWhoseMetadataFailed() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self,
            TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let existing = ScannedMediaFile(
            relativePath: "Album/damaged-on-rescan.mp4",
            fileIdentifier: "damaged-on-rescan",
            fileSize: 10,
            modifiedAt: .now,
            title: "Keep Existing"
        )
        try await repository.applyScan([existing], sourceID: sourceID, sourceWasReachable: true)

        let incompleteScanID = await repository.beginScan(sourceID: sourceID)
        let readableSibling = ScannedMediaFile(
            relativePath: "Album/new.m4a",
            fileIdentifier: "new",
            fileSize: 20,
            modifiedAt: .now,
            title: "New"
        )
        try await repository.applyScanBatch([readableSibling], sourceID: sourceID, scanID: incompleteScanID)
        try await repository.finishScan(
            sourceID: sourceID,
            scanID: incompleteScanID,
            sourceWasReachable: false
        )

        let tracks = try await repository.tracks(sourceID: sourceID)
        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(
            tracks.first(where: { $0.fileIdentifier == "damaged-on-rescan" })?.availability,
            .available
        )
    }

    func testCancelledScannerStopsBeforePublishingBatch() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVScanner-\(UUID().uuidString)", isDirectory: true)
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
            .appendingPathComponent("CMVStore-\(UUID().uuidString)", isDirectory: true)
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
