import Foundation
import SwiftData
import CMVDomain

public enum LibraryRepositoryError: Error, Equatable, Sendable {
    case invalidReconciliation
    case invalidMetadata
    case metadataUndoConflict([UUID])
    case trackNotFound(UUID)
    case playlistNotFound(UUID)
    case invalidPlaylistName
    case invalidPlaylistPermutation
}

public struct LibrarySearchCandidate: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let artist: String
    public let album: String
    public let isFavorite: Bool
    public let rating: Int

    public init(
        id: UUID,
        title: String,
        artist: String,
        album: String,
        isFavorite: Bool,
        rating: Int
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.isFavorite = isFavorite
        self.rating = rating
    }
}

public struct PlaylistTrackEntry: Identifiable, Sendable {
    public let track: Track
    public let isExcluded: Bool
    public var id: UUID { track.id }

    public init(track: Track, isExcluded: Bool) {
        self.track = track
        self.isExcluded = isExcluded
    }
}

/// Compact value snapshot for scan reconciliation. Artwork and playback
/// history are intentionally omitted from the 50k-track hot path.
public struct ScanTrackSnapshot: Sendable {
    public let fileIdentifier: String
    public let relativePath: String
    public let fileSize: Int64
    public let modifiedAt: Date
    public let title: String
    public let availability: MediaAvailability
}

public actor SwiftDataLibraryRepository: LibraryRepository {
    private let worker: LibraryDataActor

    public init(container: ModelContainer) {
        worker = LibraryDataActor(modelContainer: container)
    }

    public func tracks(matching query: String, sort: LibraryTrackSort, ascending: Bool,
                       limit: Int, offset: Int) async throws -> [Track] {
        try await tracks(matching: query, sort: sort, ascending: ascending,
                         limit: limit, offset: offset, includeArtwork: true)
    }

    public func tracks(
        matching query: String,
        sort: LibraryTrackSort = .title,
        ascending: Bool = true,
        limit: Int,
        offset: Int,
        includeArtwork: Bool = true
    ) async throws -> [Track] {
        try await worker.tracks(matching: query, sort: sort, ascending: ascending, limit: limit, offset: offset, includeArtwork: includeArtwork)
    }

    public func trackIDs(
        matching query: String,
        sort: LibraryTrackSort = .title,
        ascending: Bool = true
    ) async throws -> [UUID] {
        try await worker.trackIDs(matching: query, sort: sort, ascending: ascending)
    }

    public func tracks(ids: [UUID]) async throws -> [Track] {
        try await worker.tracks(ids: ids)
    }

    public func tracks(ids: [UUID], includeArtwork: Bool) async throws -> [Track] {
        try await worker.tracks(ids: ids, includeArtwork: includeArtwork)
    }

    public func trackCount() async throws -> Int {
        try await worker.trackCount()
    }

    public func playlistEntries(ids: [UUID], includeArtwork: Bool = true) async throws -> [PlaylistTrackEntry] {
        try await worker.playlistEntries(ids: ids, includeArtwork: includeArtwork)
    }

    public func missingPlaylistTrackIDs(ids: [UUID]) async throws -> Set<UUID> {
        try await worker.missingPlaylistTrackIDs(ids: ids)
    }

    public func catalogGroups(kind: LibraryCatalogKind) async throws -> [LibraryCatalogGroup] {
        try await worker.catalogGroups(kind: kind)
    }

    public func catalogGroupTrackIDs(kind: LibraryCatalogKind, key: String) async throws -> [UUID] {
        try await worker.catalogGroupTrackIDs(kind: kind, key: key)
    }

    public func searchCandidates(matching query: String) async throws -> [LibrarySearchCandidate] {
        try await worker.searchCandidates(matching: query)
    }

    public func excludeTracks(ids: [UUID]) async throws {
        try await worker.excludeTracks(ids: ids)
    }

    public func restoreTracks(ids: [UUID]) async throws {
        try await worker.restoreTracks(ids: ids)
    }

    public func restoreTracks(ids: [UUID], playlistTrackIDs: [UUID: [UUID]]) async throws {
        try await worker.restoreTracks(ids: ids, playlistTrackIDs: playlistTrackIDs)
    }

    @discardableResult
    public func repairDuplicateTracksByRelativePath(sourceIDs: [UUID]) async throws -> Int {
        try await worker.repairDuplicateTracksByRelativePath(sourceIDs: sourceIDs)
    }

    /// An explicit re-import of a known folder means the user wants that
    /// source back in the visible library. Playlist membership is intentionally
    /// not reconstructed because a prior removal may have been selective.
    @discardableResult
    public func restoreTracks(sourceID: UUID) async throws -> Int {
        try await worker.restoreTracks(sourceID: sourceID)
    }

    /// Re-import restores only files actually observed in a completed scan.
    /// Old excluded rows for deleted files must not reappear in the library.
    @discardableResult
    public func restoreTracks(sourceID: UUID, seenIdentifiers: Set<String>, scanID: UUID? = nil) async throws -> Int {
        try await worker.restoreTracks(sourceID: sourceID, seenIdentifiers: seenIdentifiers, scanID: scanID)
    }

    public func tracks(sourceID: UUID) async throws -> [Track] {
        try await worker.tracks(sourceID: sourceID)
    }

    public func scanSnapshots(sourceID: UUID) async throws -> [ScanTrackSnapshot] {
        try await worker.scanSnapshots(sourceID: sourceID)
    }

    public func favoriteTracks(limit: Int, offset: Int) async throws -> [Track] {
        try await worker.favoriteTracks(limit: limit, offset: offset)
    }

    public func applyReconciliation(
        upserts: [ScannedMediaFile],
        missingIdentifiers: [String],
        sourceID: UUID,
        scanID: UUID? = nil
    ) async throws {
        try await worker.applyReconciliation(
            upserts: upserts,
            missingIdentifiers: missingIdentifiers,
            sourceID: sourceID,
            expectedScanID: scanID
        )
    }

    public func beginScan(sourceID: UUID) async -> UUID {
        await worker.beginScan(sourceID: sourceID)
    }

    public func invalidateScan(sourceID: UUID) async {
        await worker.invalidateScan(sourceID: sourceID)
    }

    public func applyScanBatch(_ files: [ScannedMediaFile], sourceID: UUID, scanID: UUID) async throws {
        try await worker.applyScanBatch(files, sourceID: sourceID, scanID: scanID)
    }

    public func finishScan(sourceID: UUID, scanID: UUID, sourceWasReachable: Bool) async throws {
        try await worker.finishScan(sourceID: sourceID, scanID: scanID, sourceWasReachable: sourceWasReachable)
    }

    public func applyScan(_ files: [ScannedMediaFile], sourceID: UUID, sourceWasReachable: Bool) async throws {
        let scanID = await beginScan(sourceID: sourceID)
        for start in stride(from: 0, to: files.count, by: 400) {
            let end = min(start + 400, files.count)
            try await applyScanBatch(Array(files[start..<end]), sourceID: sourceID, scanID: scanID)
        }
        try await finishScan(sourceID: sourceID, scanID: scanID, sourceWasReachable: sourceWasReachable)
    }

    public func setFavorite(trackID: UUID, isFavorite: Bool) async throws {
        try await worker.setFavorite(trackID: trackID, isFavorite: isFavorite)
    }

    public func setRating(trackID: UUID, rating: Int) async throws {
        try await worker.setRating(trackID: trackID, rating: rating)
    }

    public func updateMetadata(for trackIDs: [UUID], with patch: TrackMetadataPatch) async throws {
        try await worker.updateMetadata(for: trackIDs, with: patch)
    }

    public func previewMetadata(for trackIDs: [UUID], with patch: TrackMetadataPatch) async throws -> [MetadataPreview] {
        try await worker.previewMetadata(for: trackIDs, with: patch)
    }

    public func updateMetadataWithUndo(for trackIDs: [UUID], with patch: TrackMetadataPatch) async throws -> MetadataUndoReceipt {
        try await worker.updateMetadataWithUndo(for: trackIDs, with: patch)
    }

    public func undoMetadata(_ receipt: MetadataUndoReceipt) async throws -> MetadataUndoResult {
        try await worker.undoMetadata(receipt)
    }

    public func recordPlayback(trackID: UUID, skipped: Bool) async throws {
        try await worker.recordPlayback(trackID: trackID, skipped: skipped)
    }

    public func setAnalysis(trackID: UUID, profile: AnalysisProfile) async throws {
        try await worker.setAnalysis(trackID: trackID, profile: profile)
    }

    public func playlists() async throws -> [Playlist] {
        try await worker.playlists()
    }

    public func createPlaylist(name: String) async throws -> Playlist {
        try await worker.createPlaylist(name: name)
    }

    public func renamePlaylist(id: UUID, name: String) async throws {
        try await worker.renamePlaylist(id: id, name: name)
    }

    public func deletePlaylist(id: UUID) async throws {
        try await worker.deletePlaylist(id: id)
    }

    public func addTrack(trackID: UUID, toPlaylist id: UUID) async throws {
        try await worker.addTrack(trackID: trackID, toPlaylist: id)
    }

    public func addTracks(trackIDs: [UUID], toPlaylist id: UUID) async throws {
        try await worker.addTracks(trackIDs: trackIDs, toPlaylist: id)
    }

    public func removeTrack(trackID: UUID, fromPlaylist id: UUID) async throws {
        try await worker.removeTrack(trackID: trackID, fromPlaylist: id)
    }

    public func removeTracks(trackIDs: [UUID], fromPlaylist id: UUID) async throws {
        try await worker.removeTracks(trackIDs: trackIDs, fromPlaylist: id)
    }

    public func reorderPlaylist(id: UUID, trackIDs: [UUID]) async throws {
        try await worker.reorderPlaylist(id: id, trackIDs: trackIDs)
    }

    @discardableResult
    public func removeUnavailableTracks(fromPlaylist id: UUID, playableMissingIDs: Set<UUID> = []) async throws -> Int {
        try await worker.removeUnavailableTracks(fromPlaylist: id, playableMissingIDs: playableMissingIDs)
    }
}

