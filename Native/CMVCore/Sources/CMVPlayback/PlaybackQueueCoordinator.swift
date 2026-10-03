import Foundation
import CMVDomain

/// 一個佇列 occurrence，而非單純的曲目 ID。
/// 同一首歌可在佇列中出現多次，每次都保有自己的 occurrence 身分。
public struct PlaybackQueueOccurrence: Identifiable, Codable, Hashable, Sendable {
    public let occurrenceID: UUID
    public let trackID: UUID

    public var id: UUID { occurrenceID }

    public init(occurrenceID: UUID = UUID(), trackID: UUID) {
        self.occurrenceID = occurrenceID
        self.trackID = trackID
    }
}

public enum PlaybackRepeatMode: String, Codable, Hashable, Sendable {
    case off
    case all
    case one
}

/// 分頁曲庫播放的輕量 continuation。只保存查詢與位置，不保存 Track／Artwork。
public struct PlaybackQueueContinuationSnapshot: Codable, Hashable, Sendable {
    public var query: String
    public var sortRawValue: String?
    public var ascending: Bool
    public var randomTrackIDs: [UUID]?
    public var nextOffset: Int
    public var pageSize: Int
    public var exhausted: Bool

    public init(query: String = "", sortRawValue: String? = nil, ascending: Bool = true,
                randomTrackIDs: [UUID]? = nil, nextOffset: Int = 0, pageSize: Int = 200,
                exhausted: Bool = false) {
        self.query = query
        self.sortRawValue = sortRawValue
        self.ascending = ascending
        self.randomTrackIDs = randomTrackIDs
        self.nextOffset = max(0, nextOffset)
        self.pageSize = max(1, pageSize)
        self.exhausted = exhausted
    }
}

/// 佇列的版本化小 snapshot。資料庫內容永遠不由此型別修改。
public struct PlaybackQueueSnapshot: Codable, Hashable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var revision: Int64
    public var entries: [PlaybackQueueOccurrence]
    /// Original user order, retained while `entries` is shuffled.
    public var baseEntries: [PlaybackQueueOccurrence]
    public var currentIndex: Int
    public var history: [UUID]
    public var continuation: PlaybackQueueContinuationSnapshot?
    public var shuffleEnabled: Bool
    public var repeatMode: PlaybackRepeatMode

    public init(version: Int = PlaybackQueueSnapshot.currentVersion,
                revision: Int64 = 0,
                entries: [PlaybackQueueOccurrence] = [],
                baseEntries: [PlaybackQueueOccurrence]? = nil,
                currentIndex: Int = 0,
                history: [UUID] = [],
                continuation: PlaybackQueueContinuationSnapshot? = nil,
                shuffleEnabled: Bool = false,
                repeatMode: PlaybackRepeatMode = .off) {
        self.version = version
        self.revision = revision
        self.entries = entries
        self.baseEntries = baseEntries ?? entries
        self.currentIndex = entries.isEmpty ? 0 : min(max(0, currentIndex), entries.count - 1)
        self.history = Array(history.suffix(64))
        self.continuation = continuation
        self.shuffleEnabled = shuffleEnabled
        self.repeatMode = repeatMode
    }

    public var current: PlaybackQueueOccurrence? {
        entries.indices.contains(currentIndex) ? entries[currentIndex] : nil
    }
}

/// 純值 queue 操作，供 AppModel 與測試共用。
public enum PlaybackQueuePlanner {
    public static let historyLimit = 64

    public static func append(_ additions: [PlaybackQueueOccurrence], to snapshot: PlaybackQueueSnapshot,
                              playNext: Bool = false) -> PlaybackQueueSnapshot {
        guard !additions.isEmpty else { return snapshot }
        var result = snapshot
        let hadEntries = !result.entries.isEmpty
        let insertion = playNext && !result.entries.isEmpty
            ? min(result.entries.count, result.currentIndex + 1)
            : result.entries.count
        result.entries.insert(contentsOf: additions, at: insertion)
        let baseCurrentIndex = result.current.flatMap { current in
            result.baseEntries.firstIndex { $0.occurrenceID == current.occurrenceID }
        }
        let baseInsertion = playNext && !result.baseEntries.isEmpty
            ? min(result.baseEntries.count, (baseCurrentIndex ?? result.currentIndex) + 1)
            : result.baseEntries.count
        result.baseEntries.insert(contentsOf: additions, at: baseInsertion)
        if hadEntries && insertion <= result.currentIndex {
            result.currentIndex += additions.count
        }
        return result
    }

    /// 只允許調整目前曲目之後的 occurrence，確保正在播放的節點不被搬動。
    public static func move(_ snapshot: PlaybackQueueSnapshot, from source: Int, to destination: Int)
        -> PlaybackQueueSnapshot {
        guard snapshot.entries.indices.contains(source), source > snapshot.currentIndex else { return snapshot }
        let boundary = min(max(snapshot.currentIndex + 1, destination), snapshot.entries.count)
        let target = boundary > source ? boundary - 1 : boundary
        guard target != source else { return snapshot }
        var result = snapshot
        let item = result.entries.remove(at: source)
        result.entries.insert(item, at: target)
        if !snapshot.shuffleEnabled { result.baseEntries = result.entries }
        return result
    }

