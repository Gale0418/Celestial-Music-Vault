import XCTest
import CMVDomain
@testable import CMVPlayback

final class QueueOperationTests: XCTestCase {
    private let first = UUID()
    private let second = UUID()
    private let third = UUID()

    private func occurrence(_ id: UUID) -> PlaybackQueueOccurrence {
        PlaybackQueueOccurrence(trackID: id)
    }

    func testPlayNextKeepsDuplicateOccurrencesDistinct() {
        let current = occurrence(first)
        let snapshot = PlaybackQueueSnapshot(entries: [current, occurrence(second)], currentIndex: 0)
        let duplicate = occurrence(first)

        let result = PlaybackQueuePlanner.append([duplicate], to: snapshot, playNext: true)

        XCTAssertEqual(result.entries.map(\.trackID), [first, first, second])
        XCTAssertNotEqual(result.entries[0].occurrenceID, result.entries[1].occurrenceID)
        XCTAssertEqual(result.currentIndex, 0)
    }

    func testAppendingToEmptyQueueNeverAdvancesPastTheFirstOccurrence() {
        let addition = occurrence(first)
        let appended = PlaybackQueuePlanner.append([addition], to: PlaybackQueueSnapshot())
        let playedNext = PlaybackQueuePlanner.append([addition], to: PlaybackQueueSnapshot(), playNext: true)

        XCTAssertEqual(appended.currentIndex, 0)
        XCTAssertEqual(appended.current?.occurrenceID, addition.occurrenceID)
        XCTAssertEqual(playedNext.currentIndex, 0)
        XCTAssertEqual(playedNext.current?.occurrenceID, addition.occurrenceID)
    }

    func testMoveAndRemoveAdjustCurrentPositionWithoutRemovingCurrent() {
        let snapshot = PlaybackQueueSnapshot(
            entries: [occurrence(first), occurrence(second), occurrence(third)], currentIndex: 0
        )
        let moved = PlaybackQueuePlanner.move(snapshot, from: 2, to: 1)
        XCTAssertEqual(moved.entries.map(\.trackID), [first, third, second])
        XCTAssertEqual(moved.currentIndex, 0)

        let removed = PlaybackQueuePlanner.remove(moved, at: 1)
        XCTAssertEqual(removed.entries.map(\.trackID), [first, second])
        XCTAssertEqual(removed.currentIndex, 0)
        XCTAssertEqual(PlaybackQueuePlanner.remove(removed, at: 0).entries.count, 2)
    }

    func testMoveUsesInsertionBoundaryForForwardBackwardEndAndCurrent() {
        let entries = [occurrence(first), occurrence(second), occurrence(third), occurrence(UUID())]
        let snapshot = PlaybackQueueSnapshot(entries: entries, currentIndex: 0)
        let movedToEnd = PlaybackQueuePlanner.move(snapshot, from: 1, to: entries.count)
        XCTAssertEqual(movedToEnd.entries.map(\.trackID), [first, third, entries[3].trackID, second])

        let movedBackward = PlaybackQueuePlanner.move(movedToEnd, from: 2, to: 1)
        XCTAssertEqual(movedBackward.entries.map(\.trackID), [first, entries[3].trackID, third, second])
        XCTAssertEqual(PlaybackQueuePlanner.move(snapshot, from: 0, to: 3).entries.map(\.trackID), snapshot.entries.map(\.trackID))
        XCTAssertEqual(movedBackward.currentIndex, 0)
    }

    func testShufflePlayNextUpdatesBaseOrderAndRestoresCurrentOccurrence() {
        let current = occurrence(first)
        let secondEntry = occurrence(second)
        let thirdEntry = occurrence(third)
        let addition = occurrence(first)
        let shuffled = PlaybackQueueSnapshot(
            entries: [current, thirdEntry, secondEntry],
            baseEntries: [current, secondEntry, thirdEntry],
            currentIndex: 0,
            shuffleEnabled: true
        )

        let withNext = PlaybackQueuePlanner.append([addition], to: shuffled, playNext: true)
        let restored = PlaybackQueuePlanner.restoreBaseOrder(withNext)

        XCTAssertEqual(withNext.entries.map(\.trackID), [first, first, third, second])
        XCTAssertEqual(restored.entries.map(\.trackID), [first, first, second, third])
        XCTAssertEqual(restored.current?.occurrenceID, current.occurrenceID)
        XCTAssertEqual(restored.entries[1].occurrenceID, addition.occurrenceID)
        XCTAssertFalse(restored.shuffleEnabled)
    }

    func testRepeatModesDefineEndOfQueueSemantics() {
        var snapshot = PlaybackQueueSnapshot(
            entries: [occurrence(first), occurrence(second)], currentIndex: 1,
            repeatMode: .off
        )
        XCTAssertNil(PlaybackQueuePlanner.nextIndex(in: snapshot))
        snapshot.repeatMode = .all
        XCTAssertEqual(PlaybackQueuePlanner.nextIndex(in: snapshot), 0)
        snapshot.repeatMode = .one
        XCTAssertEqual(PlaybackQueuePlanner.nextIndex(in: snapshot), 1)
    }

