import XCTest
import AVFoundation
import SwiftData
import CMVDomain
import CMVLibrary
import CMVPlayback

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

    private func makeSilentAudioFile(sampleRate: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMV-Reliability-\(UUID().uuidString).caf")
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ), let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(sampleRate)
        ), let samples = buffer.floatChannelData?[0] else {
            throw CocoaError(.fileWriteUnknown)
        }
        buffer.frameLength = buffer.frameCapacity
        samples.initialize(repeating: 0, count: Int(buffer.frameLength))
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
