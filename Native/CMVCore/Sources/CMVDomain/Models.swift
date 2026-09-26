import Foundation

public struct Track: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var sourceID: UUID
    public var relativePath: String
    public var fileIdentifier: String
    public var title: String
    public var artist: String
    public var album: String
    public var albumArtist: String
    public var artworkData: Data?
    public var trackNumber: Int?
    public var discNumber: Int?
    public var duration: TimeInterval
    public var fileSize: Int64
    public var modifiedAt: Date
    public var replayGainDB: Double?
    public var isFavorite: Bool
    public var rating: Int
    public var analysis: AnalysisProfile?
    public var availability: MediaAvailability
    public var mediaKind: MediaKind

    public init(
        id: UUID = UUID(), sourceID: UUID, relativePath: String,
        fileIdentifier: String, title: String, artist: String = "未知歌手",
        album: String = "未知專輯", albumArtist: String = "", artworkData: Data? = nil,
        trackNumber: Int? = nil, discNumber: Int? = nil,
        duration: TimeInterval = 0, fileSize: Int64, modifiedAt: Date,
        replayGainDB: Double? = nil, isFavorite: Bool = false,
        rating: Int = 0, analysis: AnalysisProfile? = nil,
        availability: MediaAvailability = .available,
        mediaKind: MediaKind = .audio
    ) {
        self.id = id
        self.sourceID = sourceID
        self.relativePath = relativePath
        self.fileIdentifier = fileIdentifier
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.artworkData = artworkData
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.duration = duration
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
        self.replayGainDB = replayGainDB
        self.isFavorite = isFavorite
        self.rating = min(5, max(0, rating))
        self.analysis = analysis
        self.availability = availability
        self.mediaKind = mediaKind
    }
}

/// Describes one metadata field in a partial update.
///
/// `.unchanged` leaves the existing value untouched. `.set` replaces it and
/// `.clear` removes it where the stored field is optional; for non-optional
/// text fields, clearing stores an empty string because the model keeps those
/// columns non-optional. Metadata updates only affect the library record and
/// never write back to the source media file.
public enum TrackMetadataField<Value: Equatable & Sendable>: Equatable, Sendable {
    case unchanged
    case set(Value)
    case clear
}

/// Partial metadata update applied to one or more library tracks.
///
/// Fields omitted by the caller remain unchanged. Source identity, file
/// location, playback state, ratings, favorites, and analysis are not part of
/// this patch and are therefore preserved by the repository operation.
public struct TrackMetadataPatch: Equatable, Sendable {
    public var title: TrackMetadataField<String>
    public var artist: TrackMetadataField<String>
    public var album: TrackMetadataField<String>
    public var albumArtist: TrackMetadataField<String>
    public var artworkData: TrackMetadataField<Data>
    public var trackNumber: TrackMetadataField<Int>
    public var discNumber: TrackMetadataField<Int>

    public init(
        title: TrackMetadataField<String> = .unchanged,
        artist: TrackMetadataField<String> = .unchanged,
        album: TrackMetadataField<String> = .unchanged,
        albumArtist: TrackMetadataField<String> = .unchanged,
        artworkData: TrackMetadataField<Data> = .unchanged,
        trackNumber: TrackMetadataField<Int> = .unchanged,
        discNumber: TrackMetadataField<Int> = .unchanged
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.artworkData = artworkData
        self.trackNumber = trackNumber
        self.discNumber = discNumber
    }

    public var hasChanges: Bool {
        title != .unchanged || artist != .unchanged || album != .unchanged ||
            albumArtist != .unchanged || artworkData != .unchanged ||
            trackNumber != .unchanged || discNumber != .unchanged
    }
}

public struct Album: Identifiable, Hashable, Codable, Sendable {
    public var id: String { "\(albumArtist)|\(title)" }
    public var title: String
    public var albumArtist: String
    public var trackCount: Int
    public var duration: TimeInterval
}

public struct Artist: Identifiable, Hashable, Codable, Sendable {
    public var id: String { name }
    public var name: String
    public var trackCount: Int
}

public struct Playlist: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var trackIDs: [UUID]
    public var createdAt: Date
    public var modifiedAt: Date

    public init(id: UUID = UUID(), name: String, trackIDs: [UUID] = [], now: Date = .now,
                createdAt: Date? = nil, modifiedAt: Date? = nil) {
        self.id = id; self.name = name; self.trackIDs = trackIDs
        self.createdAt = createdAt ?? now; self.modifiedAt = modifiedAt ?? now
    }
}