    func testHistoryIsBoundedAndSnapshotStoreRoundTripsCompactData() async throws {
        let historyEntries = (0...PlaybackQueuePlanner.historyLimit).map { _ in occurrence(UUID()) }
        var snapshot = PlaybackQueueSnapshot(entries: historyEntries)
        for entry in historyEntries {
            snapshot = PlaybackQueuePlanner.recordPlayed(entry.occurrenceID, in: snapshot)
        }
        XCTAssertEqual(snapshot.history.count, PlaybackQueuePlanner.historyLimit)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVQueueOperation-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = PlaybackQueueSnapshotStore(url: url)
        snapshot.revision = 1
        try await store.save(snapshot)
        let restored = await store.load()
        XCTAssertEqual(restored, snapshot)
    }

    func testSnapshotStoreRetainsRevisionLoadedFromValidEmptySnapshot() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVQueueEmptyRevision-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let empty = PlaybackQueueSnapshot(revision: 41)
        try JSONEncoder().encode(empty).write(to: url, options: .atomic)
        let store = PlaybackQueueSnapshotStore(url: url)

        let loaded = await store.load()
        XCTAssertEqual(loaded?.revision, 41)
        XCTAssertTrue(loaded?.entries.isEmpty == true)

        var stale = PlaybackQueueSnapshot(entries: [occurrence(first)])
        stale.revision = 1
        try await store.save(stale)

        let persisted = await store.load()
        XCTAssertEqual(persisted?.revision, 41)
        XCTAssertTrue(persisted?.entries.isEmpty == true)
    }

    func testCorruptSnapshotIsIgnoredWithoutTouchingOtherData() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVQueueCorrupt-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not-json".utf8).write(to: url, options: .atomic)

        let store = PlaybackQueueSnapshotStore(url: url)
        let restored = await store.load()
        XCTAssertNil(restored)
    }

    func testMalformedBaseOrderIsRejectedAndCannotRestoreOverQueue() async throws {
        let current = occurrence(first)
        var malformed = PlaybackQueueSnapshot(entries: [current, occurrence(second)], currentIndex: 0, shuffleEnabled: true)
        malformed.baseEntries[1] = PlaybackQueueOccurrence(occurrenceID: UUID(), trackID: third)
        XCTAssertFalse(PlaybackQueuePlanner.isWellFormed(malformed))
        XCTAssertEqual(PlaybackQueuePlanner.restoreBaseOrder(malformed).entries, malformed.entries)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVQueueMalformed-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try JSONEncoder().encode(malformed).write(to: url, options: .atomic)
        let store = PlaybackQueueSnapshotStore(url: url)
        let restored = await store.load()
        XCTAssertNil(restored)
    }

    @MainActor
    func testEngineRestoresPersistedBaseFutureOrderWhenShuffleTurnsOff() async throws {
        let currentID = UUID()
        let nextID = UUID()
        let lastID = UUID()
        let current = Track(
            id: currentID, sourceID: UUID(), relativePath: "current.m4a",
            fileIdentifier: "current", title: "Current", fileSize: 1, modifiedAt: .now
        )
        let next = Track(
            id: nextID, sourceID: UUID(), relativePath: "next.m4a",
            fileIdentifier: "next", title: "Next", fileSize: 1, modifiedAt: .now
        )
        let last = Track(
            id: lastID, sourceID: UUID(), relativePath: "last.m4a",
            fileIdentifier: "last", title: "Last", fileSize: 1, modifiedAt: .now
        )
        let currentOccurrence = PlaybackQueueOccurrence(trackID: currentID)
        let nextOccurrence = PlaybackQueueOccurrence(trackID: nextID)
        let lastOccurrence = PlaybackQueueOccurrence(trackID: lastID)
        let snapshot = PlaybackQueueSnapshot(
            entries: [currentOccurrence, lastOccurrence, nextOccurrence],
            baseEntries: [currentOccurrence, nextOccurrence, lastOccurrence],
            currentIndex: 0,
            shuffleEnabled: true
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CMVQueueEngineRestore-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = PlaybackQueueSnapshotStore(url: url)
        try await store.save(snapshot)
        guard let restored = await store.load() else {
            XCTFail("valid queue snapshot should load")
            return
        }

        let tracksByID = [currentID: current, nextID: next, lastID: last]
        let restoredQueue = PlaybackQueue(
            tracks: restored.entries.compactMap { tracksByID[$0.trackID] },
            currentIndex: restored.currentIndex
        )
        let restoredBaseQueue = PlaybackQueue(
            tracks: restored.baseEntries.compactMap { tracksByID[$0.trackID] },
            currentIndex: restored.currentIndex
        )
        let engine = NativePlaybackEngine()
        engine.setQueue(restoredQueue, baseQueue: restoredBaseQueue)
        engine.restoreQueueModes(shuffleEnabled: restored.shuffleEnabled, repeatEnabled: false)
        XCTAssertEqual(engine.baseQueueSnapshot.tracks.map(\.id), [currentID, nextID, lastID])

        engine.toggleShuffle()

        XCTAssertFalse(engine.isShuffleEnabled)
        XCTAssertEqual(engine.queue.tracks.map(\.id), [currentID, nextID, lastID])
        XCTAssertEqual(engine.baseQueueSnapshot.tracks.map(\.id), [currentID, nextID, lastID])
    }
}
