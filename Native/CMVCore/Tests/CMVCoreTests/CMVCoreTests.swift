import XCTest
import SwiftData
import AVFoundation
import CMVDomain
import CMVAnalysis
import CMVLibrary
@testable import CMVCache

private final class CopyGate: @unchecked Sendable {
    private let lock = NSLock()
    private var blocksNextCopy = false
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)

    func arm() {
        lock.lock()
        blocksNextCopy = true
        lock.unlock()
    }

    func takeBlock() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard blocksNextCopy else { return false }
        blocksNextCopy = false
        return true
    }
}

private final class GatedFileManager: FileManager {
    let gate: CopyGate

    init(gate: CopyGate) {
        self.gate = gate
        super.init()
    }

    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        if gate.takeBlock() {
            gate.entered.signal()
            gate.release.wait()
        }
        try super.copyItem(at: srcURL, to: dstURL)
    }
}

final class CMVCoreTests: XCTestCase {
    func testQueueClampsIndex() {
        let track = Track(sourceID: UUID(), relativePath: "a.flac", fileIdentifier: "a", title: "A", fileSize: 1, modifiedAt: .now)
        XCTAssertEqual(PlaybackQueue(tracks: [track], currentIndex: 99).current?.id, track.id)
    }

    func testPlaybackRoutePositionPreservesRepeatedOccurrences() {
        let audio = UUID()
        let video = UUID()
        XCTAssertEqual(
            PlaybackRoutePosition.resolve(
                routeIDs: [audio, audio, video], currentID: audio, preferredIndex: 1
            ),
            1
        )
        XCTAssertEqual(
            PlaybackRoutePosition.resolve(
                routeIDs: [audio, video, audio, video], currentID: audio, preferredIndex: 2
            ),
            2
        )
        XCTAssertEqual(
            PlaybackRoutePosition.resolve(
                routeIDs: [audio, video], currentID: audio, preferredIndex: nil
            ),
            0
        )
        XCTAssertNil(
            PlaybackRoutePosition.resolve(
                routeIDs: [audio, video], currentID: nil, preferredIndex: nil
            )
        )
    }

    func testSmartDJIsExplainableAndPenalizesSkips() async throws {
        let source = UUID()
        let favorite = Track(sourceID: source, relativePath: "favorite.flac", fileIdentifier: "1", title: "Favorite", fileSize: 1, modifiedAt: .now, isFavorite: true, rating: 5)
        let skipped = Track(sourceID: source, relativePath: "skipped.flac", fileIdentifier: "2", title: "Skipped", fileSize: 1, modifiedAt: .now)
        let results = try await LocalSmartDJService().makeQueue(from: [skipped, favorite], profiles: [:], history: [skipped.id: ListeningSignal(skipCount: 10)], limit: 2)
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

    func testAnalyzerCancellationMarkerOnlyAppliesToInFlightAnalysis() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVAnalyzer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let audioURL = directory.appendingPathComponent("silence.wav")

        var wave = Data("RIFF".utf8)
        func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { wave.append(contentsOf: $0) }
        }
        appendLittleEndian(UInt32(38))
        wave.append(contentsOf: Data("WAVEfmt ".utf8))
        appendLittleEndian(UInt32(16))
        appendLittleEndian(UInt16(1))
        appendLittleEndian(UInt16(1))
        appendLittleEndian(UInt32(44_100))
        appendLittleEndian(UInt32(88_200))
        appendLittleEndian(UInt16(2))
        appendLittleEndian(UInt16(16))
        wave.append(contentsOf: Data("data".utf8))
        appendLittleEndian(UInt32(2))
        appendLittleEndian(Int16(0))
        try wave.write(to: audioURL)

        let analyzer = LocalAudioAnalyzer()
        let trackID = UUID()
        await analyzer.cancel(trackID: trackID)
        _ = try await analyzer.analyze(trackID: trackID, url: audioURL)
        await analyzer.cancel(trackID: trackID)
        _ = try await analyzer.analyze(trackID: trackID, url: audioURL)
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

    func testInvalidatedScanCannotWriteOldBatchesOrFinalizeMissingTracks() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let oldScanID = await repository.beginScan(sourceID: sourceID)
        let file = ScannedMediaFile(
            relativePath: "track.flac", fileIdentifier: "track", fileSize: 1,
            modifiedAt: .now, title: "Track"
        )
        await repository.invalidateScan(sourceID: sourceID)

        do {
            try await repository.applyScanBatch([file], sourceID: sourceID, scanID: oldScanID)
            XCTFail("An invalidated scan must not write its late batch")
        } catch is CancellationError {}
        do {
            try await repository.applyReconciliation(
                upserts: [], missingIdentifiers: ["track"], sourceID: sourceID, scanID: oldScanID
            )
            XCTFail("An invalidated scan must not finalize missing tracks")
        } catch is CancellationError {}
        do {
            try await repository.finishScan(sourceID: sourceID, scanID: oldScanID, sourceWasReachable: true)
            XCTFail("An invalidated scan must not finish")
        } catch is CancellationError {}
        let beforeNewScan = try await repository.tracks(matching: "", limit: 10, offset: 0)
        XCTAssertTrue(beforeNewScan.isEmpty)

        let newScanID = await repository.beginScan(sourceID: sourceID)
        try await repository.applyScanBatch([file], sourceID: sourceID, scanID: newScanID)
        let afterNewScan = try await repository.tracks(matching: "", limit: 10, offset: 0)
        XCTAssertEqual(afterNewScan.count, 1)
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

        var pagedIDs = Set<UUID>()
        var offset = 0
        while true {
            let page = try await repository.tracks(
                matching: "",
                sort: .title,
                ascending: true,
                limit: 200,
                offset: offset
            )
            guard !page.isEmpty else { break }
            XCTAssertLessThanOrEqual(page.count, 200)
            for track in page {
                XCTAssertTrue(pagedIDs.insert(track.id).inserted, "跨頁載入不應重複歌曲")
            }
            offset += page.count
        }
        XCTAssertEqual(offset, 50_000)
        XCTAssertEqual(pagedIDs.count, 50_000)

