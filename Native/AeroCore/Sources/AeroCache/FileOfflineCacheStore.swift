import Foundation
import CryptoKit
import AeroDomain

public actor FileOfflineCacheStore: OfflineCacheStore {
    private struct ManifestEntry: Codable {
        var fileName: String
        var size: Int64
        var digest: String
        var lastAccess: Date
    }

    private struct SmartManifest: Codable {
        var entries: [String: ManifestEntry] = [:]
    }

    private let pinnedRoot: URL
    private let smartRoot: URL
    private let smartManifestURL: URL
    private let evictionPlanner: any CacheEvictionPlanner
    private var manifest = SmartManifest()
    private var manifestLoaded = false

    public init(
        fileManager: FileManager = .default,
        evictionPlanner: any CacheEvictionPlanner = DeterministicCacheEvictionPlanner()
    ) throws {
        let appSupport = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let caches = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        pinnedRoot = appSupport.appendingPathComponent("AeroMusic/Pinned", isDirectory: true)
        smartRoot = caches.appendingPathComponent("AeroMusic/Smart", isDirectory: true)
        smartManifestURL = smartRoot.appendingPathComponent("manifest.json")
        self.evictionPlanner = evictionPlanner
        try fileManager.createDirectory(at: pinnedRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: smartRoot, withIntermediateDirectories: true)
    }

    public func pin(trackID: UUID, sourceURL: URL) async throws -> URL {
        try copy(trackID: trackID, sourceURL: sourceURL, root: pinnedRoot)
    }

    public func unpin(trackID: UUID) async throws {
        let fm = FileManager.default
        for url in try mediaFiles(in: pinnedRoot, trackID: trackID) {
            try? fm.removeItem(at: url)
            try? fm.removeItem(at: checksumURL(for: url))
        }
    }

    public func isPinned(trackID: UUID) async -> Bool {
        (try? mediaFiles(in: pinnedRoot, trackID: trackID).isEmpty == false) ?? false
    }

    /// Resolves an offline copy without touching the source bookmark. Pinned
    /// media is checked first because it is never eligible for LRU eviction;
    /// smart-cache hits refresh their explicit last-access timestamp.
    public func cachedURL(trackID: UUID) async -> URL? {
        let pinned = (try? mediaFiles(in: pinnedRoot, trackID: trackID)) ?? []
        let smart = (try? mediaFiles(in: smartRoot, trackID: trackID)) ?? []
        let candidates = pinned + smart
        let pinnedCandidates = candidates.filter { $0.deletingLastPathComponent() == pinnedRoot }
        let smartCandidates = candidates.filter { $0.deletingLastPathComponent() == smartRoot }
        for url in pinnedCandidates + smartCandidates {
            guard FileManager.default.fileExists(atPath: url.path),
                  let expected = try? String(contentsOf: checksumURL(for: url), encoding: .utf8),
                  let actual = try? hashFile(url),
                  expected.trimmingCharacters(in: .whitespacesAndNewlines) == actual else {
                continue
            }
            if url.deletingLastPathComponent() == smartRoot {
                try? loadManifestIfNeeded()
                if var entry = manifest.entries[trackID.uuidString] {
                    entry.lastAccess = .now
                    manifest.entries[trackID.uuidString] = entry
                    try? saveManifest()
                }
            }
            return url
        }
        return nil
    }

    public func prefetch(trackID: UUID, sourceURL: URL) async throws -> URL {
        let url = try copy(trackID: trackID, sourceURL: sourceURL, root: smartRoot)
        try loadManifestIfNeeded()
        manifest.entries[trackID.uuidString] = ManifestEntry(
            fileName: url.lastPathComponent,
            size: Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0),
            digest: try hashFile(url),
            lastAccess: .now
        )
        try saveManifest()
        return url
    }

    public func trim(to budgetBytes: Int64) async throws {
        let fm = FileManager.default
        try loadManifestIfNeeded()
        let files = try mediaFiles(in: smartRoot)
        var entries: [(url: URL, identifier: String, size: Int64, lastAccess: Date)] = []
        entries.reserveCapacity(files.count)
        for url in files {
            if let entry = manifest.entries.values.first(where: { $0.fileName == url.lastPathComponent }) {
                entries.append((url, url.deletingPathExtension().lastPathComponent, entry.size, entry.lastAccess))
                continue
            }
            let size = Int64((try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            entries.append((url, url.deletingPathExtension().lastPathComponent, size, .distantPast))
        }
        let planEntries = entries.map { entry in
            CacheEvictionEntry(
                identifier: entry.identifier,
                sizeBytes: entry.size,
                lastAccessOrder: Self.accessOrder(for: entry.lastAccess)
            )
        }
        let evictions = evictionPlanner.plan(entries: planEntries, budgetBytes: budgetBytes)
        for identifier in evictions {
            for entry in entries where entry.identifier == identifier {
                try? fm.removeItem(at: entry.url)
                try? fm.removeItem(at: checksumURL(for: entry.url))
                manifest.entries = manifest.entries.filter { $0.value.fileName != entry.url.lastPathComponent }
            }
        }
        try saveManifest()
    }

    public func verify(trackID: UUID) async -> Bool {
        await cachedURL(trackID: trackID) != nil
    }

    private func copy(trackID: UUID, sourceURL: URL, root: URL) throws -> URL {
        let fm = FileManager.default
        let ownsSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer { if ownsSecurityScope { sourceURL.stopAccessingSecurityScopedResource() } }
        let ext = sourceURL.pathExtension.lowercased()
        let destinationName = ext.isEmpty ? trackID.uuidString : "\(trackID.uuidString).\(ext)"
        let destination = root.appendingPathComponent(destinationName)
        let temporary = root.appendingPathComponent(".\(trackID.uuidString).\(UUID().uuidString).part")
        let checksum = checksumURL(for: destination)
        let temporaryChecksum = checksum.appendingPathExtension("part")
        defer {
            try? fm.removeItem(at: temporary)
            try? fm.removeItem(at: temporaryChecksum)
        }
        try fm.copyItem(at: sourceURL, to: temporary)
        let digest = try hashFile(temporary)
        try Data(digest.utf8).write(to: temporaryChecksum, options: .atomic)
        if fm.fileExists(atPath: destination.path) {
            _ = try fm.replaceItemAt(destination, withItemAt: temporary, backupItemName: nil,
                                     options: .usingNewMetadataOnly)
        } else {
            try fm.moveItem(at: temporary, to: destination)
        }
        if fm.fileExists(atPath: checksum.path) {
            _ = try fm.replaceItemAt(checksum, withItemAt: temporaryChecksum, backupItemName: nil,
                                     options: .usingNewMetadataOnly)
        } else {
            try fm.moveItem(at: temporaryChecksum, to: checksum)
        }
        return destination
    }

    private func loadManifestIfNeeded() throws {
        guard !manifestLoaded else { return }
        manifestLoaded = true
        guard let data = try? Data(contentsOf: smartManifestURL) else { return }
        manifest = (try? JSONDecoder().decode(SmartManifest.self, from: data)) ?? SmartManifest()
    }

    private func saveManifest() throws {
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: smartManifestURL, options: .atomic)
    }

    private func mediaFiles(in root: URL, trackID: UUID? = nil) throws -> [URL] {
        let urls = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isRegularFileKey])
        return urls.filter { url in
            guard url.pathExtension.lowercased() != "sha256", url.lastPathComponent != "manifest.json" else { return false }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return false }
            guard let trackID else { return true }
            return url.lastPathComponent == trackID.uuidString || url.lastPathComponent.hasPrefix(trackID.uuidString + ".")
        }
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

    private static func accessOrder(for date: Date) -> UInt64 {
        guard date.timeIntervalSince1970.isFinite else { return 0 }
        let millis = date.timeIntervalSince1970 * 1_000
        guard millis > 0 else { return 0 }
        return UInt64(min(millis, Double(UInt64.max)).rounded(.down))
    }
}
