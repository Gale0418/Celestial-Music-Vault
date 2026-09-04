import Foundation

public struct ScanProgress: Sendable, Equatable {
    public var discovered: Int
    public var processed: Int
    public var currentPath: String
    public init(discovered: Int, processed: Int, currentPath: String) {
        self.discovered = discovered; self.processed = processed; self.currentPath = currentPath
    }
}

public struct PlaybackEvent: Sendable, Equatable {
    public enum Kind: Sendable, Equatable { case started, paused, advanced, failed(String) }
    public var kind: Kind
    public var trackID: UUID?
    public init(kind: Kind, trackID: UUID? = nil) { self.kind = kind; self.trackID = trackID }
}

public protocol MediaSourceProvider: Sendable {
    func makeBookmark(for url: URL) throws -> Data
    func resolve(bookmark: Data) throws -> URL
    func status(for bookmark: Data) async -> MediaSourceStatus
}

public protocol LibraryRepository: Sendable {
    func tracks(matching query: String, sort: LibraryTrackSort, ascending: Bool, limit: Int, offset: Int) async throws -> [Track]
    func trackIDs(matching query: String, sort: LibraryTrackSort, ascending: Bool) async throws -> [UUID]
    func tracks(ids: [UUID]) async throws -> [Track]
    func excludeTracks(ids: [UUID]) async throws
    func restoreTracks(ids: [UUID]) async throws
    func restoreTracks(ids: [UUID], playlistTrackIDs: [UUID: [UUID]]) async throws
    func applyScan(_ files: [ScannedMediaFile], sourceID: UUID, sourceWasReachable: Bool) async throws
    func setFavorite(trackID: UUID, isFavorite: Bool) async throws
    func setRating(trackID: UUID, rating: Int) async throws
    func recordPlayback(trackID: UUID, skipped: Bool) async throws
    func setAnalysis(trackID: UUID, profile: AnalysisProfile) async throws
    func playlists() async throws -> [Playlist]
    func createPlaylist(name: String) async throws -> Playlist
    func renamePlaylist(id: UUID, name: String) async throws
    func deletePlaylist(id: UUID) async throws
    func addTrack(trackID: UUID, toPlaylist id: UUID) async throws
    func addTracks(trackIDs: [UUID], toPlaylist id: UUID) async throws
    func removeTrack(trackID: UUID, fromPlaylist id: UUID) async throws
}

@MainActor
public protocol PlaybackEngine: AnyObject {
    var queue: PlaybackQueue { get }
    var isPlaying: Bool { get }
    var sleepTimerEndDate: Date? { get }
    func load(_ queue: PlaybackQueue, resolvedURLs: [UUID: URL]) async throws
    func play() throws
    func pause()
    func setSleepTimer(minutes: Int)
    func cancelSleepTimer()
    func seek(to seconds: TimeInterval)
    func skipForward() throws
    func setEQ(enabled: Bool, gains: [Float])
}

public protocol AudioAnalyzer: Sendable {
    func analyze(trackID: UUID, url: URL) async throws -> AnalysisProfile
    func cancel(trackID: UUID) async
}

public protocol OfflineCacheStore: Sendable {
    func pin(trackID: UUID, sourceURL: URL) async throws -> URL
    func unpin(trackID: UUID) async throws
    func isPinned(trackID: UUID) async -> Bool
    /// Returns a checksum-verified local copy, preferring pinned media over
    /// evictable smart-cache media. A nil result means the source must be
    /// resolved again; callers must never treat an unverified file as audio.
    func cachedURL(trackID: UUID) async -> URL?
    func prefetch(trackID: UUID, sourceURL: URL) async throws -> URL
    func trim(to budgetBytes: Int64) async throws
    func verify(trackID: UUID) async -> Bool
}

/// Value-only input for deterministic smart-cache eviction. The planner never
/// owns files; it only returns identifiers that the cache actor may remove.
public struct CacheEvictionEntry: Equatable, Sendable {
    public var identifier: String
    public var sizeBytes: Int64
    public var pinned: Bool
    public var lastAccessOrder: UInt64

