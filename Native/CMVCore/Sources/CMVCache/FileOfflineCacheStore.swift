import Foundation
import CryptoKit
import CMVDomain

public actor FileOfflineCacheStore: OfflineCacheStore {
    private final class FileManagerBox: @unchecked Sendable {
        let value: FileManager

        init(_ value: FileManager) {
            self.value = value
        }
    }

    private actor CacheIOWorker {
        private let fileManager: FileManagerBox

        init(fileManager: FileManagerBox) {
            self.fileManager = fileManager
        }

        func stage(
            sourceURL: URL,
            stagingURL: URL,
            stagingChecksumURL: URL
        ) throws -> StagedCopy {
            try Task.checkCancellation()
            let ownsSecurityScope = sourceURL.startAccessingSecurityScopedResource()
            var stagedSuccessfully = false
            defer {
                if ownsSecurityScope { sourceURL.stopAccessingSecurityScopedResource() }
                if !stagedSuccessfully {
                    try? fileManager.value.removeItem(at: stagingURL)
                    try? fileManager.value.removeItem(at: stagingChecksumURL)
                }
            }

            try fileManager.value.copyItem(at: sourceURL, to: stagingURL)
            let digest = try hashFile(stagingURL)
            try Task.checkCancellation()
            try Data(digest.utf8).write(to: stagingChecksumURL, options: .atomic)
            let values = try? stagingURL.resourceValues(
                forKeys: [.fileSizeKey, .contentModificationDateKey]
            )
            stagedSuccessfully = true
            return StagedCopy(
                mediaURL: stagingURL,
                checksumURL: stagingChecksumURL,
                size: Int64(values?.fileSize ?? 0),
                digest: digest,
                modificationDate: values?.contentModificationDate
            )
        }

        private func hashFile(_ url: URL) throws -> String {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var digest = SHA256()
            while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
                try Task.checkCancellation()
                digest.update(data: chunk)
            }
            return digest.finalize().map { String(format: "%02x", $0) }.joined()
        }
    }

    private struct ManifestEntry: Codable {
        var fileName: String
        var size: Int64
        var digest: String
        var modificationDate: Date?
        var lastAccess: Date

        private enum CodingKeys: String, CodingKey {
            case fileName, size, digest, modificationDate, lastAccess
        }

        init(fileName: String, size: Int64, digest: String, modificationDate: Date?, lastAccess: Date) {
            self.fileName = fileName
            self.size = size
            self.digest = digest
            self.modificationDate = modificationDate
            self.lastAccess = lastAccess
        }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            fileName = try values.decode(String.self, forKey: .fileName)
            size = try values.decodeIfPresent(Int64.self, forKey: .size) ?? 0
            digest = try values.decodeIfPresent(String.self, forKey: .digest) ?? ""
            modificationDate = try values.decodeIfPresent(Date.self, forKey: .modificationDate)
            lastAccess = try values.decodeIfPresent(Date.self, forKey: .lastAccess) ?? .distantPast
        }
    }

    private struct CopyResult {
        var url: URL
        var size: Int64
        var digest: String
        var modificationDate: Date?
    }

    private struct StagedCopy {
        var mediaURL: URL
        var checksumURL: URL
        var size: Int64
        var digest: String
        var modificationDate: Date?
    }

    private struct SmartManifest: Codable {
        var entries: [String: ManifestEntry] = [:]
    }

    private struct DirectoryIndex {
        var filesByIdentifier: [String: [URL]]
        var loadedAt: TimeInterval
    }

    private static let directoryIndexTTL: TimeInterval = 30
    private static let manifestFlushDelayNanoseconds: UInt64 = 500_000_000

    private let fileManager: FileManager
    private let pinnedRoot: URL
    private let smartRoot: URL
    private let smartManifestURL: URL
    private let evictionPlanner: any CacheEvictionPlanner
    private var manifest = SmartManifest()
    private var manifestLoaded = false
    private var manifestNeedsSave = false
    private var manifestFlushTask: Task<Void, Never>?
    private var pinnedDirectoryIndex: DirectoryIndex?
    private var smartDirectoryIndex: DirectoryIndex?
    private let ioWorker: CacheIOWorker
    private var prefetchGenerations: [UUID: UUID] = [:]

    public init(
        fileManager: FileManager = .default,
        evictionPlanner: any CacheEvictionPlanner = DeterministicCacheEvictionPlanner()
    ) throws {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let caches = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        self.fileManager = fileManager
        pinnedRoot = appSupport.appendingPathComponent("CMV/Pinned", isDirectory: true)
        smartRoot = caches.appendingPathComponent("CMV/Smart", isDirectory: true)
        smartManifestURL = smartRoot.appendingPathComponent("manifest.json")
        self.evictionPlanner = evictionPlanner
        try fileManager.createDirectory(at: pinnedRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: smartRoot, withIntermediateDirectories: true)
        ioWorker = CacheIOWorker(fileManager: FileManagerBox(fileManager))
    }

    /// Explicit roots make cache behavior independently testable and allow a
    /// caller to place disposable and pinned storage on distinct volumes.
    public init(
        pinnedRoot: URL,
        smartRoot: URL,
        fileManager: FileManager = .default,
        evictionPlanner: any CacheEvictionPlanner = DeterministicCacheEvictionPlanner()
    ) throws {
        self.fileManager = fileManager
        self.pinnedRoot = pinnedRoot.standardizedFileURL
        self.smartRoot = smartRoot.standardizedFileURL
        smartManifestURL = self.smartRoot.appendingPathComponent("manifest.json")
        self.evictionPlanner = evictionPlanner
        try fileManager.createDirectory(at: self.pinnedRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: self.smartRoot, withIntermediateDirectories: true)
        ioWorker = CacheIOWorker(fileManager: FileManagerBox(fileManager))
    }

    public func pin(trackID: UUID, sourceURL: URL) async throws -> URL {
        try copy(trackID: trackID, sourceURL: sourceURL, root: pinnedRoot).url
    }

    public func unpin(trackID: UUID) async throws {
        for url in try mediaFiles(in: pinnedRoot, identifiers: [trackID.uuidString]) {
            try removeFileIfPresent(at: url)
            try removeFileIfPresent(at: checksumURL(for: url))
        }
        invalidateDirectoryIndex(for: pinnedRoot)
    }

    public func isPinned(trackID: UUID) async -> Bool {
        guard let files = try? indexedMediaFiles(
            in: pinnedRoot,
            identifiers: [trackID.uuidString]
        ) else {
            return false
        }
        return files.contains { fileManager.fileExists(atPath: checksumURL(for: $0).path) }
    }

    /// Resolve a whole playlist's missing tracks with one directory-index pass.
    public func pinnedTrackIDs(in candidates: [UUID]) async -> Set<UUID> {
        let resolved = resolveCachedURLs(trackIDs: candidates, requireFullHash: false)
        return Set(resolved.compactMap { id, url in
            url.deletingLastPathComponent().standardizedFileURL == pinnedRoot.standardizedFileURL ? id : nil
        })
    }

    /// Resolves one checksum-validated local copy. Repeated single lookups share
    /// a short-lived directory index and debounce LRU persistence; queue callers
    /// can use `cachedURLs(trackIDs:)` to resolve the complete batch at once.
    public func cachedURL(trackID: UUID) async -> URL? {
        resolveCachedURLs(trackIDs: [trackID], requireFullHash: false)[trackID]
    }

    /// Batch lookup used by large playback queues. Directory enumeration is
    /// O(cache files) once per call instead of once per requested track.
    public func cachedURLs(trackIDs: [UUID]) async -> [UUID: URL] {
        resolveCachedURLs(trackIDs: trackIDs, requireFullHash: false)
    }

    private func resolveCachedURLs(
        trackIDs: [UUID],
        requireFullHash: Bool
    ) -> [UUID: URL] {
        var seen = Set<UUID>()
        let orderedIDs = trackIDs.filter { seen.insert($0).inserted }
        guard !orderedIDs.isEmpty else { return [:] }

        let requestedIdentifiers = Set(orderedIDs.map(\.uuidString))
        let pinnedFiles = (try? indexedMediaFiles(
            in: pinnedRoot,
            identifiers: requestedIdentifiers
        )) ?? []
        let smartFiles = (try? indexedMediaFiles(
            in: smartRoot,
            identifiers: requestedIdentifiers
        )) ?? []
        let pinnedByIdentifier = Dictionary(grouping: pinnedFiles, by: cacheIdentifier(for:))
        let smartByIdentifier = Dictionary(grouping: smartFiles, by: cacheIdentifier(for:))

        let manifestAvailable: Bool
        do {
            try loadManifestIfNeeded()
            manifestAvailable = true
        } catch {
            // A disposable manifest must never block pinned media or prevent a
            // full-hash recovery of a smart-cache file.
            manifestAvailable = false
        }

        let now = Date.now
        var resolved: [UUID: URL] = [:]
        resolved.reserveCapacity(orderedIDs.count)
        var manifestDirty = false

        for trackID in orderedIDs {
            let identifier = trackID.uuidString
            let pinnedCandidates = (pinnedByIdentifier[identifier] ?? [])
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            var smartCandidates = smartByIdentifier[identifier] ?? []
            if let preferred = manifest.entries[identifier]?.fileName {
                smartCandidates.sort { left, right in
                    let leftPreferred = left.lastPathComponent == preferred
                    let rightPreferred = right.lastPathComponent == preferred
                    if leftPreferred != rightPreferred { return leftPreferred }
                    return left.lastPathComponent < right.lastPathComponent
                }
            } else {
                smartCandidates.sort { $0.lastPathComponent < $1.lastPathComponent }
            }

            let candidates = pinnedCandidates.map { ($0, false) }
                + smartCandidates.map { ($0, true) }
            var foundURL: URL?

            for (url, isSmart) in candidates {
                guard fileManager.fileExists(atPath: url.path) else {
                    invalidateDirectoryIndex(for: isSmart ? smartRoot : pinnedRoot)
                    continue
                }
                guard let expectedValue = try? String(
                    contentsOf: checksumURL(for: url),
                    encoding: .utf8
                ) else {
                    continue
                }
                let expected = expectedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !expected.isEmpty else { continue }

                var resourceValues: URLResourceValues?
                var actualDigest: String?
                var validatedWithoutHash = false
                if !requireFullHash,
                   isSmart,
                   manifestAvailable,
                   let entry = manifest.entries[identifier],
                   entry.fileName == url.lastPathComponent,
                   entry.digest == expected {
                    resourceValues = freshResourceValues(for: url)
                    if let resourceValues,
                       Int64(resourceValues.fileSize ?? -1) == entry.size,
                       resourceValues.contentModificationDate == entry.modificationDate {
                        validatedWithoutHash = true
                    }
                }

                if !validatedWithoutHash {
                    guard let digest = try? hashFile(url), digest == expected else {
                        continue
                    }
                    actualDigest = digest
                }

                if isSmart, manifestAvailable {
                    if resourceValues == nil {
                        resourceValues = freshResourceValues(for: url)
                    }
                    let previous = manifest.entries[identifier]
                    let lastAccess: Date
                    if let previous, now.timeIntervalSince(previous.lastAccess) < 60 {
                        lastAccess = previous.lastAccess
                    } else {
                        lastAccess = now
                    }
                    let next = ManifestEntry(
                        fileName: url.lastPathComponent,
                        size: Int64(resourceValues?.fileSize ?? 0),
                        digest: actualDigest ?? expected,
                        modificationDate: resourceValues?.contentModificationDate,
                        lastAccess: lastAccess
                    )
                    if !Self.sameManifestEntry(previous, next) {
                        manifest.entries[identifier] = next
                        manifestDirty = true
                    }
                }

                foundURL = url
                break
            }

            if let foundURL {
                resolved[trackID] = foundURL
            } else if manifestAvailable,
                      manifest.entries.removeValue(forKey: identifier) != nil {
                // Do not preserve a manifest pointer after every matching smart
                // candidate failed validation or disappeared.
                manifestDirty = true
            }
        }

        if manifestAvailable, manifestDirty {
            markManifestDirty()
        }
        return resolved
    }

    public func prefetch(trackID: UUID, sourceURL: URL) async throws -> URL {
        try await prefetch(trackID: trackID, sourceURL: sourceURL, onAdmission: {})
    }

    internal func prefetch(
        trackID: UUID,
        sourceURL: URL,
        onAdmission: @Sendable () -> Void
    ) async throws -> URL {
        let generation = UUID()
        prefetchGenerations[trackID] = generation
        onAdmission()
        let stagingURL = smartRoot.appendingPathComponent(
            ".\(trackID.uuidString).\(UUID().uuidString).part"
        )
        let stagingChecksumURL = checksumURL(for: stagingURL)
        defer {
            try? fileManager.removeItem(at: stagingURL)
            try? fileManager.removeItem(at: stagingChecksumURL)
            if prefetchGenerations[trackID] == generation {
                prefetchGenerations.removeValue(forKey: trackID)
            }
        }

        let staged = try await ioWorker.stage(
            sourceURL: sourceURL,
            stagingURL: stagingURL,
            stagingChecksumURL: stagingChecksumURL
        )
        guard !Task.isCancelled, prefetchGenerations[trackID] == generation else {
            throw CancellationError()
        }

        let copied = try commitStagedCopy(
            trackID: trackID,
            destinationName: destinationName(trackID: trackID, sourceURL: sourceURL),
            root: smartRoot,
            staged: staged
        )
        try loadManifestIfNeeded()
        manifest.entries[trackID.uuidString] = ManifestEntry(
            fileName: copied.url.lastPathComponent,
            size: copied.size,
            digest: copied.digest,
            modificationDate: copied.modificationDate,
            lastAccess: .now
        )
        markManifestDirty()
        try persistManifestNow()
        return copied.url
    }

    public func trim(to budgetBytes: Int64) async throws {
        try loadManifestIfNeeded()
        let files = try mediaFiles(in: smartRoot)
        let existingFileNames = Set(files.map(\.lastPathComponent))
        let originalManifestCount = manifest.entries.count
        manifest.entries = manifest.entries.filter {
            existingFileNames.contains($0.value.fileName)
        }
        var manifestDirty = manifest.entries.count != originalManifestCount

        var entriesByFileName: [String: ManifestEntry] = [:]
        entriesByFileName.reserveCapacity(manifest.entries.count)
        for entry in manifest.entries.values {
            entriesByFileName[entry.fileName] = entry
        }

        var entries: [(url: URL, identifier: String, size: Int64, lastAccess: Date)] = []
        entries.reserveCapacity(files.count)
        for url in files {
            let identifier = cacheIdentifier(for: url)
            guard UUID(uuidString: identifier) != nil else { continue }
            if let entry = entriesByFileName[url.lastPathComponent] {
                entries.append((url, identifier, max(0, entry.size), entry.lastAccess))
            } else {
                let size = Int64((try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                entries.append((url, identifier, max(0, size), .distantPast))
            }
        }

        let planEntries = entries.map { entry in
            CacheEvictionEntry(
                identifier: entry.identifier,
                sizeBytes: entry.size,
                lastAccessOrder: Self.accessOrder(for: entry.lastAccess)
            )
        }
        let evictionIdentifiers = Set(
            evictionPlanner.plan(
                entries: planEntries,
                budgetBytes: max(0, budgetBytes)
            )
        )
        let entriesByIdentifier = Dictionary(grouping: entries) { $0.identifier }
        var removedFileNames = Set<String>()
        for identifier in evictionIdentifiers {
            for entry in entriesByIdentifier[identifier] ?? [] {
                try removeFileIfPresent(at: entry.url)
                try removeFileIfPresent(at: checksumURL(for: entry.url))
                removedFileNames.insert(entry.url.lastPathComponent)
            }
        }
        if !removedFileNames.isEmpty {
            manifest.entries = manifest.entries.filter {
                !removedFileNames.contains($0.value.fileName)
            }
            manifestDirty = true
            invalidateDirectoryIndex(for: smartRoot)
        }
        if manifestDirty {
            markManifestDirty()
            try persistManifestNow()
        }
    }

    public func verify(trackID: UUID) async -> Bool {
        resolveCachedURLs(trackIDs: [trackID], requireFullHash: true)[trackID] != nil
    }

    private func copy(trackID: UUID, sourceURL: URL, root: URL) throws -> CopyResult {
        let ownsSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer { if ownsSecurityScope { sourceURL.stopAccessingSecurityScopedResource() } }
        let destinationName = destinationName(trackID: trackID, sourceURL: sourceURL)
        let temporary = root.appendingPathComponent(".\(trackID.uuidString).\(UUID().uuidString).part")
        let temporaryChecksum = checksumURL(for: temporary)
        defer {
            try? fileManager.removeItem(at: temporary)
            try? fileManager.removeItem(at: temporaryChecksum)
        }
        try fileManager.copyItem(at: sourceURL, to: temporary)
        let digest = try hashFile(temporary)
        try Data(digest.utf8).write(to: temporaryChecksum, options: .atomic)
        let values = try? temporary.resourceValues(
            forKeys: [.fileSizeKey, .contentModificationDateKey]
        )
        return try commitStagedCopy(
            trackID: trackID,
            destinationName: destinationName,
            root: root,
            staged: StagedCopy(
                mediaURL: temporary,
                checksumURL: temporaryChecksum,
                size: Int64(values?.fileSize ?? 0),
                digest: digest,
                modificationDate: values?.contentModificationDate
            )
        )
    }

    private func commitStagedCopy(
        trackID: UUID,
        destinationName: String,
        root: URL,
        staged: StagedCopy
    ) throws -> CopyResult {
        let destination = root.appendingPathComponent(destinationName)
        let oldSiblings = try mediaFiles(in: root, identifiers: [trackID.uuidString])
            .filter { $0 != destination && $0 != staged.mediaURL }
        let checksum = checksumURL(for: destination)
        let backupToken = UUID().uuidString
        let destinationBackup = root.appendingPathComponent(".\(trackID.uuidString).\(backupToken).destination")
        let checksumBackup = root.appendingPathComponent(".\(trackID.uuidString).\(backupToken).checksum")
        let siblingBackups = oldSiblings.enumerated().map { index, sibling in
            (
                original: sibling,
                backup: root.appendingPathComponent(".\(trackID.uuidString).\(backupToken).sibling-\(index)")
            )
        }
        var destinationBackedUp = false
        var checksumBackedUp = false
        var destinationInstalled = false
        var checksumInstalled = false
        var movedSiblings: [(original: URL, backup: URL)] = []
        var committed = false
        defer {
            if committed {
                try? fileManager.removeItem(at: destinationBackup)
                try? fileManager.removeItem(at: checksumBackup)
                for sibling in siblingBackups {
                    try? fileManager.removeItem(at: sibling.backup)
                }
            } else {
                if checksumInstalled {
                    try? fileManager.removeItem(at: checksum)
                }
                if checksumBackedUp {
                    try? fileManager.moveItem(at: checksumBackup, to: checksum)
                }
                if destinationInstalled {
                    try? fileManager.removeItem(at: destination)
                }
                if destinationBackedUp {
                    try? fileManager.moveItem(at: destinationBackup, to: destination)
                }
                for sibling in movedSiblings.reversed() {
                    try? fileManager.moveItem(at: sibling.backup, to: sibling.original)
                }
            }
        }
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.moveItem(at: destination, to: destinationBackup)
            destinationBackedUp = true
        }
        try fileManager.moveItem(at: staged.mediaURL, to: destination)
        destinationInstalled = true
        if fileManager.fileExists(atPath: checksum.path) {
            try fileManager.moveItem(at: checksum, to: checksumBackup)
            checksumBackedUp = true
        }
        try fileManager.moveItem(at: staged.checksumURL, to: checksum)
        checksumInstalled = true
        for sibling in siblingBackups {
            try fileManager.moveItem(at: sibling.original, to: sibling.backup)
            movedSiblings.append(sibling)
        }
        committed = true
        invalidateDirectoryIndex(for: root)
        return CopyResult(
            url: destination,
            size: staged.size,
            digest: staged.digest,
            modificationDate: staged.modificationDate
        )
    }

    private func destinationName(trackID: UUID, sourceURL: URL) -> String {
        let ext = sourceURL.pathExtension.lowercased()
        return ext.isEmpty ? trackID.uuidString : "\(trackID.uuidString).\(ext)"
    }

    private func removeFileIfPresent(at url: URL) throws {
        do {
            try fileManager.removeItem(at: url)
        } catch let error as NSError
            where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
            // Missing checksum sidecars are tolerated, including a concurrent
            // cleanup race; every other deletion failure is surfaced.
        } catch {
            throw error
        }
    }

    private func loadManifestIfNeeded() throws {
        guard !manifestLoaded else { return }
        guard fileManager.fileExists(atPath: smartManifestURL.path) else {
            manifest = SmartManifest()
            manifestLoaded = true
            manifestNeedsSave = false
            return
        }

        do {
            let data = try Data(contentsOf: smartManifestURL)
            manifest = try JSONDecoder().decode(SmartManifest.self, from: data)
            manifestLoaded = true
            manifestNeedsSave = false
        } catch {
            manifest = try rebuildSmartManifest()
            manifestLoaded = true
            markManifestDirty()
        }
    }

    private func rebuildSmartManifest() throws -> SmartManifest {
        var rebuilt = SmartManifest()
        for url in try mediaFiles(in: smartRoot) {
            let identifier = cacheIdentifier(for: url)
            guard UUID(uuidString: identifier) != nil else { continue }
            let checksum = checksumURL(for: url)
            guard fileManager.fileExists(atPath: checksum.path) else { continue }
            let expected = try String(contentsOf: checksum, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !expected.isEmpty, expected == (try hashFile(url)) else { continue }
            let values = try url.resourceValues(
                forKeys: [.fileSizeKey, .contentModificationDateKey]
            )
            let candidate = ManifestEntry(
                fileName: url.lastPathComponent,
                size: Int64(values.fileSize ?? 0),
                digest: expected,
                modificationDate: values.contentModificationDate,
                lastAccess: values.contentModificationDate ?? .distantPast
            )
            if let previous = rebuilt.entries[identifier] {
                let previousDate = previous.modificationDate ?? .distantPast
                let candidateDate = candidate.modificationDate ?? .distantPast
                guard candidateDate > previousDate
                    || (candidateDate == previousDate && candidate.fileName < previous.fileName) else {
                    continue
                }
            }
            rebuilt.entries[identifier] = candidate
        }
        return rebuilt
    }

    private func markManifestDirty() {
        manifestNeedsSave = true
        guard manifestFlushTask == nil else { return }
        manifestFlushTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.manifestFlushDelayNanoseconds)
            } catch {
                return
            }
            await self?.flushScheduledManifest()
        }
    }

    private func flushScheduledManifest() {
        manifestFlushTask = nil
        guard manifestNeedsSave else { return }
        do {
            try saveManifest()
            manifestNeedsSave = false
        } catch {
            // Keep the dirty marker. A later lookup or durable cache mutation
            // will retry instead of silently forgetting the newest LRU state.
        }
    }

    private func persistManifestNow() throws {
        manifestFlushTask?.cancel()
        manifestFlushTask = nil
        guard manifestNeedsSave else { return }
        try saveManifest()
        manifestNeedsSave = false
    }

    private func saveManifest() throws {
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: smartManifestURL, options: .atomic)
    }

    private func indexedMediaFiles(
        in root: URL,
        identifiers: Set<String>? = nil
    ) throws -> [URL] {
        let now = ProcessInfo.processInfo.systemUptime
        let existingIndex = root == pinnedRoot ? pinnedDirectoryIndex : smartDirectoryIndex
        let index: DirectoryIndex
        if let existingIndex,
           now - existingIndex.loadedAt < Self.directoryIndexTTL {
            index = existingIndex
        } else {
            let files = try mediaFiles(in: root)
            let grouped = Dictionary(grouping: files, by: cacheIdentifier(for:))
            index = DirectoryIndex(filesByIdentifier: grouped, loadedAt: now)
            if root == pinnedRoot {
                pinnedDirectoryIndex = index
            } else {
                smartDirectoryIndex = index
            }
        }

        let result: [URL]
        if let identifiers {
            result = identifiers.flatMap { index.filesByIdentifier[$0] ?? [] }
        } else {
            result = index.filesByIdentifier.values.flatMap { $0 }
        }
        return result.sorted { $0.path < $1.path }
    }

    private func invalidateDirectoryIndex(for root: URL) {
        if root == pinnedRoot {
            pinnedDirectoryIndex = nil
        } else {
            smartDirectoryIndex = nil
        }
    }

    private func mediaFiles(
        in root: URL,
        identifiers: Set<String>? = nil
    ) throws -> [URL] {
        let urls = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
        return urls.filter { url in
            let name = url.lastPathComponent
            guard !name.hasPrefix("."),
                  url.pathExtension.lowercased() != "sha256",
                  name != "manifest.json",
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                return false
            }
            guard let identifiers else { return true }
            return identifiers.contains(cacheIdentifier(for: url))
        }
    }

    private func cacheIdentifier(for url: URL) -> String {
        let name = url.lastPathComponent
        if UUID(uuidString: name) != nil { return name }
        return url.deletingPathExtension().lastPathComponent
    }

    private func freshResourceValues(for url: URL) -> URLResourceValues? {
        var uncachedURL = url
        uncachedURL.removeAllCachedResourceValues()
        return try? uncachedURL.resourceValues(
            forKeys: [.fileSizeKey, .contentModificationDateKey]
        )
    }

    private func checksumURL(for file: URL) -> URL {
        file.deletingPathExtension().appendingPathExtension("sha256")
    }

    private func hashFile(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            digest.update(data: chunk)
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func sameManifestEntry(
        _ left: ManifestEntry?,
        _ right: ManifestEntry
    ) -> Bool {
        guard let left else { return false }
        return left.fileName == right.fileName
            && left.size == right.size
            && left.digest == right.digest
            && left.modificationDate == right.modificationDate
            && left.lastAccess == right.lastAccess
    }

    private static func accessOrder(for date: Date) -> UInt64 {
        guard date.timeIntervalSince1970.isFinite else { return 0 }
        let millis = date.timeIntervalSince1970 * 1_000
        guard millis > 0 else { return 0 }
        return UInt64(min(millis, Double(UInt64.max)).rounded(.down))
    }
}