    /// 移除指定 occurrence；目前播放中的項目不會被這個純 queue 操作刪除。
    public static func remove(_ snapshot: PlaybackQueueSnapshot, at index: Int)
        -> PlaybackQueueSnapshot {
        guard snapshot.entries.indices.contains(index), index != snapshot.currentIndex else { return snapshot }
        var result = snapshot
        let removed = result.entries.remove(at: index)
        result.baseEntries.removeAll { $0.occurrenceID == removed.occurrenceID }
        if index < result.currentIndex { result.currentIndex -= 1 }
        result.currentIndex = result.entries.isEmpty ? 0 : min(result.currentIndex, result.entries.count - 1)
        return result
    }

    public static func recordPlayed(_ occurrenceID: UUID, in snapshot: PlaybackQueueSnapshot)
        -> PlaybackQueueSnapshot {
        var result = snapshot
        result.history.removeAll { $0 == occurrenceID }
        result.history.append(occurrenceID)
        if result.history.count > historyLimit {
            result.history.removeFirst(result.history.count - historyLimit)
        }
        return result
    }

    public static func nextIndex(in snapshot: PlaybackQueueSnapshot) -> Int? {
        guard !snapshot.entries.isEmpty else { return nil }
        switch snapshot.repeatMode {
        case .one:
            return snapshot.currentIndex
        case .all:
            return snapshot.currentIndex + 1 < snapshot.entries.count ? snapshot.currentIndex + 1 : 0
        case .off:
            guard snapshot.currentIndex + 1 < snapshot.entries.count else { return nil }
            return snapshot.currentIndex + 1
        }
    }

    /// 以 occurrence 身分去除重排後的隨機順序，回到原始 base order。
    public static func restoreBaseOrder(_ snapshot: PlaybackQueueSnapshot) -> PlaybackQueueSnapshot {
        guard snapshot.shuffleEnabled, isWellFormed(snapshot) else { return snapshot }
        guard let current = snapshot.current else { return snapshot }
        var result = snapshot
        let currentID = current.occurrenceID
        let base = snapshot.baseEntries
        result.entries = base
        result.currentIndex = base.firstIndex { $0.occurrenceID == currentID } ?? 0
        result.shuffleEnabled = false
        return result
    }

    public static func isWellFormed(_ snapshot: PlaybackQueueSnapshot) -> Bool {
        guard snapshot.version == PlaybackQueueSnapshot.currentVersion,
              snapshot.revision >= 0,
              snapshot.entries.count <= 100_000,
              snapshot.currentIndex >= 0,
              snapshot.entries.isEmpty || snapshot.currentIndex < snapshot.entries.count,
              snapshot.baseEntries.count == snapshot.entries.count,
              snapshot.history.count <= historyLimit else { return false }
        var entriesByOccurrence: [UUID: UUID] = [:]
        for entry in snapshot.entries {
            guard entriesByOccurrence[entry.occurrenceID] == nil else { return false }
            entriesByOccurrence[entry.occurrenceID] = entry.trackID
        }
        var baseByOccurrence: [UUID: UUID] = [:]
        for entry in snapshot.baseEntries {
            guard baseByOccurrence[entry.occurrenceID] == nil else { return false }
            baseByOccurrence[entry.occurrenceID] = entry.trackID
        }
        guard entriesByOccurrence.count == snapshot.entries.count,
              entriesByOccurrence == baseByOccurrence,
              Set(snapshot.history).isSubset(of: Set(entriesByOccurrence.keys)) else { return false }
        if let continuation = snapshot.continuation {
            guard continuation.query.utf8.count <= 4_096,
                  continuation.nextOffset >= 0,
                  continuation.pageSize > 0,
                  continuation.pageSize <= 10_000,
                  continuation.randomTrackIDs?.count ?? 0 <= 100_000 else { return false }
            if let sortRawValue = continuation.sortRawValue,
               LibraryTrackSort(rawValue: sortRawValue) == nil { return false }
        }
        return true
    }
}

/// 只處理 queue JSON 的 actor。損壞或舊版本資料會被忽略，不接觸曲庫。
public actor PlaybackQueueSnapshotStore {
    private let url: URL
    private var latestRevision: Int64 = .min

    public init(url: URL) { self.url = url }

    public static func defaultStore(fileManager: FileManager = .default) -> PlaybackQueueSnapshotStore {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return PlaybackQueueSnapshotStore(
            url: root.appendingPathComponent("CMV", isDirectory: true)
                .appendingPathComponent("playback-queue-v1.json")
        )
    }

    public func load() -> PlaybackQueueSnapshot? {
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(PlaybackQueueSnapshot.self, from: data),
              snapshot.version == PlaybackQueueSnapshot.currentVersion,
              PlaybackQueuePlanner.isWellFormed(snapshot) else { return nil }
        latestRevision = max(latestRevision, snapshot.revision)
        return snapshot
    }

    public func save(_ snapshot: PlaybackQueueSnapshot) throws {
        guard snapshot.version == PlaybackQueueSnapshot.currentVersion,
              PlaybackQueuePlanner.isWellFormed(snapshot),
              snapshot.revision >= latestRevision else { return }
        let data = try JSONEncoder().encode(snapshot)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        latestRevision = snapshot.revision
    }
}
