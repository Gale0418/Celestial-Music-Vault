import XCTest
import SwiftData
import CMVDomain
import CMVLibrary

final class MetadataOperationTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeRepository() throws -> SwiftDataLibraryRepository {
        SwiftDataLibraryRepository(container: try makeContainer())
    }

    func testUndoRestoresHeterogeneousMetadataAndPreservesPriorOverride() async throws {
        let repository = try makeRepository()
        let sourceID = UUID()
        let firstDate = Date(timeIntervalSince1970: 100)
        try await repository.applyReconciliation(upserts: [
            ScannedMediaFile(relativePath: "a.flac", fileIdentifier: "a", fileSize: 1,
                              modifiedAt: firstDate, title: "A", artist: "A-artist",
                              album: "A-album", genre: "ambient", releaseDate: firstDate,
                              artworkData: Data([1]), trackNumber: 1, discNumber: 2),
            ScannedMediaFile(relativePath: "b.flac", fileIdentifier: "b", fileSize: 2,
                              modifiedAt: firstDate, title: "B", artist: "B-artist",
                              album: "B-album", genre: nil, releaseDate: nil,
                              artworkData: nil, trackNumber: nil, discNumber: 1)
        ], missingIdentifiers: [], sourceID: sourceID)
        let imported = try await repository.tracks(sourceID: sourceID)
        let first = try XCTUnwrap(imported.first { $0.fileIdentifier == "a" })
        let second = try XCTUnwrap(imported.first { $0.fileIdentifier == "b" })

        try await repository.updateMetadata(for: [first.id], with: TrackMetadataPatch(title: .set("手動標題")))
        let receipt = try await repository.updateMetadataWithUndo(
            for: [first.id, second.id],
            with: TrackMetadataPatch(
                artist: .set("共同歌手"), genre: .clear,
                releaseDate: .set(Date(timeIntervalSince1970: 200)),
                artworkData: .set(Data([8, 9])), trackNumber: .clear
            )
        )
        XCTAssertTrue(receipt.capturesArtwork)
        let result = try await repository.undoMetadata(receipt)
        XCTAssertEqual(Set(result.restoredIDs), Set([first.id, second.id]))
        XCTAssertTrue(result.conflictIDs.isEmpty)

        let restored = try await repository.tracks(ids: [first.id, second.id])
        let restoredFirst = try XCTUnwrap(restored.first { $0.id == first.id })
        XCTAssertEqual(restoredFirst.title, "手動標題")
        XCTAssertEqual(restoredFirst.artist, "A-artist")
        XCTAssertEqual(restoredFirst.genre, "ambient")
        XCTAssertEqual(restoredFirst.releaseDate, firstDate)
        XCTAssertEqual(restoredFirst.artworkData, Data([1]))
        XCTAssertEqual(restoredFirst.trackNumber, 1)
    }

    func testTitleOnlyUndoPreservesArtworkEditedAfterTheBatch() async throws {
        let repository = try makeRepository()
        let sourceID = UUID()
        try await repository.applyReconciliation(upserts: [
            ScannedMediaFile(relativePath: "artwork.flac", fileIdentifier: "artwork", fileSize: 1,
                              modifiedAt: .now, title: "原標題", artworkData: Data([1]))
        ], missingIdentifiers: [], sourceID: sourceID)
        let imported = try await repository.tracks(sourceID: sourceID)
        let track = try XCTUnwrap(imported.first)

        let receipt = try await repository.updateMetadataWithUndo(
            for: [track.id], with: TrackMetadataPatch(title: .set("批次標題"))
        )
        XCTAssertFalse(receipt.capturesArtwork)

        try await repository.updateMetadata(
            for: [track.id], with: TrackMetadataPatch(artworkData: .set(Data([2, 3])))
        )
        let result = try await repository.undoMetadata(receipt)

        XCTAssertEqual(result.restoredIDs, [track.id])
        XCTAssertTrue(result.conflictIDs.isEmpty)
        let restored = try await repository.tracks(ids: [track.id]).first
        XCTAssertEqual(restored?.title, "原標題")
        XCTAssertEqual(restored?.artworkData, Data([2, 3]))
    }

    func testUndoReportsDeletedTrackAsConflictAndRestoresRemainingTracks() async throws {
        let container = try makeContainer()
        let repository = SwiftDataLibraryRepository(container: container)
        let sourceID = UUID()
        try await repository.applyReconciliation(upserts: [
            ScannedMediaFile(relativePath: "deleted.flac", fileIdentifier: "deleted", fileSize: 1,
                              modifiedAt: .now, title: "刪除前"),
            ScannedMediaFile(relativePath: "remaining.flac", fileIdentifier: "remaining", fileSize: 1,
                              modifiedAt: .now, title: "保留前")
        ], missingIdentifiers: [], sourceID: sourceID)
        let tracks = try await repository.tracks(sourceID: sourceID)
        let deleted = try XCTUnwrap(tracks.first { $0.fileIdentifier == "deleted" })
        let remaining = try XCTUnwrap(tracks.first { $0.fileIdentifier == "remaining" })
        let receipt = try await repository.updateMetadataWithUndo(
            for: [deleted.id, remaining.id],
            with: TrackMetadataPatch(title: .set("批次標題"))
        )

        let context = ModelContext(container)
        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<TrackRecord>(
            predicate: #Predicate { $0.id == deleted.id }
        )).first)
        context.delete(record)
        try context.save()

        let result = try await repository.undoMetadata(receipt)

        XCTAssertEqual(result.restoredIDs, [remaining.id])
        XCTAssertEqual(result.conflictIDs, [deleted.id])
        let restored = try await repository.tracks(ids: [remaining.id]).first
        XCTAssertEqual(restored?.title, "保留前")
        let deletedAfter = try await repository.tracks(ids: [deleted.id])
        XCTAssertTrue(deletedAfter.isEmpty)
    }

    func testUndoReportsConflictWithoutClobberingLaterEdit() async throws {
        let repository = try makeRepository()
        let sourceID = UUID()
        try await repository.applyReconciliation(upserts: [
            ScannedMediaFile(relativePath: "a.flac", fileIdentifier: "a", fileSize: 1,
                              modifiedAt: .now, title: "A")
        ], missingIdentifiers: [], sourceID: sourceID)
        let loadedTracks = try await repository.tracks(sourceID: sourceID)
        let track = try XCTUnwrap(loadedTracks.first)
        let receipt = try await repository.updateMetadataWithUndo(for: [track.id], with: TrackMetadataPatch(artist: .set("批次歌手")))
        try await repository.updateMetadata(for: [track.id], with: TrackMetadataPatch(artist: .set("後續歌手")))
        let result = try await repository.undoMetadata(receipt)
        XCTAssertEqual(result.restoredIDs, [])
        XCTAssertEqual(result.conflictIDs, [track.id])
        let afterConflict = try await repository.tracks(ids: [track.id])
        XCTAssertEqual(afterConflict.first?.artist, "後續歌手")
    }

    func testPlaylistReorderRequiresCompleteUniquePermutation() async throws {
        let repository = try makeRepository()
        let sourceID = UUID()
        let files = (0..<3).map { index in
            ScannedMediaFile(relativePath: "\(index).flac", fileIdentifier: "\(index)", fileSize: 1,
                              modifiedAt: .now, title: "\(index)")
        }
        try await repository.applyReconciliation(upserts: files, missingIdentifiers: [], sourceID: sourceID)
        let tracks = try await repository.tracks(sourceID: sourceID)
        let playlist = try await repository.createPlaylist(name: "排序")
        try await repository.addTracks(trackIDs: tracks.map(\.id), toPlaylist: playlist.id)
        do {
            try await repository.reorderPlaylist(id: playlist.id, trackIDs: [tracks[0].id, tracks[0].id, tracks[2].id])
            XCTFail("Duplicate IDs must be rejected")
        } catch let error as LibraryRepositoryError {
            XCTAssertEqual(error, .invalidPlaylistPermutation)
        }
        try await repository.reorderPlaylist(id: playlist.id, trackIDs: [tracks[2].id, tracks[0].id, tracks[1].id])
        let reordered = try await repository.playlists()
        XCTAssertEqual(reordered.first?.trackIDs, [tracks[2].id, tracks[0].id, tracks[1].id])
    }

    func testAddedAtDateSortIsStableAcrossPages() async throws {
        let repository = try makeRepository()
        let sourceID = UUID()
        let files = ["a", "b", "c"].map { name in
            ScannedMediaFile(relativePath: "\(name).flac", fileIdentifier: name, fileSize: 1,
                              modifiedAt: .now, title: name)
        }
        try await repository.applyReconciliation(upserts: files, missingIdentifiers: [], sourceID: sourceID)
        let all = try await repository.tracks(matching: "", sort: .addedAt, ascending: true, limit: 3, offset: 0)
        let pageOne = try await repository.tracks(matching: "", sort: .addedAt, ascending: true, limit: 1, offset: 0)
        let pageTwo = try await repository.tracks(matching: "", sort: .addedAt, ascending: true, limit: 2, offset: 1)
        XCTAssertEqual(all.map(\.id), pageOne.map(\.id) + pageTwo.map(\.id))
        XCTAssertEqual(all.map(\.addedAt).sorted(), all.map(\.addedAt))
    }
}
