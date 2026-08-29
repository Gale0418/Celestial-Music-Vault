import Foundation
import SwiftData
import CMVDomain

public enum LibraryRepositoryError: Error, Equatable, Sendable {
    case invalidReconciliation
}

public actor SwiftDataLibraryRepository: LibraryRepository {
    private let worker: LibraryDataActor

    public init(container: ModelContainer) {
        worker = LibraryDataActor(modelContainer: container)
    }

    public func tracks(matching query: String, limit: Int, offset: Int) async throws -> [Track] {
        try await worker.tracks(matching: query, limit: limit, offset: offset)
    }

    public func trackIDs(matching query: String) async throws -> [UUID] {
        try await worker.trackIDs(matching: query)
    }

    public func tracks(ids: [UUID]) async throws -> [Track] {
        try await worker.tracks(ids: ids)
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
        let sortTitle: String
    }

    private var searchIndex: [UUID: SearchEntry] = [:]
    private var searchTokensByID: [UUID: Set<String>] = [:]
    private var searchIDsByToken: [String: Set<UUID>] = [:]
    private var searchIndexLoaded = false

    public func tracks(matching query: String, limit: Int, offset: Int) throws -> [Track] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty {
            try ensureSearchIndex()
            let needle = Self.searchValue(normalized)
            let queryTokens = Self.searchTokens(needle)
            let indexedCandidates = queryTokens.compactMap { searchIDsByToken[$0] }
            var candidateIDs: Set<UUID>?
            if let smallestIndex = indexedCandidates.indices.min(by: {
                indexedCandidates[$0].count < indexedCandidates[$1].count
            }) {
                var result = indexedCandidates[smallestIndex]
                for index in indexedCandidates.indices where index != smallestIndex {
                    result.formIntersection(indexedCandidates[index])
                }
                candidateIDs = result
            } else {
                candidateIDs = nil
            }
            let matchingIDs = (candidateIDs ?? Set(searchIndex.keys)).compactMap { searchIndex[$0] }
                .filter { entry in
                    entry.title.contains(needle) ||
                    entry.artist.contains(needle) ||
                    entry.album.contains(needle)
                }
                .sorted { $0.sortTitle.localizedStandardCompare($1.sortTitle) == .orderedAscending }
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
        descriptor.sortBy = [SortDescriptor(\.title)]
        return try modelContext.fetch(descriptor).map(\.domain)
    }

    public func trackIDs(matching query: String) throws -> [UUID] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            let descriptor = FetchDescriptor<TrackRecord>(
                predicate: #Predicate { !$0.isExcluded },
                sortBy: [SortDescriptor(\.title)]
            )
            return try modelContext.fetch(descriptor).map(\.id)
        }

        try ensureSearchIndex()
        let needle = Self.searchValue(normalized)
        return searchIndex.values
            .filter { entry in
                entry.title.contains(needle) || entry.artist.contains(needle) || entry.album.contains(needle)
            }
            .sorted { $0.sortTitle.localizedStandardCompare($1.sortTitle) == .orderedAscending }
            .map(\.id)
    }

    public func tracks(sourceID: UUID) throws -> [Track] {
        let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { record in
            record.sourceID == sourceID
        })
        return try modelContext.fetch(descriptor).map(\.domain)
    }

    public func tracks(ids: [UUID]) throws -> [Track] {
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { record in
            ids.contains(record.id) && !record.isExcluded
        })
        let byID = Dictionary(uniqueKeysWithValues: try modelContext.fetch(descriptor).map { ($0.id, $0.domain) })
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
            try modelContext.save()
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
            try modelContext.save()
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
            for record in try modelContext.fetch(descriptor) {
                record.availabilityRaw = MediaAvailability.missing.rawValue
                if searchIndexLoaded { index(record) }
            }
            try modelContext.save()
        }
    }

    public func beginScan(sourceID: UUID) -> UUID { UUID() }

    public func applyScanBatch(_ files: [ScannedMediaFile], sourceID: UUID, scanID: UUID) throws {
        guard !files.isEmpty else { return }
        let identifiers = files.map(\.fileIdentifier)
        let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { record in
            record.sourceID == sourceID && identifiers.contains(record.fileIdentifier)
        })
        let existing = try modelContext.fetch(descriptor)
        var byIdentifier: [String: TrackRecord] = [:]
        for record in existing { byIdentifier[record.fileIdentifier] = record }
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
            if searchIndexLoaded { index(record) }
        }
        try modelContext.save()
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
                if searchIndexLoaded { index(record) }
            }
            try modelContext.save()
        }
    }

    public func setFavorite(trackID: UUID, isFavorite: Bool) throws {
        let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { $0.id == trackID })
        if let record = try modelContext.fetch(descriptor).first {
            record.isFavorite = isFavorite
            try modelContext.save()
            if searchIndexLoaded { index(record) }
        }
    }

    public func setRating(trackID: UUID, rating: Int) throws {
        let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { $0.id == trackID })
        if let record = try modelContext.fetch(descriptor).first {
            record.rating = min(5, max(0, rating))
            try modelContext.save()
            if searchIndexLoaded { index(record) }
        }
    }

    public func recordPlayback(trackID: UUID, skipped: Bool) throws {
        let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { $0.id == trackID })
        if let record = try modelContext.fetch(descriptor).first {
            if skipped { record.skipCount += 1 } else { record.playCount += 1 }
            record.lastPlayedAt = .now
            try modelContext.save()
            if searchIndexLoaded { index(record) }
        }
    }

    public func setAnalysis(trackID: UUID, profile: AnalysisProfile) throws {
        let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { $0.id == trackID })
        if let record = try modelContext.fetch(descriptor).first {
            record.analysisVersion = profile.version
            record.bpm = profile.bpm
            record.musicalKey = profile.musicalKey
            record.integratedLoudnessLUFS = profile.integratedLoudnessLUFS
            record.energy = profile.energy
            record.brightness = profile.brightness
            try modelContext.save()
            if searchIndexLoaded { index(record) }
        }
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
        try modelContext.save()
        return playlist
    }

    public func renamePlaylist(id: UUID, name: String) throws {
        let descriptor = FetchDescriptor<PlaylistRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try modelContext.fetch(descriptor).first else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        record.name = trimmed
        record.modifiedAt = .now
        try modelContext.save()
    }

    public func deletePlaylist(id: UUID) throws {
        let descriptor = FetchDescriptor<PlaylistRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    public func addTrack(trackID: UUID, toPlaylist id: UUID) throws {
        try addTracks(trackIDs: [trackID], toPlaylist: id)
    }

    public func addTracks(trackIDs: [UUID], toPlaylist id: UUID) throws {
        let descriptor = FetchDescriptor<PlaylistRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try modelContext.fetch(descriptor).first else { return }
        var existing = Set(record.trackIDs)
        let uniqueNewIDs = trackIDs.filter { existing.insert($0).inserted }
        guard !uniqueNewIDs.isEmpty else { return }
        record.trackIDs.append(contentsOf: uniqueNewIDs)
        record.modifiedAt = .now
        try modelContext.save()
    }

    public func removeTrack(trackID: UUID, fromPlaylist id: UUID) throws {
        let descriptor = FetchDescriptor<PlaylistRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try modelContext.fetch(descriptor).first else { return }
        record.trackIDs.removeAll { $0 == trackID }
        record.modifiedAt = .now
        try modelContext.save()
    }

    private func ensureSearchIndex() throws {
        guard !searchIndexLoaded else { return }
        let descriptor = FetchDescriptor<TrackRecord>()
        searchIndex.removeAll(keepingCapacity: true)
        searchTokensByID.removeAll(keepingCapacity: true)
        searchIDsByToken.removeAll(keepingCapacity: true)
        for record in try modelContext.fetch(descriptor) { index(record) }
        searchIndexLoaded = true
    }

    private func index(_ record: TrackRecord) {
        removeFromSearchIndex(record.id)
        guard !record.isExcluded else { return }
        let title = Self.searchValue(record.title)
        let artist = Self.searchValue(record.artist)
        let album = Self.searchValue(record.album)
        let tokens = Self.searchTokens([title, artist, album].joined(separator: " "))
        searchIndex[record.id] = SearchEntry(
            id: record.id,
            title: title,
            artist: artist,
            album: album,
            sortTitle: record.title
        )
        searchTokensByID[record.id] = tokens
        for token in tokens { searchIDsByToken[token, default: []].insert(record.id) }
    }

    private func removeFromSearchIndex(_ id: UUID) {
        searchIndex.removeValue(forKey: id)
        guard let oldTokens = searchTokensByID.removeValue(forKey: id) else { return }
        for token in oldTokens {
            searchIDsByToken[token]?.remove(id)
            if searchIDsByToken[token]?.isEmpty == true { searchIDsByToken.removeValue(forKey: token) }
        }
    }

    private static func searchValue(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func searchTokens(_ value: String) -> Set<String> {
        Set(value.split { !$0.isLetter && !$0.isNumber }.map(String.init))
    }
}
