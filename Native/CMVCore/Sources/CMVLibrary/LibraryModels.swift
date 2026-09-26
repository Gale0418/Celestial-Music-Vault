import Foundation
import SwiftData
import CMVDomain

@Model
public final class MediaSourceRecord {
    @Attribute(.unique) public var id: UUID
    public var displayName: String
    @Attribute(.externalStorage) public var bookmarkData: Data
    public var statusRaw: String
    public var lastSuccessfulScan: Date?
    public var updatedAt: Date
    public var pendingReimportRestore: Bool = false
    /// Last picker path is a duplicate-prevention hint, not an authorization.
    public var rootPath: String = ""

    public init(id: UUID = UUID(), displayName: String, bookmarkData: Data,
                status: MediaSourceStatus = .available, now: Date = .now) {
        self.id = id; self.displayName = displayName; self.bookmarkData = bookmarkData
        self.statusRaw = status.rawValue; self.updatedAt = now
    }

    public var status: MediaSourceStatus {
        get { MediaSourceStatus(rawValue: statusRaw) ?? .permissionRequired }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
public final class TrackRecord {
    @Attribute(.unique) public var id: UUID
    public var sourceID: UUID
    public var relativePath: String
    public var fileIdentifier: String
    public var title: String
    public var artist: String
    public var album: String
    public var albumArtist: String
    @Attribute(.externalStorage) public var artworkData: Data?
    public var trackNumber: Int?
    public var discNumber: Int?
    public var duration: Double
    public var fileSize: Int64
    public var modifiedAt: Date
    public var replayGainDB: Double?
    /// Raw storage keeps SwiftData migration lightweight; missing legacy
    /// values are interpreted as audio by `domain`.
    public var mediaKindRaw: String = MediaKind.audio.rawValue
    public var isFavorite: Bool
    public var rating: Int
    public var analysisVersion: Int?
    public var bpm: Double?
    public var musicalKey: String?
    public var integratedLoudnessLUFS: Double?
    public var energy: Double
    public var brightness: Double
    public var playCount: Int
    public var skipCount: Int
    public var lastPlayedAt: Date?
    public var availabilityRaw: String
    public var lastSeenScanID: UUID?
    /// A user-initiated library removal. The source file is preserved and
    /// later scans must not silently add the item back to the visible library.
    public var isExcluded: Bool = false
    /// Bitmask for metadata fields explicitly overridden in CMV. Source scans
    /// update only fields without a user override, so library edits survive a
    /// later re-index without modifying the original media file.
    public var metadataOverrideMask: Int = 0

    static let titleMetadataOverride = 1 << 0
    static let artistMetadataOverride = 1 << 1
    static let albumMetadataOverride = 1 << 2
    static let albumArtistMetadataOverride = 1 << 3
    static let artworkMetadataOverride = 1 << 4
    static let trackNumberMetadataOverride = 1 << 5
    static let discNumberMetadataOverride = 1 << 6

    func hasMetadataOverride(_ bit: Int) -> Bool {
        metadataOverrideMask & bit != 0
    }

    func addMetadataOverride(_ bit: Int) {
        metadataOverrideMask |= bit
    }

    public init(id: UUID = UUID(), sourceID: UUID, file: ScannedMediaFile) {
        self.id = id; self.sourceID = sourceID; self.relativePath = file.relativePath
        self.fileIdentifier = file.fileIdentifier; self.title = file.title
        self.artist = file.artist; self.album = file.album; self.albumArtist = file.albumArtist; self.artworkData = file.artworkData
        self.trackNumber = file.trackNumber; self.discNumber = file.discNumber
        self.duration = file.duration; self.fileSize = file.fileSize; self.modifiedAt = file.modifiedAt
        self.replayGainDB = file.replayGainDB
        self.mediaKindRaw = file.mediaKind.rawValue
        self.isFavorite = false; self.rating = 0; self.playCount = 0; self.skipCount = 0
        self.lastPlayedAt = nil; self.availabilityRaw = MediaAvailability.available.rawValue
        self.analysisVersion = nil; self.bpm = nil; self.musicalKey = nil
        self.integratedLoudnessLUFS = nil; self.energy = 0; self.brightness = 0
    }

    public var domain: Track { domain(includeArtwork: true) }

    public func domain(includeArtwork: Bool) -> Track {
        Track(id: id, sourceID: sourceID, relativePath: relativePath,
              fileIdentifier: fileIdentifier, title: title, artist: artist,
              album: album, albumArtist: albumArtist,
              artworkData: includeArtwork ? artworkData : nil,
              trackNumber: trackNumber, discNumber: discNumber, duration: duration,
              fileSize: fileSize, modifiedAt: modifiedAt, replayGainDB: replayGainDB,
              isFavorite: isFavorite, rating: rating,
              analysis: analysisVersion.map { AnalysisProfile(version: $0, bpm: bpm, musicalKey: musicalKey,
                                                               integratedLoudnessLUFS: integratedLoudnessLUFS,
                                                               energy: energy, brightness: brightness) },
              availability: MediaAvailability(rawValue: availabilityRaw) ?? .missing,
              mediaKind: MediaKind(rawValue: mediaKindRaw) ?? .audio)
    }
}

@Model
public final class PlaylistRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    @Attribute(.externalStorage) public var trackIDsData: Data
    public var createdAt: Date
    public var modifiedAt: Date

    public init(id: UUID = UUID(), name: String, trackIDs: [UUID] = [], now: Date = .now) {
        self.id = id
        self.name = name
        self.trackIDsData = (try? JSONEncoder().encode(trackIDs)) ?? Data("[]".utf8)
        self.createdAt = now
        self.modifiedAt = now
    }

    public var trackIDs: [UUID] {
        get { (try? JSONDecoder().decode([UUID].self, from: trackIDsData)) ?? [] }
        set { trackIDsData = (try? JSONEncoder().encode(newValue)) ?? Data("[]".utf8) }
    }

    public var domain: Playlist {
        Playlist(id: id, name: name, trackIDs: trackIDs, createdAt: createdAt, modifiedAt: modifiedAt)
    }
}
