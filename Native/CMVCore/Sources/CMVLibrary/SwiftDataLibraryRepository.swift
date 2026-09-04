import Foundation
import SwiftData
import CMVDomain

public enum LibraryRepositoryError: Error, Equatable, Sendable {
    case invalidReconciliation
    case trackNotFound(UUID)
    case playlistNotFound(UUID)
    case invalidPlaylistName
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

public actor SwiftDataLibraryRepository: LibraryRepository {
    private let worker: LibraryDataActor

    public init(container: ModelContainer) {
        worker = LibraryDataActor(modelContainer: container)
    }

    public func tracks(
        matching query: String,
        sort: LibraryTrackSort = .title,
        ascending: Bool = true,
        limit: Int,
        offset: Int
    ) async throws -> [Track] {
        try await worker.tracks(matching: query, sort: sort, ascending: ascending, limit: limit, offset: offset)
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

    public func tracks(sourceID: UUID) async throws -> [Track] {
        try await worker.tracks(sourceID: sourceID)
    }

    public func favoriteTracks(limit: Int, offset: Int) async throws -> [Track] {
        try await worker.favoriteTracks(limit: limit, offset: offset)
    }

    public func applyReconciliation(
        upserts: [ScannedMediaFile],
        missingIdentifiers: [String],
        sourceID: UUID
    ) async throws {
        try await worker.applyReconciliation(
            upserts: upserts,
            missingIdentifiers: missingIdentifiers,
            sourceID: sourceID
        )
    }

    public func beginScan(sourceID: UUID) async -> UUID {
        await worker.beginScan(sourceID: sourceID)
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
        let discNumber: Int
        let trackNumber: Int
        let modifiedAt: Date
        let isFavorite: Bool
        let rating: Int
    }

    private var searchIndex: [UUID: SearchEntry] = [:]
    private var searchIndexLoaded = false

    public func tracks(
        matching query: String,
        sort: LibraryTrackSort = .title,
        ascending: Bool = true,
        limit: Int,
        offset: Int
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
            let matches = searchIndex.values.filter { Self.matches($0, queryTokens: queryTokens) }
            let matchingIDs = Self.sorted(Array(matches), by: sort, ascending: ascending)
                .dropFirst(max(0, offset))
                .prefix(max(1, limit))
                .map(\.id)
            let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { record in
                matchingIDs.contains(record.id)
            })
            let byID = Dictionary(uniqueKeysWithValues: try modelContext.fetch(descriptor).map { ($0.id, $0.domain) })
            return matchingIDs.compactMap { byID[$0] }
        }

        var descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { !$0.isExcluded })
        descriptor.fetchLimit = max(1, limit)
        descriptor.fetchOffset = max(0, offset)
        descriptor.sortBy = Self.sortDescriptors(for: sort, ascending: ascending)
        return try modelContext.fetch(descriptor).map(\.domain)
    }

    public func trackIDs(
        matching query: String,
        sort: LibraryTrackSort = .title,
        ascending: Bool = true
    ) throws -> [UUID] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            let descriptor = FetchDescriptor<TrackRecord>(
                predicate: #Predicate { !$0.isExcluded },
                sortBy: Self.sortDescriptors(for: sort, ascending: ascending)
            )
            return try modelContext.fetch(descriptor).map(\.id)
        }

        try ensureSearchIndex()
        let queryTokens = Self.queryTokens(Self.searchValue(normalized))
        let matches = searchIndex.values.filter { Self.matches($0, queryTokens: queryTokens) }
        return Self.sorted(Array(matches), by: sort, ascending: ascending).map(\.id)
    }

    public func searchCandidates(matching query: String) throws -> [LibrarySearchCandidate] {
        try ensureSearchIndex()
        let queryTokens = Self.queryTokens(Self.searchValue(
            query.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        return searchIndex.values.compactMap { entry in
            guard Self.matches(entry, queryTokens: queryTokens) else { return nil }
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

    public func tracks(ids: [UUID]) throws -> [Track] {
        guard !ids.isEmpty else { return [] }
        var byID: [UUID: Track] = [:]
        byID.reserveCapacity(ids.count)
        for start in stride(from: 0, to: ids.count, by: 400) {
            let batch = Array(ids[start..<min(start + 400, ids.count)])
            let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { record in
                batch.contains(record.id) && !record.isExcluded
            })
            for record in try modelContext.fetch(descriptor) {
                byID[record.id] = record.domain
            }
        }
        return ids.compactMap { byID[$0] }
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

            let selected = Set(ids)
            for playlist in try modelContext.fetch(FetchDescriptor<PlaylistRecord>()) {
                let original = playlist.trackIDs
                let filtered = original.filter { !selected.contains($0) }
                guard filtered.count != original.count else { continue }
                playlist.trackIDs = filtered
                playlist.modifiedAt = .now
            }
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

    public func applyReconciliation(
        upserts: [ScannedMediaFile],
        missingIdentifiers: [String],
        sourceID: UUID
    ) throws {
        let upsertIDs = Set(upserts.map(\.fileIdentifier))
        guard upsertIDs.count == upserts.count,
              upsertIDs.isDisjoint(with: missingIdentifiers) else {
            throw LibraryRepositoryError.invalidReconciliation
        }

        let scanID = UUID()
        for start in stride(from: 0, to: upserts.count, by: 400) {
            let end = min(start + 400, upserts.count)
            try applyScanBatch(Array(upserts[start..<end]), sourceID: sourceID, scanID: scanID)
        }
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
            try saveChanges()
            if searchIndexLoaded { records.forEach(index) }
        }
    }

    public func beginScan(sourceID: UUID) -> UUID { UUID() }

    public func applyScanBatch(_ files: [ScannedMediaFile], sourceID: UUID, scanID: UUID) throws {
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
            record.title = file.title
            record.artist = file.artist
            record.album = file.album
            record.albumArtist = file.albumArtist
            record.artworkData = file.artworkData
            record.trackNumber = file.trackNumber
            record.discNumber = file.discNumber
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
        let record = try playlistRecord(id: id)
        guard record.trackIDs.contains(trackID) else { return }
        record.trackIDs.removeAll { $0 == trackID }
        record.modifiedAt = .now
        try saveChanges()
    }

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

    private func saveChanges() throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func ensureSearchIndex() throws {
        guard !searchIndexLoaded else { return }
        let descriptor = FetchDescriptor<TrackRecord>()
        searchIndex.removeAll(keepingCapacity: true)
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
            discNumber: record.discNumber ?? 0,
            trackNumber: record.trackNumber ?? 0,
            modifiedAt: record.modifiedAt,
            isFavorite: record.isFavorite,
            rating: record.rating
        )
    }

    private func removeFromSearchIndex(_ id: UUID) {
        searchIndex.removeValue(forKey: id)
    }

    private static func searchValue(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func queryTokens(_ value: String) -> Set<String> {
        Set(value.split(whereSeparator: \.isWhitespace).map(String.init))
    }

    private static func matches(_ entry: SearchEntry, queryTokens: Set<String>) -> Bool {
        queryTokens.allSatisfy { token in
            entry.title.contains(token) || entry.artist.contains(token) || entry.album.contains(token)
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