        _ = try await repository.tracks(matching: "Track 49999", limit: 20, offset: 0)
        let searchStart = ContinuousClock.now
        let result = try await repository.tracks(matching: "Track 49999", limit: 20, offset: 0)
        let searchElapsed = searchStart.duration(to: .now)
        XCTAssertEqual(result.first?.title, "Track 49999")
        XCTAssertLessThan(searchElapsed, .milliseconds(150))
    }

    func testDeepPageOrderCacheInvalidatesAfterMetadataChange() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let files = (0..<2_050).map { index in
            ScannedMediaFile(
                relativePath: "track-\(index).flac", fileIdentifier: "track-\(index)",
                fileSize: 1, modifiedAt: .now,
                title: String(format: "Track %04d", index)
            )
        }
        try await repository.applyReconciliation(upserts: files, missingIdentifiers: [], sourceID: sourceID)
        let originalPage = try await repository.tracks(
            matching: "", sort: .title, ascending: true, limit: 100, offset: 2_000
        )
        XCTAssertEqual(originalPage.first?.title, "Track 2000")
        XCTAssertEqual(originalPage.last?.title, "Track 2049")

        var renamed = files[2_049]
        renamed.title = "Track -1"
        try await repository.applyReconciliation(upserts: [renamed], missingIdentifiers: [], sourceID: sourceID)
        let refreshedPage = try await repository.tracks(
            matching: "", sort: .title, ascending: true, limit: 100, offset: 2_000
        )
        XCTAssertEqual(refreshedPage.first?.title, "Track 1999")
        XCTAssertEqual(refreshedPage.last?.title, "Track 2048")
    }

    func testNASRemountDuplicateRepairPreservesUserMetadataAndPlaylistIdentity() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let oldFile = ScannedMediaFile(
            relativePath: "Albums/Moon/song.flac", fileIdentifier: "old-volume-id",
            fileSize: 100, modifiedAt: Date(timeIntervalSince1970: 100), title: "舊標題"
        )
        let remountedFile = ScannedMediaFile(
            relativePath: "Albums/Moon/song.flac", fileIdentifier: "new-volume-id",
            fileSize: 120, modifiedAt: Date(timeIntervalSince1970: 200), title: "月光"
        )
        try await repository.applyReconciliation(
            upserts: [oldFile, remountedFile], missingIdentifiers: [], sourceID: sourceID
        )
        let imported = try await repository.tracks(sourceID: sourceID)
        let oldTrack = try XCTUnwrap(imported.first { $0.fileIdentifier == "old-volume-id" })
        let newTrack = try XCTUnwrap(imported.first { $0.fileIdentifier == "new-volume-id" })
        try await repository.setFavorite(trackID: oldTrack.id, isFavorite: true)
        try await repository.setRating(trackID: oldTrack.id, rating: 4)
        try await repository.recordPlayback(trackID: oldTrack.id, skipped: false)
        try await repository.updateMetadata(for: [oldTrack.id],
                                            with: TrackMetadataPatch(title: .set("手動月光")))
        let playlist = try await repository.createPlaylist(name: "保留身份")
        try await repository.addTracks(trackIDs: [oldTrack.id, newTrack.id], toPlaylist: playlist.id)
        try await repository.applyReconciliation(
            upserts: [], missingIdentifiers: ["old-volume-id"], sourceID: sourceID
        )

        let repairedCount = try await repository.repairDuplicateTracksByRelativePath(sourceIDs: [])
        let repairedTracks = try await repository.tracks(sourceID: sourceID)
        let repaired = try XCTUnwrap(repairedTracks.first)
        XCTAssertEqual(repairedCount, 1)
        XCTAssertEqual(repaired.id, oldTrack.id)
        XCTAssertEqual(repaired.fileIdentifier, "new-volume-id")
        XCTAssertEqual(repaired.title, "手動月光")
        XCTAssertEqual(repaired.availability, .available)
        XCTAssertTrue(repaired.isFavorite)
        XCTAssertEqual(repaired.rating, 4)
        let repairedPlaylists = try await repository.playlists()
        XCTAssertEqual(repairedPlaylists.first?.trackIDs, [oldTrack.id])
        let secondRepairCount = try await repository.repairDuplicateTracksByRelativePath(sourceIDs: [sourceID])
        XCTAssertEqual(secondRepairCount, 0)
        try await repository.applyReconciliation(upserts: [remountedFile],
                                                 missingIdentifiers: [], sourceID: sourceID)
        let rescannedTracks = try await repository.tracks(sourceID: sourceID)
        let rescanned = try XCTUnwrap(rescannedTracks.first)
        XCTAssertEqual(rescanned.title, "手動月光")
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

    func testLibrarySortFieldsRemainBidirectionalAndPageStable() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let files = [
            ScannedMediaFile(
                relativePath: "zulu.flac", fileIdentifier: "zulu", fileSize: 1,
                modifiedAt: Date(timeIntervalSince1970: 40), title: "Catalog Zulu",
                artist: "Catalog Delta", album: "Catalog Ocean"
            ),
            ScannedMediaFile(
                relativePath: "alpha.flac", fileIdentifier: "alpha", fileSize: 1,
                modifiedAt: Date(timeIntervalSince1970: 10), title: "Catalog Alpha",
                artist: "Catalog Bravo", album: "Catalog Zebra"
            ),
            ScannedMediaFile(
                relativePath: "echo.flac", fileIdentifier: "echo", fileSize: 1,
                modifiedAt: Date(timeIntervalSince1970: 30), title: "Catalog Echo",
                artist: "Catalog Echo", album: "Catalog Forest"
            ),
            ScannedMediaFile(
                relativePath: "mike.flac", fileIdentifier: "mike", fileSize: 1,
                modifiedAt: Date(timeIntervalSince1970: 20), title: "Catalog Mike",
                artist: "Catalog Alpha", album: "Catalog Mountain"
            )
        ]
        try await repository.applyReconciliation(
            upserts: files, missingIdentifiers: [], sourceID: sourceID
        )

        let expected: [(sort: LibraryTrackSort, ascending: [String], descending: [String])] = [
            (.title, ["alpha", "echo", "mike", "zulu"], ["zulu", "mike", "echo", "alpha"]),
            (.artist, ["mike", "alpha", "zulu", "echo"], ["echo", "zulu", "alpha", "mike"]),
            (.album, ["echo", "mike", "zulu", "alpha"], ["alpha", "zulu", "mike", "echo"]),
            (.modifiedAt, ["alpha", "mike", "echo", "zulu"], ["zulu", "echo", "mike", "alpha"])
        ]

        for fixture in expected {
            let allAscending = try await repository.tracks(
                matching: "", sort: fixture.sort, ascending: true,
                limit: files.count, offset: 0
            )
            let allDescending = try await repository.tracks(
                matching: "", sort: fixture.sort, ascending: false,
                limit: files.count, offset: 0
            )
            XCTAssertEqual(allAscending.map(\.fileIdentifier), fixture.ascending)
            XCTAssertEqual(allDescending.map(\.fileIdentifier), fixture.descending)

            for (ascending, expectedIDs) in [(true, fixture.ascending), (false, fixture.descending)] {
                var pagedIDs: [UUID] = []
                for offset in stride(from: 0, to: files.count, by: 2) {
                    let page = try await repository.tracks(
                        matching: "catalog", sort: fixture.sort, ascending: ascending,
                        limit: 2, offset: offset
                    )
                    pagedIDs.append(contentsOf: page.map(\.id))
                }
                let sortedIDs = try await repository.trackIDs(
                    matching: "catalog", sort: fixture.sort, ascending: ascending
                )
                let roundTripped = try await repository.tracks(ids: sortedIDs)
                XCTAssertEqual(pagedIDs, sortedIDs)
                XCTAssertEqual(roundTripped.map(\.fileIdentifier), expectedIDs)
            }
        }
    }

    func testSearchMatchesEveryTokenAcrossDifferentMetadataFields() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        try await repository.applyReconciliation(
            upserts: [
                ScannedMediaFile(
                    relativePath: "hotel.flac", fileIdentifier: "hotel", fileSize: 1,
                    modifiedAt: .now, title: "Hotel California", artist: "Eagles", album: "Greatest Hits"
                ),
                ScannedMediaFile(
                    relativePath: "other.flac", fileIdentifier: "other", fileSize: 1,
                    modifiedAt: .now, title: "Hotel California", artist: "Other Artist", album: "Greatest Hits"
                )
            ],
            missingIdentifiers: [],
            sourceID: sourceID
        )

        let candidates = try await repository.searchCandidates(matching: "hotel eagles")
        XCTAssertEqual(candidates.map(\.id).count, 1)
        let matches = try await repository.tracks(ids: candidates.map(\.id))
        XCTAssertEqual(matches.map(\.fileIdentifier), ["hotel"])
        let reversedQueryIDs = try await repository.trackIDs(matching: "eagles hotel")
        XCTAssertEqual(reversedQueryIDs, candidates.map(\.id))
    }

    func testSearchCandidatesFoldDiacriticsWhilePreservingDisplayMetadata() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        try await repository.applyReconciliation(
            upserts: [
                ScannedMediaFile(
                    relativePath: "deja-vu.flac", fileIdentifier: "deja-vu", fileSize: 1,
                    modifiedAt: .now, title: "Canci\u{00F3}n", artist: "Beyonc\u{00E9}", album: "D\u{00E9}j\u{00E0} Vu"
                )
            ],
            missingIdentifiers: [],
            sourceID: sourceID
        )

        let candidates = try await repository.searchCandidates(matching: "beyonce deja vu")
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].title, "Canci\u{00F3}n")
        XCTAssertEqual(candidates[0].artist, "Beyonc\u{00E9}")
        XCTAssertEqual(candidates[0].album, "D\u{00E9}j\u{00E0} Vu")
    }

    func testSearchCandidatesReturnMatchesBeyondFiveHundred() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let files = (0..<501).map { index in
            ScannedMediaFile(
                relativePath: "shared-\(index).flac", fileIdentifier: "shared-\(index)",
                fileSize: 1, modifiedAt: Date(timeIntervalSince1970: TimeInterval(index)),
                title: "Shared Result \(index)"
            )
        }
        try await repository.applyReconciliation(
            upserts: files, missingIdentifiers: [], sourceID: sourceID
        )

        let candidates = try await repository.searchCandidates(matching: "shared result")
        XCTAssertEqual(candidates.count, 501)
        XCTAssertEqual(Set(candidates.map(\.id)).count, 501)
        XCTAssertTrue(candidates.contains { $0.title == "Shared Result 500" })
    }

    func testSearchReusesIndexAcrossQueriesAndNormalizesWhitespaceNoResultsAndDuplicateTokens() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        try await repository.applyReconciliation(
            upserts: [
                ScannedMediaFile(
                    relativePath: "moon.flac", fileIdentifier: "moon", fileSize: 1,
                    modifiedAt: .now, title: "Moonlight", artist: "Night Drive"
                ),
                ScannedMediaFile(
                    relativePath: "sun.flac", fileIdentifier: "sun", fileSize: 1,
                    modifiedAt: .now, title: "Sunrise", artist: "Day Drive"
                )
            ],
            missingIdentifiers: [], sourceID: sourceID
        )

        let padded = try await repository.searchCandidates(matching: "  moonlight \n")
        let otherQuery = try await repository.searchCandidates(matching: "sunrise")
        let duplicateTokens = try await repository.searchCandidates(matching: "moonlight moonlight")
        let repeated = try await repository.searchCandidates(matching: "  moonlight ")
        let noResult = try await repository.searchCandidates(matching: "does-not-exist")
        let repeatedAfterNoResult = try await repository.searchCandidates(matching: "moonlight")

        XCTAssertEqual(padded.map(\.id), duplicateTokens.map(\.id))
        XCTAssertEqual(padded.map(\.id), repeated.map(\.id))
        XCTAssertEqual(otherQuery.map(\.title), ["Sunrise"])
        XCTAssertTrue(noResult.isEmpty)
        XCTAssertEqual(repeatedAfterNoResult.map(\.id), padded.map(\.id))
    }

    func testCatalogGroupsAreCompleteSortedAndExcludeHiddenTracks() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let uniqueFiles = (0..<501).map { index in
            ScannedMediaFile(
                relativePath: "catalog-\(index).flac", fileIdentifier: "catalog-\(index)",
                fileSize: 1, modifiedAt: Date(timeIntervalSince1970: TimeInterval(index)),
                title: "Track \(String(format: "%03d", index))",
                artist: "Artist \(String(format: "%03d", index))",
                album: "Album \(String(format: "%03d", index))"
            )
        }
        let duplicate = ScannedMediaFile(
            relativePath: "catalog-first.flac", fileIdentifier: "catalog-first", fileSize: 1,
            modifiedAt: .now, title: "AAA First", artist: "Artist 000", album: "Album 000"
        )
        let sameArtist = [
            ScannedMediaFile(
                relativePath: "catalog-second.flac", fileIdentifier: "catalog-second", fileSize: 1,
                modifiedAt: .now, title: "BBB Second", artist: "Artist 000", album: "Album 000"
            ),
            ScannedMediaFile(
                relativePath: "catalog-third.flac", fileIdentifier: "catalog-third", fileSize: 1,
                modifiedAt: .now, title: "CCC Third", artist: "Artist 000", album: "Album 000"
            )
        ]
        let albumArtistPreferred = ScannedMediaFile(
            relativePath: "catalog-album-artist.flac", fileIdentifier: "catalog-album-artist", fileSize: 1,
            modifiedAt: .now, title: "Album Artist Preferred", artist: "Artist 001",
            album: "Album Preferred", albumArtist: "Album Artist"
        )
        let unknownMetadata = ScannedMediaFile(
            relativePath: "catalog-unknown.flac", fileIdentifier: "catalog-unknown", fileSize: 1,
            modifiedAt: .now, title: "Unknown Metadata", artist: "", album: "", albumArtist: ""
        )
        let hidden = ScannedMediaFile(
            relativePath: "catalog-hidden.flac", fileIdentifier: "catalog-hidden", fileSize: 1,
            modifiedAt: .now, title: "Hidden", artist: "Hidden Artist", album: "Hidden Album"
        )
        try await repository.applyReconciliation(
            upserts: uniqueFiles + [duplicate] + sameArtist + [albumArtistPreferred, unknownMetadata, hidden],
            missingIdentifiers: [], sourceID: sourceID
        )
        let imported = try await repository.tracks(sourceID: sourceID)
        let hiddenID = try XCTUnwrap(imported.first { $0.fileIdentifier == hidden.fileIdentifier }?.id)
        try await repository.excludeTracks(ids: [hiddenID])

        let artistGroups = try await repository.catalogGroups(kind: .artist)
        XCTAssertEqual(artistGroups.count, 502)
        XCTAssertEqual(artistGroups.map(\.key), artistGroups.map(\.key).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        })
        let primaryArtist = try XCTUnwrap(artistGroups.first { $0.key == "Artist 000" })
        XCTAssertEqual(primaryArtist.count, 4)
        XCTAssertEqual(primaryArtist.previewTitles, ["AAA First", "BBB Second", "CCC Third"])
        let primaryArtistIDs = try await repository.catalogGroupTrackIDs(kind: .artist, key: "Artist 000")
        XCTAssertEqual(primaryArtistIDs.count, primaryArtist.count)
        XCTAssertFalse(primaryArtistIDs.contains(hiddenID))
        XCTAssertTrue(artistGroups.contains { $0.key == "未知歌手" && $0.count == 1 })
        XCTAssertFalse(artistGroups.contains { $0.key == "Hidden Artist" })

        let albumGroups = try await repository.catalogGroups(kind: .album)
        XCTAssertEqual(albumGroups.count, 503)
        XCTAssertEqual(albumGroups.map(\.key), albumGroups.map(\.key).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        })
        XCTAssertTrue(albumGroups.contains { $0.key == "Album 000 · Artist 000" })
        XCTAssertTrue(albumGroups.contains { $0.key == "Album Preferred · Album Artist" })
        XCTAssertTrue(albumGroups.contains { $0.key == "未知專輯 · 未知歌手" })
        let preferredAlbumIDs = try await repository.catalogGroupTrackIDs(kind: .album, key: "Album Preferred · Album Artist")
        XCTAssertEqual(preferredAlbumIDs.count, 1)
    }

    func testTracksByIDsChunksLargePredicatesAndPreservesRequestedOrder() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let files = (0..<405).map { index in
            ScannedMediaFile(
                relativePath: "track-\(index).flac", fileIdentifier: "track-\(index)",
                fileSize: 1, modifiedAt: .now, title: "Track \(index)",
                artworkData: index == 0 ? Data([1, 2, 3]) : nil
            )
        }
        try await repository.applyReconciliation(upserts: files, missingIdentifiers: [], sourceID: sourceID)
        let imported = try await repository.tracks(sourceID: sourceID)
        let requestedIDs = Array(imported.map(\.id).reversed())
        let fetched = try await repository.tracks(ids: requestedIDs)
        XCTAssertEqual(fetched.map(\.id), requestedIDs)
        let lean = try await repository.tracks(ids: requestedIDs, includeArtwork: false)
        XCTAssertEqual(lean.map(\.id), requestedIDs)
        XCTAssertTrue(lean.allSatisfy { $0.artworkData == nil })
        let leanPage = try await repository.tracks(matching: "", limit: 200, offset: 0, includeArtwork: false)
        XCTAssertEqual(leanPage.count, 200)
        XCTAssertTrue(leanPage.allSatisfy { $0.artworkData == nil })
        let leanSearch = try await repository.tracks(matching: "Track 0", limit: 20, offset: 0, includeArtwork: false)
        XCTAssertTrue(leanSearch.allSatisfy { $0.artworkData == nil })
        XCTAssertEqual(fetched.first(where: { $0.fileIdentifier == "track-0" })?.artworkData, Data([1, 2, 3]))
    }

    func testReimportIntentPersistsWithSourceRecord() throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let source = MediaSourceRecord(displayName: "NAS", bookmarkData: Data([1]), status: .scanning)
        source.pendingReimportRestore = true
        source.rootPath = "/Volumes/NAS/Music"
        context.insert(source)
        try context.save()
        let freshContext = ModelContext(container)
        let restored = try XCTUnwrap(freshContext.fetch(FetchDescriptor<MediaSourceRecord>()).first)
        XCTAssertEqual(restored.status, .scanning)
        XCTAssertTrue(restored.pendingReimportRestore)
        XCTAssertEqual(restored.rootPath, "/Volumes/NAS/Music")
    }

    func testLoadedSearchIndexUpdatesAfterLaterScanOnSameRepository() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let first = ScannedMediaFile(
            relativePath: "first.flac", fileIdentifier: "first", fileSize: 1,
            modifiedAt: .now, title: "Moon One"
        )
        try await repository.applyReconciliation(upserts: [first], missingIdentifiers: [], sourceID: sourceID)
        let initialCandidates = try await repository.searchCandidates(matching: "moon")
        XCTAssertEqual(initialCandidates.count, 1)

        let second = ScannedMediaFile(
            relativePath: "second.flac", fileIdentifier: "second", fileSize: 1,
            modifiedAt: .now, title: "Moon Two"
        )
        try await repository.applyReconciliation(
            upserts: [first, second], missingIdentifiers: [], sourceID: sourceID
        )
        let updatedCandidates = try await repository.searchCandidates(matching: "moon")
        XCTAssertEqual(updatedCandidates.count, 2)
    }

    func testApplyScanBatchRejectsDuplicateFileIdentifiers() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let duplicateFiles = [
            ScannedMediaFile(relativePath: "one.flac", fileIdentifier: "same", fileSize: 1,
                             modifiedAt: .now, title: "One"),
            ScannedMediaFile(relativePath: "two.flac", fileIdentifier: "same", fileSize: 2,
                             modifiedAt: .now, title: "Two")
        ]

        do {
            try await repository.applyScanBatch(
                duplicateFiles,
                sourceID: sourceID,
                scanID: await repository.beginScan(sourceID: sourceID)
            )
            XCTFail("Expected duplicate identifiers to be rejected")
        } catch let error as LibraryRepositoryError {
            XCTAssertEqual(error, .invalidReconciliation)
        }
        let imported = try await repository.tracks(sourceID: sourceID)
        XCTAssertTrue(imported.isEmpty)
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

    func testExcludedTracksStayHiddenAfterRescanButKeepPlaylistMembership() async throws {
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
        XCTAssertEqual(playlistsAfterRemoval.first?.trackIDs, [removed.id, kept.id])
        let playlistEntries = try await repository.playlistEntries(ids: [removed.id, kept.id])
        XCTAssertEqual(playlistEntries.map(\.id), [removed.id, kept.id])
        XCTAssertTrue(playlistEntries[0].isExcluded)

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

    func testReimportRestoresOnlySeenFilesAndExplicitCleanupPreservesValidEntries() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let files = [
            ScannedMediaFile(relativePath: "present.mp3", fileIdentifier: "present", fileSize: 1,
                             modifiedAt: .now, title: "仍存在"),
            ScannedMediaFile(relativePath: "deleted.mp3", fileIdentifier: "deleted", fileSize: 1,
                             modifiedAt: .now, title: "已刪除"),
            ScannedMediaFile(relativePath: "offline.mp3", fileIdentifier: "offline", fileSize: 1,
                             modifiedAt: .now, title: "仍有效")
        ]
        try await repository.applyReconciliation(upserts: files, missingIdentifiers: [], sourceID: sourceID)
        let imported = try await repository.tracks(sourceID: sourceID)
        let snapshots = try await repository.scanSnapshots(sourceID: sourceID)
        XCTAssertEqual(Set(snapshots.map(\.fileIdentifier)), Set(files.map(\.fileIdentifier)))
        let byIdentifier = Dictionary(uniqueKeysWithValues: imported.map { ($0.fileIdentifier, $0) })
        let playlist = try await repository.createPlaylist(name: "旅程")
        let ordered = ["present", "deleted", "offline"].compactMap { byIdentifier[$0]?.id }
        try await repository.addTracks(trackIDs: ordered, toPlaylist: playlist.id)
        try await repository.excludeTracks(ids: ordered)

        let restored = try await repository.restoreTracks(sourceID: sourceID, seenIdentifiers: ["present", "offline"])
        XCTAssertEqual(restored, 2)
        try await repository.applyReconciliation(upserts: [], missingIdentifiers: ["deleted"], sourceID: sourceID)
        let entries = try await repository.playlistEntries(ids: ordered)
        XCTAssertEqual(entries.map(\.id), ordered)
        XCTAssertTrue(entries[1].isExcluded)
        XCTAssertEqual(entries[1].track.availability, .missing)
        XCTAssertFalse(entries[2].isExcluded)
        let initiallyMissing = try await repository.missingPlaylistTrackIDs(ids: ordered)
        XCTAssertTrue(initiallyMissing.isEmpty) // Excluded items never qualify for pinned playback.

        try await repository.applyReconciliation(upserts: [], missingIdentifiers: ["offline"], sourceID: sourceID)
        let laterMissing = try await repository.missingPlaylistTrackIDs(ids: ordered)
        XCTAssertEqual(laterMissing, Set([ordered[2]]))

        let cleaned = try await repository.removeUnavailableTracks(
            fromPlaylist: playlist.id, playableMissingIDs: [ordered[2]]
        )
        XCTAssertEqual(cleaned, 1)
        let playlistsAfterCleanup = try await repository.playlists()
        XCTAssertEqual(playlistsAfterCleanup.first?.trackIDs,
                       [byIdentifier["present"]?.id, byIdentifier["offline"]?.id].compactMap { $0 })
    }

    func testExplicitSourceRestoreMakesExcludedTracksVisibleAgain() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let files = (0..<405).map { index in
            ScannedMediaFile(relativePath: "song-\(index).flac", fileIdentifier: "song-\(index)",
                             fileSize: 1, modifiedAt: .now, title: "Song \(index)")
        }
        try await repository.applyReconciliation(upserts: files, missingIdentifiers: [], sourceID: sourceID)
        let imported = try await repository.tracks(sourceID: sourceID)
        try await repository.excludeTracks(ids: imported.map(\.id))
        let hiddenIDs = try await repository.trackIDs(matching: "")
        XCTAssertTrue(hiddenIDs.isEmpty)

        let restoredCount = try await repository.restoreTracks(sourceID: sourceID)
        let visibleIDs = try await repository.trackIDs(matching: "")
        let alreadyRestoredCount = try await repository.restoreTracks(sourceID: sourceID)

        XCTAssertEqual(restoredCount, files.count)
        XCTAssertEqual(visibleIDs.count, files.count)
        XCTAssertEqual(alreadyRestoredCount, 0)
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

    func testBatchMetadataUpdateAppliesPatchAndPreservesUnspecifiedFields() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let files = [
            ScannedMediaFile(
                relativePath: "first.flac", fileIdentifier: "first", fileSize: 11,
                modifiedAt: .now, title: "第一首", artist: "舊歌手一", album: "舊專輯一",
                albumArtist: "舊專輯歌手一", trackNumber: 1, discNumber: 2
            ),
            ScannedMediaFile(
                relativePath: "second.flac", fileIdentifier: "second", fileSize: 22,
                modifiedAt: .now, title: "第二首", artist: "舊歌手二", album: "舊專輯二",
                albumArtist: "舊專輯歌手二", trackNumber: 3, discNumber: 4
            ),
            ScannedMediaFile(
                relativePath: "third.flac", fileIdentifier: "third", fileSize: 33,
                modifiedAt: .now, title: "第三首", artist: "獨立歌手", album: "獨立專輯",
                albumArtist: "獨立專輯歌手", trackNumber: 5, discNumber: 6
            )
        ]
        try await repository.applyReconciliation(upserts: files, missingIdentifiers: [], sourceID: sourceID)
        let imported = try await repository.tracks(sourceID: sourceID)
        let first = try XCTUnwrap(imported.first { $0.fileIdentifier == "first" })
        let second = try XCTUnwrap(imported.first { $0.fileIdentifier == "second" })
        let third = try XCTUnwrap(imported.first { $0.fileIdentifier == "third" })
        try await repository.setFavorite(trackID: first.id, isFavorite: true)
        try await repository.setRating(trackID: first.id, rating: 4)

        try await repository.updateMetadata(
            for: [first.id, second.id],
            with: TrackMetadataPatch(
                artist: .set("共同歌手"),
                album: .set("共同專輯"),
                artworkData: .set(Data([1, 2, 3])),
                trackNumber: .clear
            )
        )

        let updated = try await repository.tracks(ids: [first.id, second.id, third.id])
        let updatedFirst = try XCTUnwrap(updated.first { $0.id == first.id })
        let updatedSecond = try XCTUnwrap(updated.first { $0.id == second.id })
        let unchangedThird = try XCTUnwrap(updated.first { $0.id == third.id })
        XCTAssertEqual(updatedFirst.artist, "共同歌手")
        XCTAssertEqual(updatedFirst.album, "共同專輯")
        XCTAssertEqual(updatedFirst.artworkData, Data([1, 2, 3]))
        XCTAssertNil(updatedFirst.trackNumber)
        XCTAssertEqual(updatedFirst.discNumber, 2)
        XCTAssertEqual(updatedFirst.title, "第一首")
        XCTAssertEqual(updatedFirst.albumArtist, "舊專輯歌手一")
        XCTAssertTrue(updatedFirst.isFavorite)
        XCTAssertEqual(updatedFirst.rating, 4)
        XCTAssertEqual(updatedSecond.artist, "共同歌手")
        XCTAssertEqual(updatedSecond.album, "共同專輯")
        XCTAssertNil(updatedSecond.trackNumber)
        XCTAssertEqual(updatedSecond.discNumber, 4)
        XCTAssertEqual(updatedSecond.title, "第二首")
        XCTAssertEqual(updatedSecond.albumArtist, "舊專輯歌手二")
        XCTAssertEqual(unchangedThird.artist, "獨立歌手")
        XCTAssertEqual(unchangedThird.album, "獨立專輯")
        XCTAssertEqual(unchangedThird.trackNumber, 5)
        XCTAssertEqual(unchangedThird.relativePath, "third.flac")
        XCTAssertEqual(unchangedThird.fileIdentifier, "third")
    }

    func testBatchMetadataUpdateValidatesAllIDsBeforeMutatingAnyTrack() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        try await repository.applyReconciliation(
            upserts: [
                ScannedMediaFile(relativePath: "first.flac", fileIdentifier: "first", fileSize: 1,
                                  modifiedAt: .now, title: "第一首", artist: "原歌手一"),
                ScannedMediaFile(relativePath: "second.flac", fileIdentifier: "second", fileSize: 2,
                                  modifiedAt: .now, title: "第二首", artist: "原歌手二")
            ],
            missingIdentifiers: [], sourceID: sourceID
        )
        let imported = try await repository.tracks(sourceID: sourceID)
        let first = try XCTUnwrap(imported.first { $0.fileIdentifier == "first" })
        let second = try XCTUnwrap(imported.first { $0.fileIdentifier == "second" })
        let missingID = UUID()

        do {
            try await repository.updateMetadata(
                for: [first.id, missingID, second.id],
                with: TrackMetadataPatch(artist: .set("不應寫入"))
            )
            XCTFail("Missing track IDs must reject the whole metadata batch")
        } catch let error as LibraryRepositoryError {
            XCTAssertEqual(error, .trackNotFound(missingID))
        }

        do {
            try await repository.updateMetadata(
                for: [first.id, second.id],
                with: TrackMetadataPatch(trackNumber: .set(-1))
            )
            XCTFail("Negative track numbers must reject the metadata batch")
        } catch let error as LibraryRepositoryError {
            XCTAssertEqual(error, .invalidMetadata)
        }

        let unchanged = try await repository.tracks(ids: [first.id, second.id])
        XCTAssertEqual(unchanged.first { $0.id == first.id }?.artist, "原歌手一")
        XCTAssertEqual(unchanged.first { $0.id == second.id }?.artist, "原歌手二")
    }

    func testBatchPlaylistRemovalPreservesOrderAndIgnoresUnknownIDs() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        let files = (0..<4).map { index in
            ScannedMediaFile(
                relativePath: "track-\(index).flac", fileIdentifier: "track-\(index)",
                fileSize: Int64(index + 1), modifiedAt: .now, title: "曲目 \(index)"
            )
        }
        try await repository.applyReconciliation(upserts: files, missingIdentifiers: [], sourceID: sourceID)
        let imported = try await repository.tracks(sourceID: sourceID)
        let ordered = files.compactMap { file in imported.first { $0.fileIdentifier == file.fileIdentifier }?.id }
        XCTAssertEqual(ordered.count, 4)
        let playlist = try await repository.createPlaylist(name: "批次移除")
        try await repository.addTracks(trackIDs: ordered, toPlaylist: playlist.id)

        let unknownID = UUID()
        try await repository.removeTracks(
            trackIDs: [ordered[2], unknownID, ordered[0], ordered[2]],
            fromPlaylist: playlist.id
        )

        let remaining = try await repository.playlists().first { $0.id == playlist.id }
        XCTAssertEqual(remaining?.trackIDs, [ordered[1], ordered[3]])
    }

    func testBatchMetadataOverridesSurviveRescanOnlyForEditedFields() async throws {
        let container = try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        try await repository.applyReconciliation(
            upserts: [ScannedMediaFile(
                relativePath: "song.flac", fileIdentifier: "song", fileSize: 1,
                modifiedAt: .now, title: "來源標題", artist: "來源歌手", album: "來源專輯",
                albumArtist: "來源專輯歌手", trackNumber: 1, discNumber: 1
            )],
            missingIdentifiers: [], sourceID: sourceID
        )
        let imported = try await repository.tracks(sourceID: sourceID)
        let original = try XCTUnwrap(imported.first)
        try await repository.updateMetadata(
            for: [original.id],
            with: TrackMetadataPatch(title: .set("使用者標題"), artist: .set("使用者歌手"))
        )

        try await repository.applyReconciliation(
            upserts: [ScannedMediaFile(
                relativePath: "song.flac", fileIdentifier: "song", fileSize: 2,
                modifiedAt: .now, title: "重掃標題", artist: "重掃歌手", album: "重掃專輯",
                albumArtist: "重掃專輯歌手", trackNumber: 9, discNumber: 9
            )],
            missingIdentifiers: [], sourceID: sourceID
        )

        let rescannedTracks = try await repository.tracks(sourceID: sourceID)
        let rescanned = try XCTUnwrap(rescannedTracks.first)
        XCTAssertEqual(rescanned.title, "使用者標題")
        XCTAssertEqual(rescanned.artist, "使用者歌手")
        XCTAssertEqual(rescanned.album, "重掃專輯")
        XCTAssertEqual(rescanned.albumArtist, "重掃專輯歌手")
        XCTAssertEqual(rescanned.trackNumber, 9)
        XCTAssertEqual(rescanned.discNumber, 9)
        XCTAssertEqual(rescanned.fileSize, 2)
        XCTAssertEqual(rescanned.relativePath, "song.flac")
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

    func testSameSizeSmartCacheMutationFallsBackToFullVerification() async throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-smart-corrupt-\(UUID().uuidString).bin")
        try Data(repeating: 3, count: 64).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let store = try FileOfflineCacheStore()
        let trackID = UUID()
        let cachedURL = try await store.prefetch(trackID: trackID, sourceURL: source)
        let initialURL = await store.cachedURL(trackID: trackID)
        XCTAssertEqual(initialURL, cachedURL)

        try Data(repeating: 9, count: 64).write(to: cachedURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: 120)],
            ofItemAtPath: cachedURL.path
        )

        let mutatedURL = await store.cachedURL(trackID: trackID)
        let verified = await store.verify(trackID: trackID)
        XCTAssertNil(mutatedURL)
        XCTAssertFalse(verified)
        try await store.trim(to: 0)
    }

    func testPinnedStatusRequiresMediaAndChecksumSidecar() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("cache-pinned-status-\(UUID().uuidString).bin")
        try Data(repeating: 5, count: 64).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let store = try FileOfflineCacheStore()
        let trackID = UUID()
        let cachedURL = try await store.pin(trackID: trackID, sourceURL: source)
        let intact = await store.isPinned(trackID: trackID)
        XCTAssertTrue(intact)
        let batchPinned = await store.pinnedTrackIDs(in: [trackID, UUID()])
        XCTAssertEqual(batchPinned, Set([trackID]))
        let presentPinned = await store.presentPinnedTrackIDs(in: [trackID, UUID()])
        XCTAssertEqual(presentPinned, Set([trackID]))

        try Data(repeating: 6, count: 64).write(to: cachedURL, options: .atomic)
        let modifiedMediaStillPinned = await store.isPinned(trackID: trackID)
        XCTAssertTrue(modifiedMediaStillPinned)
        let batchDamaged = await store.pinnedTrackIDs(in: [trackID])
        XCTAssertTrue(batchDamaged.isEmpty)
        let presentDamaged = await store.presentPinnedTrackIDs(in: [trackID])
        XCTAssertEqual(presentDamaged, Set([trackID]))

        try Data(repeating: 5, count: 64).write(to: cachedURL, options: .atomic)
        try FileManager.default.removeItem(at: cachedURL.deletingPathExtension().appendingPathExtension("sha256"))
        let missingSidecar = await store.isPinned(trackID: trackID)
        XCTAssertFalse(missingSidecar)
        let batchMissingSidecar = await store.pinnedTrackIDs(in: [trackID])
        XCTAssertTrue(batchMissingSidecar.isEmpty)
        let presentMissingSidecar = await store.presentPinnedTrackIDs(in: [trackID])
        XCTAssertTrue(presentMissingSidecar.isEmpty)

        let sidecarURL = cachedURL.deletingPathExtension().appendingPathExtension("sha256")
        try Data("  \n".utf8).write(to: sidecarURL, options: .atomic)
        let presentEmptySidecar = await store.presentPinnedTrackIDs(in: [trackID])
        XCTAssertTrue(presentEmptySidecar.isEmpty)

        try await store.unpin(trackID: trackID)
    }

    func testOfflineCacheReplacesSameTrackWithNewExtension() async throws {
        let sourceRoot = FileManager.default.temporaryDirectory.appendingPathComponent("cache-extension-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let firstSource = sourceRoot.appendingPathComponent("source.MP3")
        let secondSource = sourceRoot.appendingPathComponent("source.FLAC")
        try Data(repeating: 1, count: 32).write(to: firstSource)
        try Data(repeating: 2, count: 48).write(to: secondSource)

        let store = try FileOfflineCacheStore()
        let pinnedID = UUID()
        let firstPinnedURL = try await store.pin(trackID: pinnedID, sourceURL: firstSource)
        let secondPinnedURL = try await store.pin(trackID: pinnedID, sourceURL: secondSource)
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstPinnedURL.path))
        let resolvedPinnedURL = await store.cachedURL(trackID: pinnedID)
        XCTAssertEqual(resolvedPinnedURL, secondPinnedURL)

        let smartID = UUID()
        let firstSmartURL = try await store.prefetch(trackID: smartID, sourceURL: firstSource)
        let secondSmartURL = try await store.prefetch(trackID: smartID, sourceURL: secondSource)
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstSmartURL.path))
        let resolvedSmartURL = await store.cachedURL(trackID: smartID)
        XCTAssertEqual(resolvedSmartURL, secondSmartURL)

        try await store.unpin(trackID: pinnedID)
        try await store.trim(to: 0)
    }

    func testPrefetchStagesOffActorAndKeepsExistingCacheAvailable() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-staging-\(UUID().uuidString)", isDirectory: true)
        let pinnedRoot = root.appendingPathComponent("Pinned", isDirectory: true)
        let smartRoot = root.appendingPathComponent("Smart", isDirectory: true)
        let sourceRoot = root.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let firstSource = sourceRoot.appendingPathComponent("first.mp3")
        let secondSource = sourceRoot.appendingPathComponent("second.flac")
        try Data(repeating: 1, count: 64).write(to: firstSource)
        try Data(repeating: 2, count: 64).write(to: secondSource)
        let gate = CopyGate()
        let store = try FileOfflineCacheStore(
            pinnedRoot: pinnedRoot,
            smartRoot: smartRoot,
            fileManager: GatedFileManager(gate: gate)
        )
        let trackID = UUID()
        let existingURL = try await store.prefetch(trackID: trackID, sourceURL: firstSource)

        gate.arm()
        let pending = Task { try await store.prefetch(trackID: trackID, sourceURL: secondSource) }
        defer { gate.release.signal() }
        XCTAssertEqual(gate.entered.wait(timeout: .now() + 10), .success)
        let lookup = Task { await store.cachedURL(trackID: trackID) }
        let lookupExpectation = expectation(description: "cachedURL completes while prefetch stages")
        Task {
            _ = await lookup.value
            lookupExpectation.fulfill()
        }
        await fulfillment(of: [lookupExpectation], timeout: 2)
        gate.release.signal()
        let availableDuringStaging = await lookup.value
        XCTAssertEqual(availableDuringStaging?.standardizedFileURL, existingURL.standardizedFileURL)

        let replacementURL = try await pending.value
        XCTAssertNotEqual(replacementURL, existingURL)
        let resolvedReplacement = await store.cachedURL(trackID: trackID)
        XCTAssertEqual(resolvedReplacement?.standardizedFileURL, replacementURL.standardizedFileURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: existingURL.path))
    }

    func testCancelledPrefetchRollsBackStagingAndPreservesExistingCache() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-cancel-\(UUID().uuidString)", isDirectory: true)
        let pinnedRoot = root.appendingPathComponent("Pinned", isDirectory: true)
        let smartRoot = root.appendingPathComponent("Smart", isDirectory: true)
        let sourceRoot = root.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let firstSource = sourceRoot.appendingPathComponent("first.mp3")
        let secondSource = sourceRoot.appendingPathComponent("second.flac")
        try Data(repeating: 3, count: 64).write(to: firstSource)
        try Data(repeating: 4, count: 64).write(to: secondSource)
        let gate = CopyGate()
        let store = try FileOfflineCacheStore(
            pinnedRoot: pinnedRoot,
            smartRoot: smartRoot,
            fileManager: GatedFileManager(gate: gate)
        )
        let trackID = UUID()
        let existingURL = try await store.prefetch(trackID: trackID, sourceURL: firstSource)

        gate.arm()
        let pending = Task { () -> Bool in
            do {
                _ = try await store.prefetch(trackID: trackID, sourceURL: secondSource)
                return false
            } catch is CancellationError {
                return true
            } catch {
                return false
            }
        }
        XCTAssertEqual(gate.entered.wait(timeout: .now() + 10), .success)
        defer { gate.release.signal() }
        pending.cancel()
        gate.release.signal()

        let cancelled = await pending.value
        XCTAssertTrue(cancelled)
        let resolvedAfterCancellation = await store.cachedURL(trackID: trackID)
        XCTAssertEqual(resolvedAfterCancellation?.standardizedFileURL, existingURL.standardizedFileURL)
        let leftovers = (try? FileManager.default.contentsOfDirectory(at: smartRoot, includingPropertiesForKeys: nil)) ?? []
        XCTAssertFalse(leftovers.contains { $0.lastPathComponent.hasSuffix(".part") })
        XCTAssertTrue(FileManager.default.fileExists(atPath: existingURL.path))
    }

    func testSupersededPrefetchDoesNotPublishOlderStaging() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-supersession-\(UUID().uuidString)", isDirectory: true)
        let pinnedRoot = root.appendingPathComponent("Pinned", isDirectory: true)
        let smartRoot = root.appendingPathComponent("Smart", isDirectory: true)
        let sourceRoot = root.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let firstSource = sourceRoot.appendingPathComponent("first.mp3")
        let secondSource = sourceRoot.appendingPathComponent("second.flac")
        try Data(repeating: 5, count: 64).write(to: firstSource)
        try Data(repeating: 6, count: 64).write(to: secondSource)
        let gate = CopyGate()
        let store = try FileOfflineCacheStore(
            pinnedRoot: pinnedRoot,
            smartRoot: smartRoot,
            fileManager: GatedFileManager(gate: gate)
        )
        let trackID = UUID()
        gate.arm()
        let older = Task { () -> Bool in
            do {
                _ = try await store.prefetch(trackID: trackID, sourceURL: firstSource)
                return false
            } catch is CancellationError {
                return true
            } catch {
                return false
            }
        }
        XCTAssertEqual(gate.entered.wait(timeout: .now() + 10), .success)
        let admissionExpectation = expectation(description: "newer prefetch admitted before older release")
        let newer = Task {
            try await store.prefetch(
                trackID: trackID,
                sourceURL: secondSource,
                onAdmission: { admissionExpectation.fulfill() }
            )
        }
        await fulfillment(of: [admissionExpectation], timeout: 2)
        gate.release.signal()

        let superseded = await older.value
        XCTAssertTrue(superseded)
        let newestURL = try await newer.value
        let resolvedNewest = await store.cachedURL(trackID: trackID)
        XCTAssertEqual(resolvedNewest?.standardizedFileURL, newestURL.standardizedFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: newestURL.path))
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