public struct MediaSource: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var displayName: String
    public var bookmarkData: Data
    public var status: MediaSourceStatus
    public var lastSuccessfulScan: Date?

    public init(id: UUID = UUID(), displayName: String, bookmarkData: Data,
                status: MediaSourceStatus = .available, lastSuccessfulScan: Date? = nil) {
        self.id = id; self.displayName = displayName; self.bookmarkData = bookmarkData
        self.status = status; self.lastSuccessfulScan = lastSuccessfulScan
    }
}

public struct PlaybackQueue: Hashable, Codable, Sendable {
    public var tracks: [Track]
    public var currentIndex: Int
    public var current: Track? { tracks.indices.contains(currentIndex) ? tracks[currentIndex] : nil }

    public init(tracks: [Track] = [], currentIndex: Int = 0) {
        self.tracks = tracks
        self.currentIndex = tracks.isEmpty ? 0 : min(max(0, currentIndex), tracks.count - 1)
    }
}

/// Resolves a full mixed-media route position without collapsing repeated IDs
/// to the first occurrence. The preferred index is the occurrence tracked by
/// the playback coordinator; ID lookup is only a legacy/fallback path.
public enum PlaybackRoutePosition {
    public static func resolve(
        routeIDs: [UUID],
        currentID: UUID?,
        preferredIndex: Int?
    ) -> Int? {
        if let preferredIndex,
           routeIDs.indices.contains(preferredIndex),
           (currentID == nil || routeIDs[preferredIndex] == currentID) {
            return preferredIndex
        }
        guard let currentID else { return nil }
        return routeIDs.firstIndex(of: currentID)
    }
}

public struct AnalysisProfile: Hashable, Codable, Sendable {
    public var version: Int
    public var bpm: Double?
    public var musicalKey: String?
    public var integratedLoudnessLUFS: Double?
    public var energy: Double
    public var brightness: Double

    public init(version: Int = 1, bpm: Double? = nil, musicalKey: String? = nil,
                integratedLoudnessLUFS: Double? = nil, energy: Double = 0, brightness: Double = 0) {
        self.version = version; self.bpm = bpm; self.musicalKey = musicalKey
        self.integratedLoudnessLUFS = integratedLoudnessLUFS
        self.energy = energy; self.brightness = brightness
    }
}

public struct CachePolicy: Hashable, Codable, Sendable {
    public var smartBudgetBytes: Int64
    public var prefetchCount: Int
    public init(smartBudgetBytes: Int64 = 10 * 1_024 * 1_024 * 1_024, prefetchCount: Int = 12) {
        self.smartBudgetBytes = max(0, smartBudgetBytes); self.prefetchCount = max(0, prefetchCount)
    }
}

public enum MediaAvailability: String, Codable, Sendable { case available, sourceOffline, missing, permissionRequired }
public enum MediaSourceStatus: String, Codable, Sendable { case available, offline, permissionRequired, scanning }
/// The playable media surface selected by AVFoundation during scanning.
/// `.audio` is the migration/default value for records created before video
/// indexing was introduced.
public enum MediaKind: String, Codable, Hashable, Sendable { case audio, video }

/// Stable library sort fields that can be applied before SwiftData pagination.
/// Random ordering is intentionally owned by the UI generation so one shuffle
/// remains stable while additional pages load.
public enum LibraryTrackSort: String, CaseIterable, Codable, Hashable, Sendable {
    case title
    case artist
    case album
    case modifiedAt
}

public enum LibraryCatalogKind: String, Codable, Hashable, Sendable {
    case artist
    case album
}

public struct LibraryCatalogGroup: Identifiable, Hashable, Sendable {
    public let key: String
    public let count: Int
    public let previewTitles: [String]
    public let sampleArtist: String
    public let sampleAlbum: String
    /// An inexpensive artwork source for the group card. The artwork itself
    /// stays on the track record and is loaded only when a card is visible.
    public let representativeTrackID: UUID?

    public var id: String { key }

    public init(
        key: String,
        count: Int,
        previewTitles: [String],
        sampleArtist: String,
        sampleAlbum: String,
        representativeTrackID: UUID? = nil
    ) {
        self.key = key
        self.count = count
        self.previewTitles = previewTitles
        self.sampleArtist = sampleArtist
        self.sampleAlbum = sampleAlbum
        self.representativeTrackID = representativeTrackID
    }
}
