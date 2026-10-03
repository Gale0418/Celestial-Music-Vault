import XCTest
import SwiftData
import CMVDomain
import CMVLibrary
import CMVPlayback
@testable import CMV

#if DEBUG && CMV_STOREKIT_TEST_HOST
@MainActor
final class AppModelReliabilityTests: XCTestCase {
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
}
#endif