@ModelActor
public actor LibraryDataActor {
    private struct SearchEntry: Sendable {
        let id: UUID
        let title: String
        let artist: String
        let album: String
        let displayArtist: String
        let displayAlbum: String
        let sortTitle: String
        let albumArtist: String
        let genre: String
        let discNumber: Int
        let trackNumber: Int
        let duration: TimeInterval
        let releaseDate: Date?
        let addedAt: Date
        let modifiedAt: Date
        let isFavorite: Bool
        let rating: Int
    }

    private struct SearchQueryKey: Hashable, Sendable {
        let tokens: [String]
    }

    private struct PagedSortKey: Hashable {
        let sort: LibraryTrackSort
        let ascending: Bool
    }

    private struct DuplicatePathKey: Hashable {
        let sourceID: UUID
        let relativePath: String
    }

    private struct SearchMatchCache: Sendable {
        let key: SearchQueryKey
        let matchingIDs: [UUID]
    }

    private struct CatalogAccumulator {
        let key: String
        var count = 0
        var previewTitles: [String] = []
        var sampleArtist = ""
        var sampleAlbum = ""
        var representativeTrackID: UUID?

        mutating func append(_ record: TrackRecord) {
            if count == 0 {
                sampleArtist = record.artist
                sampleAlbum = record.album
                representativeTrackID = record.id
            }
            count += 1
            if previewTitles.count < 3 { previewTitles.append(record.title) }
        }
    }

    private var searchIndex: [UUID: SearchEntry] = [:]
    private var searchIndexLoaded = false
    private var searchMatchCache: SearchMatchCache?
    private var activeScanIDs: [UUID: UUID] = [:]
    private var orderedTrackIDsBySort: [PagedSortKey: [UUID]] = [:]

    public func tracks(
        matching query: String,
        sort: LibraryTrackSort = .title,
        ascending: Bool = true,
        limit: Int,
        offset: Int,
        includeArtwork: Bool = true
    ) throws -> [Track] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty {
            try ensureSearchIndex()
            let queryTokens = Self.queryTokens(Self.searchValue(normalized))
            // The previous exact-token posting-list shortcut conflicted with
            // substring search semantics: a query token such as "love" could
            // exclude "Lovely" whenever some unrelated record happened to
            // contain the exact token "love". The normalized 50k index is
            // already reused across queries, so scan that compact value index
            // and preserve correctness deterministically.
            let matchingIDs = Self.sorted(
                matchingEntries(queryTokens: queryTokens),
                by: sort,
                ascending: ascending
            )
                .dropFirst(max(0, offset))
                .prefix(max(1, limit))
                .map(\.id)
            var descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { record in
                matchingIDs.contains(record.id)
            })
            if !includeArtwork { descriptor.propertiesToFetch = Self.trackPropertiesWithoutArtwork }
            let byID = Dictionary(uniqueKeysWithValues: try modelContext.fetch(descriptor).map { ($0.id, $0.domain(includeArtwork: includeArtwork)) })
            return matchingIDs.compactMap { byID[$0] }
        }

        let sortKey = PagedSortKey(sort: sort, ascending: ascending)
        if offset >= 2_000 || orderedTrackIDsBySort[sortKey] != nil {
            let orderedIDs: [UUID]
            if let cached = orderedTrackIDsBySort[sortKey] {
                orderedIDs = cached
            } else {
                var idsDescriptor = FetchDescriptor<TrackRecord>(
                    predicate: #Predicate { !$0.isExcluded },
                    sortBy: Self.sortDescriptors(for: sort, ascending: ascending)
                )
                idsDescriptor.propertiesToFetch = [\TrackRecord.id]
                orderedIDs = try modelContext.fetch(idsDescriptor).map(\.id)
                orderedTrackIDsBySort[sortKey] = orderedIDs
            }
            let start = min(max(0, offset), orderedIDs.count)
            let end = start + min(max(1, limit), orderedIDs.count - start)
            guard start < end else { return [] }
            let pageIDs = Array(orderedIDs[start..<end])
            var pageDescriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { record in
                pageIDs.contains(record.id)
            })
            if !includeArtwork { pageDescriptor.propertiesToFetch = Self.trackPropertiesWithoutArtwork }
            let byID = Dictionary(uniqueKeysWithValues: try modelContext.fetch(pageDescriptor).map {
                ($0.id, $0.domain(includeArtwork: includeArtwork))
            })
            return pageIDs.compactMap { byID[$0] }
        }

        var descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { !$0.isExcluded })
        descriptor.fetchLimit = max(1, limit)
        descriptor.fetchOffset = max(0, offset)
        descriptor.sortBy = Self.sortDescriptors(for: sort, ascending: ascending)
        if !includeArtwork { descriptor.propertiesToFetch = Self.trackPropertiesWithoutArtwork }
        return try modelContext.fetch(descriptor).map { $0.domain(includeArtwork: includeArtwork) }
    }

    public func trackIDs(
        matching query: String,
        sort: LibraryTrackSort = .title,
        ascending: Bool = true
    ) throws -> [UUID] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            var descriptor = FetchDescriptor<TrackRecord>(
                predicate: #Predicate { !$0.isExcluded },
                sortBy: Self.sortDescriptors(for: sort, ascending: ascending)
            )
            descriptor.propertiesToFetch = [\TrackRecord.id]
            return try modelContext.fetch(descriptor).map(\.id)
        }

        try ensureSearchIndex()
        let queryTokens = Self.queryTokens(Self.searchValue(normalized))
        return Self.sorted(
            matchingEntries(queryTokens: queryTokens),
            by: sort,
            ascending: ascending
        ).map(\.id)
    }

    public func searchCandidates(matching query: String) throws -> [LibrarySearchCandidate] {
        try ensureSearchIndex()
        let queryTokens = Self.queryTokens(Self.searchValue(
            query.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        return matchingEntries(queryTokens: queryTokens).map { entry in
            return LibrarySearchCandidate(
                id: entry.id,
                title: entry.sortTitle,
                artist: entry.displayArtist,
                album: entry.displayAlbum,
                isFavorite: entry.isFavorite,
                rating: entry.rating
            )
        }
    }

    public func tracks(sourceID: UUID) throws -> [Track] {
        let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { record in
            record.sourceID == sourceID
        })
        return try modelContext.fetch(descriptor).map(\.domain)
    }

    public func trackCount() throws -> Int {
        let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { !$0.isExcluded })
        return try modelContext.fetchCount(descriptor)
    }

    public func scanSnapshots(sourceID: UUID) throws -> [ScanTrackSnapshot] {
        var descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { $0.sourceID == sourceID })
        descriptor.propertiesToFetch = [
            \.fileIdentifier, \.relativePath, \.fileSize, \.modifiedAt, \.title, \.availabilityRaw
        ]
        var snapshots: [ScanTrackSnapshot] = []
        try modelContext.enumerate(descriptor, batchSize: 500) { record in
            snapshots.append(ScanTrackSnapshot(
                fileIdentifier: record.fileIdentifier,
                relativePath: record.relativePath,
                fileSize: record.fileSize,
                modifiedAt: record.modifiedAt,
                title: record.title,
                availability: MediaAvailability(rawValue: record.availabilityRaw) ?? .missing
            ))
        }
        return snapshots
    }

    public func tracks(ids: [UUID], includeArtwork: Bool = true) throws -> [Track] {
        guard !ids.isEmpty else { return [] }
        var byID: [UUID: Track] = [:]
        byID.reserveCapacity(ids.count)
        for start in stride(from: 0, to: ids.count, by: 400) {
            let batch = Array(ids[start..<min(start + 400, ids.count)])
            var descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { record in
                batch.contains(record.id) && !record.isExcluded
            })
            if !includeArtwork { descriptor.propertiesToFetch = Self.trackPropertiesWithoutArtwork }
            for record in try modelContext.fetch(descriptor) {
                byID[record.id] = record.domain(includeArtwork: includeArtwork)
            }
        }
        return ids.compactMap { byID[$0] }
    }

    public func playlistEntries(ids: [UUID], includeArtwork: Bool = true) throws -> [PlaylistTrackEntry] {
        guard !ids.isEmpty else { return [] }
        var byID: [UUID: PlaylistTrackEntry] = [:]
        byID.reserveCapacity(ids.count)
        for start in stride(from: 0, to: ids.count, by: 400) {
            let batch = Array(ids[start..<min(start + 400, ids.count)])
            var descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { batch.contains($0.id) })
            if !includeArtwork { descriptor.propertiesToFetch = Self.trackPropertiesWithoutArtwork }
            for record in try modelContext.fetch(descriptor) {
                byID[record.id] = PlaylistTrackEntry(track: record.domain(includeArtwork: includeArtwork), isExcluded: record.isExcluded)
            }
        }
        return ids.compactMap { byID[$0] }
    }

    public func missingPlaylistTrackIDs(ids: [UUID]) throws -> Set<UUID> {
        let states = try playlistAvailability(ids: ids)
        return Set(states.compactMap { id, state in
            !state.isExcluded && state.availability == .missing ? id : nil
        })
    }

    public func catalogGroups(kind: LibraryCatalogKind) throws -> [LibraryCatalogGroup] {
        var descriptor = FetchDescriptor<TrackRecord>(
            predicate: #Predicate { !$0.isExcluded },
            sortBy: Self.sortDescriptors(for: .title, ascending: true)
        )
        descriptor.propertiesToFetch = [
            \.id, \.title, \.artist, \.album, \.albumArtist, \.isExcluded
        ]
        var grouped: [String: CatalogAccumulator] = [:]
        try modelContext.enumerate(descriptor, batchSize: 500) { record in
            try Task.checkCancellation()
            let key = Self.catalogKey(for: record, kind: kind)
            grouped[key, default: CatalogAccumulator(key: key)].append(record)
        }
        return grouped.values.map {
            LibraryCatalogGroup(
                key: $0.key,
                count: $0.count,
                previewTitles: $0.previewTitles,
                sampleArtist: $0.sampleArtist,
                sampleAlbum: $0.sampleAlbum,
                representativeTrackID: $0.representativeTrackID
            )
        }
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
    }

    public func catalogGroupTrackIDs(kind: LibraryCatalogKind, key: String) throws -> [UUID] {
        var descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { !$0.isExcluded })
        descriptor.propertiesToFetch = [\.id, \.title, \.artist, \.album, \.albumArtist, \.discNumber, \.trackNumber, \.isExcluded]
        var matches: [(id: UUID, disc: Int, track: Int, title: String)] = []
        try modelContext.enumerate(descriptor, batchSize: 500) { record in
            try Task.checkCancellation()
            guard Self.catalogKey(for: record, kind: kind) == key else { return }
            matches.append((record.id, record.discNumber ?? 0, record.trackNumber ?? 0, record.title))
        }
        matches.sort { lhs, rhs in
            if kind == .album {
                if lhs.disc != rhs.disc { return lhs.disc < rhs.disc }
                if lhs.track != rhs.track { return lhs.track < rhs.track }
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        return matches.map(\.id)
    }

    public func favoriteTracks(limit: Int, offset: Int) throws -> [Track] {
        var descriptor = FetchDescriptor<TrackRecord>(
            predicate: #Predicate { $0.isFavorite && !$0.isExcluded },
            sortBy: [SortDescriptor(\.title)]
        )
        descriptor.fetchLimit = max(1, limit)
        descriptor.fetchOffset = max(0, offset)
        return try modelContext.fetch(descriptor).map(\.domain)
    }

    public func excludeTracks(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        do {
            for start in stride(from: 0, to: ids.count, by: 400) {
                let batch = Array(ids[start..<min(start + 400, ids.count)])
                let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { batch.contains($0.id) })
                for record in try modelContext.fetch(descriptor) { record.isExcluded = true }
            }

            // Library visibility and playlist membership are independent.
            // Keep the reference so a later re-import can restore its place.
            try saveChanges()
            if searchIndexLoaded { ids.forEach(removeFromSearchIndex) }
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    public func restoreTracks(ids: [UUID]) throws {
        try restoreTracks(ids: ids, playlistTrackIDs: [:])
    }

    public func restoreTracks(ids: [UUID], playlistTrackIDs: [UUID: [UUID]]) throws {
        guard !ids.isEmpty else { return }
        do {
            var restoredRecords: [TrackRecord] = []
            for start in stride(from: 0, to: ids.count, by: 400) {
                let batch = Array(ids[start..<min(start + 400, ids.count)])
                let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { batch.contains($0.id) })
                let records = try modelContext.fetch(descriptor)
                records.forEach { $0.isExcluded = false }
                restoredRecords.append(contentsOf: records)
            }
            if !playlistTrackIDs.isEmpty {
                let playlistIDs = Array(playlistTrackIDs.keys)
                let descriptor = FetchDescriptor<PlaylistRecord>(predicate: #Predicate { playlistIDs.contains($0.id) })
                for playlist in try modelContext.fetch(descriptor) {
                    guard let originalTrackIDs = playlistTrackIDs[playlist.id] else { continue }
                    playlist.trackIDs = originalTrackIDs
                    playlist.modifiedAt = .now
                }
            }
            try saveChanges()
            if searchIndexLoaded { restoredRecords.forEach(index) }
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// Repairs records duplicated when a NAS remount changes the filesystem's
    /// resource identifier. A relative path is unique inside one authorized
    /// source, so it is the safe fallback identity boundary.
    @discardableResult
    public func repairDuplicateTracksByRelativePath(sourceIDs: [UUID]) throws -> Int {
        do {
            let playlists = try modelContext.fetch(FetchDescriptor<PlaylistRecord>())
            let referencedIDs = Set(playlists.flatMap(\.trackIDs))
            var replacements = [UUID: UUID]()
            var repaired = 0

            let sourceRecordGroups: [[TrackRecord]]
            if sourceIDs.isEmpty {
                sourceRecordGroups = [try modelContext.fetch(FetchDescriptor<TrackRecord>())]
            } else {
                sourceRecordGroups = try sourceIDs.map { sourceID in
                    let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { $0.sourceID == sourceID })
                    return try modelContext.fetch(descriptor)
                }
            }
            for records in sourceRecordGroups {
                let groups = Dictionary(grouping: records) {
                    DuplicatePathKey(sourceID: $0.sourceID, relativePath: $0.relativePath)
                }
                for duplicates in groups.values where duplicates.count > 1 {
                    let keeper = duplicates.max { lhs, rhs in
                        Self.duplicateKeeperScore(lhs, referencedIDs: referencedIDs)
                            < Self.duplicateKeeperScore(rhs, referencedIDs: referencedIDs)
                    }!
                    let liveRecord = duplicates
                        .filter { $0.availabilityRaw == MediaAvailability.available.rawValue }
                        .max { $0.modifiedAt < $1.modifiedAt }
                    Self.mergeDuplicateMetadata(from: duplicates, liveRecord: liveRecord, into: keeper)
                    for duplicate in duplicates where duplicate.id != keeper.id {
                        replacements[duplicate.id] = keeper.id
                        removeFromSearchIndex(duplicate.id)
                        modelContext.delete(duplicate)
                        repaired += 1
                    }
                    if searchIndexLoaded { index(keeper) }
                }
            }

            if !replacements.isEmpty {
                for playlist in playlists {
                    var seen = Set<UUID>()
                    let repairedIDs = playlist.trackIDs.compactMap { original -> UUID? in
                        let resolved = replacements[original] ?? original
                        return seen.insert(resolved).inserted ? resolved : nil
                    }
                    guard repairedIDs != playlist.trackIDs else { continue }
                    playlist.trackIDs = repairedIDs
                    playlist.modifiedAt = .now
                }
            }
            if repaired > 0 { try saveChanges() }
            return repaired
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private static func duplicateKeeperScore(_ record: TrackRecord, referencedIDs: Set<UUID>) -> Int {
        (referencedIDs.contains(record.id) ? 1_000_000 : 0)
            + (record.isFavorite ? 100_000 : 0)
            + record.rating * 10_000
            + (record.analysisVersion == nil ? 0 : 1_000)
            + min(999, record.playCount + record.skipCount)
            + (record.availabilityRaw == MediaAvailability.missing.rawValue ? 1 : 0)
    }

    private static func mergeDuplicateMetadata(
        from records: [TrackRecord],
        liveRecord: TrackRecord?,
        into keeper: TrackRecord
    ) {
        let overrideMask = records.reduce(0) { $0 | $1.metadataOverrideMask }
        func overrideOwner(_ bit: Int) -> TrackRecord? {
            if keeper.hasMetadataOverride(bit) { return keeper }
            if let liveRecord, liveRecord.hasMetadataOverride(bit) { return liveRecord }
            return records.filter { $0.hasMetadataOverride(bit) }
                .max { $0.id.uuidString < $1.id.uuidString }
        }
        if let liveRecord, liveRecord.id != keeper.id {
            keeper.fileIdentifier = liveRecord.fileIdentifier
            keeper.relativePath = liveRecord.relativePath
            if overrideMask & TrackRecord.titleMetadataOverride == 0 { keeper.title = liveRecord.title }
            if overrideMask & TrackRecord.artistMetadataOverride == 0 { keeper.artist = liveRecord.artist }
            if overrideMask & TrackRecord.albumMetadataOverride == 0 { keeper.album = liveRecord.album }
            if overrideMask & TrackRecord.albumArtistMetadataOverride == 0 { keeper.albumArtist = liveRecord.albumArtist }
            if overrideMask & TrackRecord.genreMetadataOverride == 0 { keeper.genre = liveRecord.genre }
            if overrideMask & TrackRecord.releaseDateMetadataOverride == 0 { keeper.releaseDate = liveRecord.releaseDate }
            if overrideMask & TrackRecord.artworkMetadataOverride == 0 { keeper.artworkData = liveRecord.artworkData }
            if overrideMask & TrackRecord.trackNumberMetadataOverride == 0 { keeper.trackNumber = liveRecord.trackNumber }
            if overrideMask & TrackRecord.discNumberMetadataOverride == 0 { keeper.discNumber = liveRecord.discNumber }
            keeper.duration = liveRecord.duration
            keeper.fileSize = liveRecord.fileSize
            keeper.modifiedAt = liveRecord.modifiedAt
            keeper.addedAt = min(keeper.addedAt, liveRecord.addedAt)
            keeper.replayGainDB = liveRecord.replayGainDB
            keeper.mediaKindRaw = liveRecord.mediaKindRaw
            keeper.availabilityRaw = liveRecord.availabilityRaw
            keeper.lastSeenScanID = liveRecord.lastSeenScanID
        }
        if let owner = overrideOwner(TrackRecord.titleMetadataOverride) { keeper.title = owner.title }
        if let owner = overrideOwner(TrackRecord.artistMetadataOverride) { keeper.artist = owner.artist }
        if let owner = overrideOwner(TrackRecord.albumMetadataOverride) { keeper.album = owner.album }
        if let owner = overrideOwner(TrackRecord.albumArtistMetadataOverride) { keeper.albumArtist = owner.albumArtist }
        if let owner = overrideOwner(TrackRecord.genreMetadataOverride) { keeper.genre = owner.genre }
        if let owner = overrideOwner(TrackRecord.releaseDateMetadataOverride) { keeper.releaseDate = owner.releaseDate }
        if let owner = overrideOwner(TrackRecord.artworkMetadataOverride) { keeper.artworkData = owner.artworkData }
        if let owner = overrideOwner(TrackRecord.trackNumberMetadataOverride) { keeper.trackNumber = owner.trackNumber }
        if let owner = overrideOwner(TrackRecord.discNumberMetadataOverride) { keeper.discNumber = owner.discNumber }
        keeper.metadataOverrideMask = overrideMask
        keeper.isFavorite = records.contains(where: \.isFavorite)
        keeper.rating = records.map(\.rating).max() ?? keeper.rating
        keeper.playCount = records.map(\.playCount).max() ?? keeper.playCount
        keeper.skipCount = records.map(\.skipCount).max() ?? keeper.skipCount
        keeper.lastPlayedAt = records.compactMap(\.lastPlayedAt).max()
        keeper.isExcluded = records.allSatisfy(\.isExcluded)
        if let analyzed = records.filter({ $0.analysisVersion != nil }).max(by: {
            ($0.analysisVersion ?? 0) < ($1.analysisVersion ?? 0)
        }) {
            keeper.analysisVersion = analyzed.analysisVersion
            keeper.bpm = analyzed.bpm
            keeper.musicalKey = analyzed.musicalKey
            keeper.integratedLoudnessLUFS = analyzed.integratedLoudnessLUFS
            keeper.energy = analyzed.energy
            keeper.brightness = analyzed.brightness
        }
    }

    @discardableResult
    public func restoreTracks(sourceID: UUID) throws -> Int {
        var restoredCount = 0
        do {
            while true {
                var descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { record in
                    record.sourceID == sourceID && record.isExcluded
                })
                descriptor.fetchLimit = 400
                let records = try modelContext.fetch(descriptor)
                guard !records.isEmpty else { break }
                records.forEach { $0.isExcluded = false }
                try saveChanges()
                restoredCount += records.count
                if searchIndexLoaded { records.forEach(index) }
            }
            return restoredCount
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @discardableResult
    public func restoreTracks(sourceID: UUID, seenIdentifiers: Set<String>, scanID: UUID? = nil) throws -> Int {
        if let scanID { guard activeScanIDs[sourceID] == scanID else { throw CancellationError() } }
        guard !seenIdentifiers.isEmpty else { return 0 }
        var restoredRecords: [TrackRecord] = []
        do {
            let identifiers = Array(seenIdentifiers)
            for start in stride(from: 0, to: identifiers.count, by: 400) {
                let batch = Array(identifiers[start..<min(start + 400, identifiers.count)])
                let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { record in
                    record.sourceID == sourceID && record.isExcluded && batch.contains(record.fileIdentifier)
                })
                let records = try modelContext.fetch(descriptor)
                records.forEach { $0.isExcluded = false }
                restoredRecords.append(contentsOf: records)
            }
            if !restoredRecords.isEmpty {
                try saveChanges()
                if searchIndexLoaded { restoredRecords.forEach(index) }
            }
            return restoredRecords.count
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    public func applyReconciliation(
        upserts: [ScannedMediaFile],
        missingIdentifiers: [String],
        sourceID: UUID,
        expectedScanID: UUID? = nil
    ) throws {
        if let expectedScanID {
            guard activeScanIDs[sourceID] == expectedScanID else { throw CancellationError() }
        }
        let upsertIDs = Set(upserts.map(\.fileIdentifier))
        guard upsertIDs.count == upserts.count,
              upsertIDs.isDisjoint(with: missingIdentifiers) else {
            throw LibraryRepositoryError.invalidReconciliation
        }

        let scanID = expectedScanID ?? beginScan(sourceID: sourceID)
        for start in stride(from: 0, to: upserts.count, by: 400) {
            let end = min(start + 400, upserts.count)
            try applyScanBatch(Array(upserts[start..<end]), sourceID: sourceID, scanID: scanID)
        }
        var newlyMissing: [TrackRecord] = []
        do {
            for start in stride(from: 0, to: missingIdentifiers.count, by: 400) {
                let end = min(start + 400, missingIdentifiers.count)
                let identifiers = Array(missingIdentifiers[start..<end])
                let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { record in
                    record.sourceID == sourceID && identifiers.contains(record.fileIdentifier)
                })
                let records = try modelContext.fetch(descriptor)
                for record in records {
                    record.availabilityRaw = MediaAvailability.missing.rawValue
                }
                if searchIndexLoaded { newlyMissing.append(contentsOf: records) }
            }
            // Finalize all missing markers in one store transaction. A later
            // batch failure must not leave only part of a source unavailable.
            if !missingIdentifiers.isEmpty {
                try saveChanges()
                if searchIndexLoaded { newlyMissing.forEach(index) }
            }
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    public func beginScan(sourceID: UUID) -> UUID {
        let scanID = UUID()
        activeScanIDs[sourceID] = scanID
        return scanID
    }

    public func invalidateScan(sourceID: UUID) {
        activeScanIDs.removeValue(forKey: sourceID)
    }

    public func applyScanBatch(_ files: [ScannedMediaFile], sourceID: UUID, scanID: UUID) throws {
        guard activeScanIDs[sourceID] == scanID else { throw CancellationError() }
        guard !files.isEmpty else { return }
        let identifiers = files.map(\.fileIdentifier)
        guard Set(identifiers).count == identifiers.count else {
            throw LibraryRepositoryError.invalidReconciliation
        }
        let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { record in
            record.sourceID == sourceID && identifiers.contains(record.fileIdentifier)
        })
        let existing = try modelContext.fetch(descriptor)
        var byIdentifier: [String: TrackRecord] = [:]
        for record in existing { byIdentifier[record.fileIdentifier] = record }
        var changedRecords: [TrackRecord] = []
        changedRecords.reserveCapacity(files.count)
        for file in files {
            let record = byIdentifier.removeValue(forKey: file.fileIdentifier) ?? TrackRecord(sourceID: sourceID, file: file)
            record.relativePath = file.relativePath
            if !record.hasMetadataOverride(TrackRecord.titleMetadataOverride) {
                record.title = file.title
            }
            if !record.hasMetadataOverride(TrackRecord.artistMetadataOverride) {
                record.artist = file.artist
            }
            if !record.hasMetadataOverride(TrackRecord.albumMetadataOverride) {
                record.album = file.album
            }
            if !record.hasMetadataOverride(TrackRecord.albumArtistMetadataOverride) {
                record.albumArtist = file.albumArtist
            }
            if !record.hasMetadataOverride(TrackRecord.genreMetadataOverride) {
                record.genre = file.genre
            }
            if !record.hasMetadataOverride(TrackRecord.releaseDateMetadataOverride) {
                record.releaseDate = file.releaseDate
            }
            if !record.hasMetadataOverride(TrackRecord.artworkMetadataOverride) {
                record.artworkData = file.artworkData
            }
            if !record.hasMetadataOverride(TrackRecord.trackNumberMetadataOverride) {
                record.trackNumber = file.trackNumber
            }
            if !record.hasMetadataOverride(TrackRecord.discNumberMetadataOverride) {
                record.discNumber = file.discNumber
            }
            record.duration = file.duration
            record.fileSize = file.fileSize
            record.modifiedAt = file.modifiedAt
            record.replayGainDB = file.replayGainDB
            record.mediaKindRaw = file.mediaKind.rawValue
            record.availabilityRaw = MediaAvailability.available.rawValue
            record.lastSeenScanID = scanID
            if record.modelContext == nil { modelContext.insert(record) }
            changedRecords.append(record)
        }
        try saveChanges()
        if searchIndexLoaded { changedRecords.forEach(index) }
    }

    public func finishScan(sourceID: UUID, scanID: UUID, sourceWasReachable: Bool) throws {
        guard activeScanIDs[sourceID] == scanID else { throw CancellationError() }
        guard sourceWasReachable else { return }
        let missingAvailability = MediaAvailability.missing.rawValue
        while true {
            var descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { record in
                record.sourceID == sourceID &&
                record.lastSeenScanID != scanID &&
                record.availabilityRaw != missingAvailability
            })
            descriptor.fetchLimit = 400
            let unseen = try modelContext.fetch(descriptor)
            guard !unseen.isEmpty else { break }
            for record in unseen {
                record.availabilityRaw = MediaAvailability.missing.rawValue
            }
            try saveChanges()
            if searchIndexLoaded { unseen.forEach(index) }
        }
    }

    public func setFavorite(trackID: UUID, isFavorite: Bool) throws {
        let record = try trackRecord(id: trackID)
        record.isFavorite = isFavorite
        try saveChanges()
        if searchIndexLoaded { index(record) }
    }

    public func setRating(trackID: UUID, rating: Int) throws {
        let record = try trackRecord(id: trackID)
        record.rating = min(5, max(0, rating))
        try saveChanges()
        if searchIndexLoaded { index(record) }
    }

    /// Updates all requested records in one context transaction. Every record
    /// is resolved before any field is changed, so a stale selection cannot
    /// leave only part of a batch updated. SwiftData rollback in `saveChanges`
    /// also restores all records if the single save fails.
    public func updateMetadata(for trackIDs: [UUID], with patch: TrackMetadataPatch) throws {
        _ = try updateMetadataWithUndo(for: trackIDs, with: patch)
    }

    public func previewMetadata(for trackIDs: [UUID], with patch: TrackMetadataPatch) throws -> [MetadataPreview] {
        guard patch.hasChanges else { return [] }
        try validate(patch)
        let records = try records(for: trackIDs)
        return records.map {
            let before = snapshot(of: $0, includeArtwork: patch.artworkData != .unchanged)
            return MetadataPreview(id: $0.id, before: before, after: Self.patchedSnapshot(before, with: patch))
        }
    }

    public func updateMetadataWithUndo(for trackIDs: [UUID], with patch: TrackMetadataPatch) throws -> MetadataUndoReceipt {
        guard patch.hasChanges else { return MetadataUndoReceipt(entries: []) }
        try validate(patch)
        let records = try records(for: trackIDs)
        let capturesArtwork = patch.artworkData != .unchanged
        let entries = records.map { record -> MetadataUndoEntry in
            let before = snapshot(of: record, includeArtwork: capturesArtwork)
            apply(patch, to: record)
            return MetadataUndoEntry(trackID: record.id, before: before,
                                     after: snapshot(of: record, includeArtwork: capturesArtwork))
        }
        do {
            try saveChanges()
            if searchIndexLoaded { records.forEach(index) }
            return MetadataUndoReceipt(entries: entries, capturesArtwork: capturesArtwork)
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    public func undoMetadata(_ receipt: MetadataUndoReceipt) throws -> MetadataUndoResult {
        guard !receipt.entries.isEmpty else { return MetadataUndoResult() }
        let ids = receipt.entries.map(\.trackID)
        let recordsByID = Dictionary(uniqueKeysWithValues: try records(for: ids, requireAll: false).map { ($0.id, $0) })
        var conflicts: [UUID] = []
        var restorable: [(TrackRecord, TrackMetadataSnapshot)] = []
        for entry in receipt.entries {
            guard let record = recordsByID[entry.trackID] else {
                conflicts.append(entry.trackID)
                continue
            }
            guard snapshot(of: record, includeArtwork: receipt.capturesArtwork) == entry.after else {
                conflicts.append(entry.trackID)
                continue
            }
            restorable.append((record, entry.before))
        }
        for (record, before) in restorable {
            restore(before, to: record, includeArtwork: receipt.capturesArtwork)
        }
        if !restorable.isEmpty {
            try saveChanges()
            if searchIndexLoaded { restorable.forEach { index($0.0) } }
        }
        return MetadataUndoResult(restoredIDs: restorable.map { $0.0.id }, conflictIDs: conflicts)
    }

    public func recordPlayback(trackID: UUID, skipped: Bool) throws {
        let record = try trackRecord(id: trackID)
        if skipped {
            if record.skipCount < Int.max { record.skipCount += 1 }
        } else if record.playCount < Int.max {
            record.playCount += 1
        }
        record.lastPlayedAt = .now
        try saveChanges()
        if searchIndexLoaded { index(record) }
    }

    public func setAnalysis(trackID: UUID, profile: AnalysisProfile) throws {
        try Task.checkCancellation()
        let record = try trackRecord(id: trackID)
        record.analysisVersion = profile.version
        record.bpm = profile.bpm
        record.musicalKey = profile.musicalKey
        record.integratedLoudnessLUFS = profile.integratedLoudnessLUFS
        record.energy = profile.energy
        record.brightness = profile.brightness
        try saveChanges()
        if searchIndexLoaded { index(record) }
    }

    public func playlists() throws -> [Playlist] {
        let descriptor = FetchDescriptor<PlaylistRecord>(sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)])
        return try modelContext.fetch(descriptor).map(\.domain)
    }

    public func createPlaylist(name: String) throws -> Playlist {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let playlist = Playlist(name: trimmed.isEmpty ? "未命名歌單" : trimmed)
        modelContext.insert(PlaylistRecord(id: playlist.id, name: playlist.name, trackIDs: playlist.trackIDs,
                                           now: playlist.createdAt))
        try saveChanges()
        return playlist
    }

    public func renamePlaylist(id: UUID, name: String) throws {
        let record = try playlistRecord(id: id)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LibraryRepositoryError.invalidPlaylistName }
        record.name = trimmed
        record.modifiedAt = .now
        try saveChanges()
    }

    public func deletePlaylist(id: UUID) throws {
        let record = try playlistRecord(id: id)
        modelContext.delete(record)
        try saveChanges()
    }

    public func addTrack(trackID: UUID, toPlaylist id: UUID) throws {
        try addTracks(trackIDs: [trackID], toPlaylist: id)
    }

    public func addTracks(trackIDs: [UUID], toPlaylist id: UUID) throws {
        let record = try playlistRecord(id: id)
        var seenRequested = Set<UUID>()
        let requested = trackIDs.filter { seenRequested.insert($0).inserted }
        guard !requested.isEmpty else { return }

        var available = Set<UUID>()
        for start in stride(from: 0, to: requested.count, by: 400) {
            let batch = Array(requested[start..<min(start + 400, requested.count)])
            let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { track in
                batch.contains(track.id) && !track.isExcluded
            })
            available.formUnion(try modelContext.fetch(descriptor).map(\.id))
        }
        if let missing = requested.first(where: { !available.contains($0) }) {
            throw LibraryRepositoryError.trackNotFound(missing)
        }

        var existing = Set(record.trackIDs)
        let uniqueNewIDs = requested.filter { existing.insert($0).inserted }
        guard !uniqueNewIDs.isEmpty else { return }
        record.trackIDs.append(contentsOf: uniqueNewIDs)
        record.modifiedAt = .now
        try saveChanges()
    }

    public func removeTrack(trackID: UUID, fromPlaylist id: UUID) throws {
        try removeTracks(trackIDs: [trackID], fromPlaylist: id)
    }

    public func removeTracks(trackIDs: [UUID], fromPlaylist id: UUID) throws {
        let record = try playlistRecord(id: id)
        let removalIDs = Set(trackIDs)
        guard !removalIDs.isEmpty else { return }

        let original = record.trackIDs
        let filtered = original.filter { !removalIDs.contains($0) }
        guard filtered.count != original.count else { return }
        record.trackIDs = filtered
        record.modifiedAt = .now
        try saveChanges()
    }

    public func reorderPlaylist(id: UUID, trackIDs: [UUID]) throws {
        let record = try playlistRecord(id: id)
        let original = record.trackIDs
        // A reorder is deliberately stricter than add/remove: the caller must
        // provide every existing occurrence exactly once, so media can never
        // disappear because of a stale drag-and-drop snapshot.
        guard trackIDs.count == original.count,
              Set(trackIDs).count == trackIDs.count,
              Set(trackIDs) == Set(original) else {
            throw LibraryRepositoryError.invalidPlaylistPermutation
        }
        guard trackIDs != original else { return }
        record.trackIDs = trackIDs
        record.modifiedAt = .now
        try saveChanges()
    }

    @discardableResult
    public func removeUnavailableTracks(fromPlaylist id: UUID, playableMissingIDs: Set<UUID> = []) throws -> Int {
        let playlist = try playlistRecord(id: id)
        let original = playlist.trackIDs
        guard !original.isEmpty else { return 0 }
        let states = try playlistAvailability(ids: original)
        let filtered = original.filter { trackID in
            guard let state = states[trackID], !state.isExcluded else { return false }
            return state.availability != .missing || playableMissingIDs.contains(trackID)
        }
        let removed = original.count - filtered.count
        if removed > 0 {
            playlist.trackIDs = filtered
            playlist.modifiedAt = .now
            do { try saveChanges() }
            catch { modelContext.rollback(); throw error }
        }
        return removed
    }

    private func playlistAvailability(ids: [UUID]) throws -> [UUID: (isExcluded: Bool, availability: MediaAvailability)] {
        var states: [UUID: (isExcluded: Bool, availability: MediaAvailability)] = [:]
        states.reserveCapacity(ids.count)
        for start in stride(from: 0, to: ids.count, by: 400) {
            let batch = Array(ids[start..<min(start + 400, ids.count)])
            var descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { batch.contains($0.id) })
            descriptor.propertiesToFetch = [\.id, \.isExcluded, \.availabilityRaw]
            for record in try modelContext.fetch(descriptor) {
                states[record.id] = (record.isExcluded, MediaAvailability(rawValue: record.availabilityRaw) ?? .missing)
            }
        }
        return states
    }

    private static var trackPropertiesWithoutArtwork: [PartialKeyPath<TrackRecord>] { [
        \.id, \.sourceID, \.relativePath, \.fileIdentifier, \.title, \.artist,
        \.album, \.albumArtist, \.genre, \.releaseDate, \.trackNumber, \.discNumber, \.duration,
        \.fileSize, \.modifiedAt, \.addedAt, \.replayGainDB, \.mediaKindRaw,
        \.isFavorite, \.rating, \.analysisVersion, \.bpm, \.musicalKey,
        \.integratedLoudnessLUFS, \.energy, \.brightness, \.availabilityRaw,
        \.isExcluded
    ] }

    private func trackRecord(id: UUID) throws -> TrackRecord {
        let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try modelContext.fetch(descriptor).first else {
            throw LibraryRepositoryError.trackNotFound(id)
        }
        return record
    }

    private func playlistRecord(id: UUID) throws -> PlaylistRecord {
        let descriptor = FetchDescriptor<PlaylistRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try modelContext.fetch(descriptor).first else {
            throw LibraryRepositoryError.playlistNotFound(id)
        }
        return record
    }

    private func records(for ids: [UUID], requireAll: Bool = true) throws -> [TrackRecord] {
        var seen = Set<UUID>()
        let requested = ids.filter { seen.insert($0).inserted }
        guard !requested.isEmpty else { return [] }
        var recordsByID: [UUID: TrackRecord] = [:]
        recordsByID.reserveCapacity(requested.count)
        for start in stride(from: 0, to: requested.count, by: 400) {
            let batch = Array(requested[start..<min(start + 400, requested.count)])
            let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { batch.contains($0.id) })
            for record in try modelContext.fetch(descriptor) { recordsByID[record.id] = record }
        }
        guard requireAll, let missingID = requested.first(where: { recordsByID[$0] == nil }) else {
            return requested.compactMap { recordsByID[$0] }
        }
        throw LibraryRepositoryError.trackNotFound(missingID)
    }

    private func validate(_ patch: TrackMetadataPatch) throws {
        if case let .set(value) = patch.trackNumber, value < 0 { throw LibraryRepositoryError.invalidMetadata }
        if case let .set(value) = patch.discNumber, value < 0 { throw LibraryRepositoryError.invalidMetadata }
    }

    private func snapshot(of record: TrackRecord, includeArtwork: Bool = true) -> TrackMetadataSnapshot {
        TrackMetadataSnapshot(title: record.title, artist: record.artist, album: record.album,
                              albumArtist: record.albumArtist, genre: record.genre,
                              releaseDate: record.releaseDate,
                              artworkData: includeArtwork ? record.artworkData : nil,
                              trackNumber: record.trackNumber, discNumber: record.discNumber,
                              metadataOverrideMask: includeArtwork ? record.metadataOverrideMask
                                  : record.metadataOverrideMask & ~TrackRecord.artworkMetadataOverride)
    }

    private func restore(_ snapshot: TrackMetadataSnapshot, to record: TrackRecord, includeArtwork: Bool) {
        record.title = snapshot.title; record.artist = snapshot.artist; record.album = snapshot.album
        record.albumArtist = snapshot.albumArtist; record.genre = snapshot.genre
        record.releaseDate = snapshot.releaseDate
        if includeArtwork { record.artworkData = snapshot.artworkData }
        record.trackNumber = snapshot.trackNumber; record.discNumber = snapshot.discNumber
        record.metadataOverrideMask = includeArtwork ? snapshot.metadataOverrideMask
            : snapshot.metadataOverrideMask | (record.metadataOverrideMask & TrackRecord.artworkMetadataOverride)
    }

    private static func patchedSnapshot(_ before: TrackMetadataSnapshot, with patch: TrackMetadataPatch) -> TrackMetadataSnapshot {
        var result = before
        func text(_ field: TrackMetadataField<String>, _ value: inout String, _ bit: Int) {
            switch field {
            case .unchanged: break
            case .set(let newValue): value = newValue; result.metadataOverrideMask |= bit
            case .clear: value = ""; result.metadataOverrideMask |= bit
            }
        }
        text(patch.title, &result.title, TrackRecord.titleMetadataOverride)
        text(patch.artist, &result.artist, TrackRecord.artistMetadataOverride)
        text(patch.album, &result.album, TrackRecord.albumMetadataOverride)
        text(patch.albumArtist, &result.albumArtist, TrackRecord.albumArtistMetadataOverride)
        switch patch.genre {
        case .unchanged: break
        case .set(let value): result.genre = value; result.metadataOverrideMask |= TrackRecord.genreMetadataOverride
        case .clear: result.genre = nil; result.metadataOverrideMask |= TrackRecord.genreMetadataOverride
        }
        switch patch.releaseDate {
        case .unchanged: break
        case .set(let value): result.releaseDate = value; result.metadataOverrideMask |= TrackRecord.releaseDateMetadataOverride
        case .clear: result.releaseDate = nil; result.metadataOverrideMask |= TrackRecord.releaseDateMetadataOverride
        }
        switch patch.artworkData {
        case .unchanged: break
        case .set(let value): result.artworkData = value; result.metadataOverrideMask |= TrackRecord.artworkMetadataOverride
        case .clear: result.artworkData = nil; result.metadataOverrideMask |= TrackRecord.artworkMetadataOverride
        }
        switch patch.trackNumber {
        case .unchanged: break
        case .set(let value): result.trackNumber = value; result.metadataOverrideMask |= TrackRecord.trackNumberMetadataOverride
        case .clear: result.trackNumber = nil; result.metadataOverrideMask |= TrackRecord.trackNumberMetadataOverride
        }
        switch patch.discNumber {
        case .unchanged: break
        case .set(let value): result.discNumber = value; result.metadataOverrideMask |= TrackRecord.discNumberMetadataOverride
        case .clear: result.discNumber = nil; result.metadataOverrideMask |= TrackRecord.discNumberMetadataOverride
        }
        return result
    }

    private func apply(_ patch: TrackMetadataPatch, to record: TrackRecord) {
        switch patch.title {
        case .unchanged: break
        case let .set(value):
            record.title = value
            record.addMetadataOverride(TrackRecord.titleMetadataOverride)
        case .clear:
            record.title = ""
            record.addMetadataOverride(TrackRecord.titleMetadataOverride)
        }
        switch patch.artist {
        case .unchanged: break
        case let .set(value):
            record.artist = value
            record.addMetadataOverride(TrackRecord.artistMetadataOverride)
        case .clear:
            record.artist = ""
            record.addMetadataOverride(TrackRecord.artistMetadataOverride)
        }
        switch patch.album {
        case .unchanged: break
        case let .set(value):
            record.album = value
            record.addMetadataOverride(TrackRecord.albumMetadataOverride)
        case .clear:
            record.album = ""
            record.addMetadataOverride(TrackRecord.albumMetadataOverride)
        }
        switch patch.albumArtist {
        case .unchanged: break
        case let .set(value):
            record.albumArtist = value
            record.addMetadataOverride(TrackRecord.albumArtistMetadataOverride)
        case .clear:
            record.albumArtist = ""
            record.addMetadataOverride(TrackRecord.albumArtistMetadataOverride)
        }
        switch patch.genre {
        case .unchanged: break
        case let .set(value):
            record.genre = value
            record.addMetadataOverride(TrackRecord.genreMetadataOverride)
        case .clear:
            record.genre = nil
            record.addMetadataOverride(TrackRecord.genreMetadataOverride)
        }
        switch patch.releaseDate {
        case .unchanged: break
        case let .set(value):
            record.releaseDate = value
            record.addMetadataOverride(TrackRecord.releaseDateMetadataOverride)
        case .clear:
            record.releaseDate = nil
            record.addMetadataOverride(TrackRecord.releaseDateMetadataOverride)
        }
        switch patch.artworkData {
        case .unchanged: break
        case let .set(value):
            record.artworkData = value
            record.addMetadataOverride(TrackRecord.artworkMetadataOverride)
        case .clear:
            record.artworkData = nil
            record.addMetadataOverride(TrackRecord.artworkMetadataOverride)
        }
        switch patch.trackNumber {
        case .unchanged: break
        case let .set(value):
            record.trackNumber = value
            record.addMetadataOverride(TrackRecord.trackNumberMetadataOverride)
        case .clear:
            record.trackNumber = nil
            record.addMetadataOverride(TrackRecord.trackNumberMetadataOverride)
        }
        switch patch.discNumber {
        case .unchanged: break
        case let .set(value):
            record.discNumber = value
            record.addMetadataOverride(TrackRecord.discNumberMetadataOverride)
        case .clear:
            record.discNumber = nil
            record.addMetadataOverride(TrackRecord.discNumberMetadataOverride)
        }
    }

    private func saveChanges() throws {
        do {
            try modelContext.save()
            orderedTrackIDsBySort.removeAll(keepingCapacity: true)
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func ensureSearchIndex() throws {
        guard !searchIndexLoaded else { return }
        var descriptor = FetchDescriptor<TrackRecord>()
        // The search index only needs scalar metadata. Fetching full records
        // may fault external artwork for the entire library on first search.
        descriptor.propertiesToFetch = [
            \TrackRecord.id, \TrackRecord.isExcluded, \TrackRecord.title,
            \TrackRecord.artist, \TrackRecord.album, \TrackRecord.albumArtist,
            \TrackRecord.genre, \TrackRecord.releaseDate, \TrackRecord.discNumber, \TrackRecord.trackNumber,
            \TrackRecord.duration, \TrackRecord.addedAt, \TrackRecord.modifiedAt,
            \TrackRecord.isFavorite, \TrackRecord.rating
        ]
        searchIndex.removeAll(keepingCapacity: true)
        searchMatchCache = nil
        for record in try modelContext.fetch(descriptor) { index(record) }
        searchIndexLoaded = true
    }

    private func index(_ record: TrackRecord) {
        removeFromSearchIndex(record.id)
        guard !record.isExcluded else { return }
        let title = Self.searchValue(record.title)
        let artist = Self.searchValue(record.artist)
        let album = Self.searchValue(record.album)
        searchIndex[record.id] = SearchEntry(
            id: record.id,
            title: title,
            artist: artist,
            album: album,
            displayArtist: record.artist,
            displayAlbum: record.album,
            sortTitle: record.title,
            albumArtist: Self.searchValue(record.albumArtist),
            genre: Self.searchValue(record.genre ?? ""),
            discNumber: record.discNumber ?? 0,
            trackNumber: record.trackNumber ?? 0,
            duration: record.duration,
            releaseDate: record.releaseDate,
            addedAt: record.addedAt,
            modifiedAt: record.modifiedAt,
            isFavorite: record.isFavorite,
            rating: record.rating
        )
    }

    private func removeFromSearchIndex(_ id: UUID) {
        searchIndex.removeValue(forKey: id)
        searchMatchCache = nil
    }

    private func matchingEntries(queryTokens: Set<String>) -> [SearchEntry] {
        let key = SearchQueryKey(tokens: queryTokens.sorted())
        let matchingIDs: [UUID]
        if let cached = searchMatchCache, cached.key == key {
            matchingIDs = cached.matchingIDs
        } else {
            matchingIDs = searchIndex.values
                .filter { Self.matches($0, queryTokens: queryTokens) }
                .map(\.id)
            searchMatchCache = SearchMatchCache(key: key, matchingIDs: matchingIDs)
        }
        return matchingIDs.compactMap { searchIndex[$0] }
    }

    private static func searchValue(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func catalogKey(for record: TrackRecord, kind: LibraryCatalogKind) -> String {
        switch kind {
        case .artist:
            return record.artist.isEmpty ? "未知歌手" : record.artist
        case .album:
            let album = record.album.isEmpty ? "未知專輯" : record.album
            let artist = record.albumArtist.isEmpty
                ? (record.artist.isEmpty ? "未知歌手" : record.artist)
                : record.albumArtist
            return "\(album) · \(artist)"
        }
    }

    private static func queryTokens(_ value: String) -> Set<String> {
        Set(value.split(whereSeparator: \.isWhitespace).map(String.init))
    }

    private static func matches(_ entry: SearchEntry, queryTokens: Set<String>) -> Bool {
        queryTokens.allSatisfy { token in
            entry.title.contains(token) || entry.artist.contains(token) || entry.album.contains(token) ||
            entry.albumArtist.contains(token) || entry.genre.contains(token)
        }
    }

    private static func sortDescriptors(
        for sort: LibraryTrackSort,
        ascending: Bool
    ) -> [SortDescriptor<TrackRecord>] {
        let order: SortOrder = ascending ? .forward : .reverse
        switch sort {
        case .title:
            return [
                SortDescriptor(\.title, order: order),
                SortDescriptor(\.artist, order: order),
                SortDescriptor(\.id, order: order)
            ]
        case .artist:
            return [
                SortDescriptor(\.artist, order: order),
                SortDescriptor(\.album, order: order),
                SortDescriptor(\.discNumber, order: order),
                SortDescriptor(\.trackNumber, order: order),
                SortDescriptor(\.title, order: order),
                SortDescriptor(\.id, order: order)
            ]
        case .album:
            return [
                SortDescriptor(\.album, order: order),
                SortDescriptor(\.albumArtist, order: order),
                SortDescriptor(\.discNumber, order: order),
                SortDescriptor(\.trackNumber, order: order),
                SortDescriptor(\.title, order: order),
                SortDescriptor(\.id, order: order)
            ]
        case .albumArtist:
            return [
                SortDescriptor(\.albumArtist, order: order),
                SortDescriptor(\.album, order: order),
                SortDescriptor(\.title, order: order),
                SortDescriptor(\.id, order: order)
            ]
        case .genre:
            return [
                SortDescriptor(\.genre, order: order),
                SortDescriptor(\.title, order: order),
                SortDescriptor(\.id, order: order)
            ]
        case .trackNumber:
            return [
                SortDescriptor(\.trackNumber, order: order),
                SortDescriptor(\.discNumber, order: order),
                SortDescriptor(\.title, order: order),
                SortDescriptor(\.id, order: order)
            ]
        case .discNumber:
            return [
                SortDescriptor(\.discNumber, order: order),
                SortDescriptor(\.trackNumber, order: order),
                SortDescriptor(\.title, order: order),
                SortDescriptor(\.id, order: order)
            ]
        case .duration:
            return [
                SortDescriptor(\.duration, order: order),
                SortDescriptor(\.title, order: order),
                SortDescriptor(\.id, order: order)
            ]
        case .rating:
            return [
                SortDescriptor(\.rating, order: order),
                SortDescriptor(\.title, order: order),
                SortDescriptor(\.id, order: order)
            ]
        case .addedAt:
            return [
                SortDescriptor(\.addedAt, order: order),
                SortDescriptor(\.title, order: order),
                SortDescriptor(\.id, order: order)
            ]
        case .releaseDate:
            return [
                SortDescriptor(\.releaseDate, order: order),
                SortDescriptor(\.title, order: order),
                SortDescriptor(\.id, order: order)
            ]
        case .modifiedAt:
            return [
                SortDescriptor(\.modifiedAt, order: order),
                SortDescriptor(\.title, order: order),
                SortDescriptor(\.id, order: order)
            ]
        }
    }

    private static func sorted(
        _ entries: [SearchEntry],
        by sort: LibraryTrackSort,
        ascending: Bool
    ) -> [SearchEntry] {
        entries.sorted { lhs, rhs in
            let comparison: ComparisonResult
            switch sort {
            case .title:
                comparison = lhs.sortTitle.localizedStandardCompare(rhs.sortTitle)
            case .artist:
                comparison = Self.compare(
                    [lhs.artist, lhs.album, String(lhs.discNumber), String(lhs.trackNumber), lhs.sortTitle],
                    [rhs.artist, rhs.album, String(rhs.discNumber), String(rhs.trackNumber), rhs.sortTitle]
                )
            case .album:
                comparison = Self.compare(
                    [lhs.album, lhs.albumArtist, String(lhs.discNumber), String(lhs.trackNumber), lhs.sortTitle],
                    [rhs.album, rhs.albumArtist, String(rhs.discNumber), String(rhs.trackNumber), rhs.sortTitle]
                )
            case .albumArtist:
                comparison = Self.compare([lhs.albumArtist, lhs.album, lhs.sortTitle], [rhs.albumArtist, rhs.album, rhs.sortTitle])
            case .genre:
                comparison = Self.compare([lhs.genre, lhs.sortTitle], [rhs.genre, rhs.sortTitle])
            case .trackNumber:
                comparison = Self.compare([String(lhs.trackNumber), String(lhs.discNumber), lhs.sortTitle],
                                          [String(rhs.trackNumber), String(rhs.discNumber), rhs.sortTitle])
            case .discNumber:
                comparison = Self.compare([String(lhs.discNumber), String(lhs.trackNumber), lhs.sortTitle],
                                          [String(rhs.discNumber), String(rhs.trackNumber), rhs.sortTitle])
            case .duration:
                comparison = lhs.duration == rhs.duration ? .orderedSame : (lhs.duration < rhs.duration ? .orderedAscending : .orderedDescending)
            case .rating:
                comparison = lhs.rating == rhs.rating ? .orderedSame : (lhs.rating < rhs.rating ? .orderedAscending : .orderedDescending)
            case .addedAt:
                comparison = lhs.addedAt == rhs.addedAt ? .orderedSame : (lhs.addedAt < rhs.addedAt ? .orderedAscending : .orderedDescending)
            case .releaseDate:
                switch (lhs.releaseDate, rhs.releaseDate) {
                case (nil, nil): comparison = .orderedSame
                case (nil, _): comparison = .orderedAscending
                case (_, nil): comparison = .orderedDescending
                case let (left?, right?): comparison = left == right ? .orderedSame : (left < right ? .orderedAscending : .orderedDescending)
                }
            case .modifiedAt:
                if lhs.modifiedAt == rhs.modifiedAt {
                    comparison = .orderedSame
                } else {
                    comparison = lhs.modifiedAt < rhs.modifiedAt ? .orderedAscending : .orderedDescending
                }
            }
            let stableComparison = comparison == .orderedSame
                ? lhs.sortTitle.localizedStandardCompare(rhs.sortTitle)
                : comparison
            if stableComparison == .orderedSame {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return ascending
                ? stableComparison == .orderedAscending
                : stableComparison == .orderedDescending
        }
    }

    private static func compare(_ lhs: [String], _ rhs: [String]) -> ComparisonResult {
        for (left, right) in zip(lhs, rhs) {
            let result = left.localizedStandardCompare(right)
            if result != .orderedSame { return result }
        }
        return .orderedSame
    }
}