    public init(identifier: String, sizeBytes: Int64, pinned: Bool = false, lastAccessOrder: UInt64) {
        self.identifier = identifier
        self.sizeBytes = sizeBytes
        self.pinned = pinned
        self.lastAccessOrder = lastAccessOrder
    }
}

public protocol CacheEvictionPlanner: Sendable {
    func plan(entries: [CacheEvictionEntry], budgetBytes: Int64) -> [String]
}

/// First-party fallback used by the Swift package tests and non-App clients.
/// The app injects the Rust implementation at its platform boundary.
public struct DeterministicCacheEvictionPlanner: CacheEvictionPlanner {
    public init() {}

    public func plan(entries: [CacheEvictionEntry], budgetBytes: Int64) -> [String] {
        // A cache manifest is external state and can contain values whose
        // aggregate exceeds Int64.max. Decimal keeps the fallback exact instead
        // of trapping in debug or wrapping in optimized builds; Rust uses u128
        // for the same reason on the primary path.
        var total = entries.reduce(Decimal(0)) { partial, entry in
            partial + Decimal(max(0, entry.sizeBytes))
        }
        let budget = Decimal(max(0, budgetBytes))
        let candidates = entries.filter { !$0.pinned }
            .sorted { ($0.lastAccessOrder, $0.identifier) < ($1.lastAccessOrder, $1.identifier) }
        var result: [String] = []
        var index = 0
        while total > budget, index < candidates.count {
            let entry = candidates[index]
            index += 1
            result.append(entry.identifier)
            total -= Decimal(max(0, entry.sizeBytes))
        }
        return result
    }
}

public protocol SmartDJService: Sendable {
    func makeQueue(from tracks: [Track], profiles: [UUID: AnalysisProfile], history: [UUID: ListeningSignal], limit: Int) async -> [DJSelection]
}

public struct ScannedMediaFile: Hashable, Sendable {
    public var relativePath: String
    public var fileIdentifier: String
    public var fileSize: Int64
    public var modifiedAt: Date
    public var title: String
    public var artist: String
    public var album: String
    public var albumArtist: String
    public var artworkData: Data?
    public var trackNumber: Int?
    public var discNumber: Int?
    public var duration: TimeInterval
    public var replayGainDB: Double?
    public var mediaKind: MediaKind
    public init(relativePath: String, fileIdentifier: String, fileSize: Int64, modifiedAt: Date, title: String,
                artist: String = "未知歌手", album: String = "未知專輯", albumArtist: String = "", artworkData: Data? = nil,
                trackNumber: Int? = nil, discNumber: Int? = nil, duration: TimeInterval = 0,
                replayGainDB: Double? = nil, mediaKind: MediaKind = .audio) {
        self.relativePath = relativePath; self.fileIdentifier = fileIdentifier
        self.fileSize = fileSize; self.modifiedAt = modifiedAt; self.title = title
        self.artist = artist; self.album = album; self.albumArtist = albumArtist; self.artworkData = artworkData
        self.trackNumber = trackNumber; self.discNumber = discNumber
        self.duration = duration; self.replayGainDB = replayGainDB; self.mediaKind = mediaKind
    }
}

public struct ListeningSignal: Hashable, Codable, Sendable {
    public var playCount: Int
    public var skipCount: Int
    public var lastPlayedAt: Date?
    public init(playCount: Int = 0, skipCount: Int = 0, lastPlayedAt: Date? = nil) {
        self.playCount = playCount; self.skipCount = skipCount; self.lastPlayedAt = lastPlayedAt
    }
}

public struct DJSelection: Identifiable, Hashable, Sendable {
    public var id: UUID { track.id }
    public var track: Track
    public var score: Double
    public var reasons: [String]
    public init(track: Track, score: Double, reasons: [String]) {
        self.track = track; self.score = score; self.reasons = reasons
    }
}