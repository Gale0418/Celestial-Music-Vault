import Foundation
import AVFoundation
import SwiftUI
import SwiftData
import Observation
import CMVDomain
import CMVLibrary
import CMVPlayback
import CMVThemes
import CMVCache
#if os(macOS)
import AppKit
#endif

private actor ScanBatchState {
    private var seenIdentifiers = Set<String>()
    private var encounteredIssue = false

    func accept(_ identifiers: [String]) throws {
        for identifier in identifiers {
            guard seenIdentifiers.insert(identifier).inserted else {
                throw CocoaError(.fileReadCorruptFile)
            }
        }
    }

    func registerIssue() -> Bool {
        let isFirstIssue = !encounteredIssue
        encounteredIssue = true
        return isFirstIssue
    }

    func completedWithoutIssues() -> Bool { !encounteredIssue }
}

private struct SourceStatusProbeResult: Sendable {
    let id: UUID
    let refreshedBookmark: Data?
    let status: MediaSourceStatus
}

private struct RustCacheEvictionPlanner: CacheEvictionPlanner {
    let client: CMVCoreRSClient

    func plan(entries: [CacheEvictionEntry], budgetBytes: Int64) -> [String] {
        let rustEntries = entries.map {
            RustCacheEvictionEntry(
                identifier: $0.identifier,
                sizeBytes: $0.sizeBytes,
                pinned: $0.pinned,
                lastAccessOrder: $0.lastAccessOrder
            )
        }
        if let plan = try? client.planEviction(entries: rustEntries, budgetBytes: budgetBytes) {
            return plan
        }
        return DeterministicCacheEvictionPlanner().plan(entries: entries, budgetBytes: budgetBytes)
    }
}

@MainActor
@Observable
final class AppModel {
    private static let themeDefaultsKey = "CMV.selectedTheme"
    var selection: LibraryDestination? = .nowPlaying
    var showingImporter = false
    var showingQueue = true
    var errorMessage: String?
    var selectedTheme: CMVThemeID {
        didSet { UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.themeDefaultsKey) }
    }
    private(set) var backgroundActivities: [UUID: BackgroundActivity] = [:]
    private(set) var pinnedTrackIDs: Set<UUID> = []
    let playback: NativePlaybackEngine
    /// 非音訊曲目由原生 AVPlayer 表面呈現；URL 存在期間保留來源 lease。
    private(set) var videoURL: URL?
    private(set) var videoTrack: Track?
    private(set) var currentTrackID: UUID?

    var currentTrack: Track? { videoTrack ?? playback.queue.current }

    var primaryBackgroundActivity: BackgroundActivity? {
        backgroundActivities.values.sorted {
            if $0.kind.priority != $1.kind.priority { return $0.kind.priority > $1.kind.priority }
            return $0.startedAt < $1.startedAt
        }.first
    }

    var additionalBackgroundActivityCount: Int { max(0, backgroundActivities.count - 1) }

    private let sourceProvider = SecurityScopedMediaSourceProvider()
    private let sourceAccess = SourceAccessCoordinator()
    private let scanner = IncrementalScanner()
    private let rustCore: CMVCoreRSClient
    private let analyzer = NativeAudioAnalyzer()
    private let smartDJ = NativeSmartDJService()
    private let cacheStore: FileOfflineCacheStore?
    /// 保持佇列涉及的 security-scoped lease 到目前播放結束，避免 NAS／檔案 App 權限在解碼中途失效。
    private var playbackAccessLeases: [SecurityScopedResourceLease] = []
    private var videoAccessLeases: [SecurityScopedResourceLease] = []
    private var mixedQueue: [Track]?
    private var activePlaybackContext: ModelContext?

    init() {
        selectedTheme = UserDefaults.standard.string(forKey: Self.themeDefaultsKey)
            .flatMap(CMVThemeID.init(rawValue:)) ?? .crimsonNebula
        let core = CMVCoreRSClient()
        rustCore = core
        cacheStore = try? FileOfflineCacheStore(evictionPlanner: RustCacheEvictionPlanner(client: core))
        playback = NativePlaybackEngine { engineRate, current, next in
            let plan = try core.planPlayback(
                engineSampleRateHz: engineRate,
                current: RustTimelineTrack(current),
                next: RustTimelineTrack(next)
            )
            return PlaybackSchedulePlan(
                currentStartFrame: plan.currentStartFrame,
                currentFrameCount: plan.currentFrameCount,
                nextStartEngineFrame: plan.nextStartEngineFrame,
                currentGainLinear: plan.currentGainLinear,
                nextGainLinear: plan.nextGainLinear
            )
        }
        playback.onCurrentTrackChanged = { [weak self] track in
            self?.currentTrackID = track?.id
        }
        playback.onQueueFinished = { [weak self] in
            self?.advanceAfterAudioQueue()
        }
    }

    @discardableResult
    func beginBackgroundActivity(kind: BackgroundActivityKind, title: String, detail: String? = nil) -> UUID {
        let id = UUID()
        backgroundActivities[id] = BackgroundActivity(
            id: id,
            kind: kind,
            title: title,
            detail: detail,
            startedAt: .now
        )
        return id
    }

    func updateBackgroundActivity(_ id: UUID, detail: String?) {
        guard var activity = backgroundActivities[id] else { return }
        activity.detail = detail
        backgroundActivities[id] = activity
    }

    func endBackgroundActivity(_ id: UUID) {
        backgroundActivities[id] = nil
    }

    func addSource(_ url: URL, context: ModelContext) {
        addSources([url], context: context)
    }

    /// 批次加入資料夾來源，讓 Finder／檔案 App 的多選結果只需一次存檔，
    /// 並在同一批次內去除重複路徑。單一資料夾仍透過這個入口維持相同行為。
    func addSources(_ urls: [URL], context: ModelContext) {
        let directories = urls.filter(\.hasDirectoryPath)
        guard !directories.isEmpty else { return }

        let existingPaths = Set((try? context.fetch(FetchDescriptor<MediaSourceRecord>()))?.compactMap { source in
            try? sourceProvider.resolveWithRefresh(bookmark: source.bookmarkData).url.standardizedFileURL.path
        } ?? [])
        var seenPaths = existingPaths
        var pendingSources: [MediaSourceRecord] = []
        var failures: [String] = []

        for url in directories {
            let normalizedURL = url.standardizedFileURL
            guard seenPaths.insert(normalizedURL.path).inserted else { continue }
            do {
                let ownsAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if ownsAccess { url.stopAccessingSecurityScopedResource() }
                }
                // The URL returned by the system picker carries the sandbox
                // grant. A newly standardized URL has the same path but can
                // no longer be used to mint a security-scoped bookmark.
                let bookmark = try sourceProvider.makeBookmark(for: url)
                let source = MediaSourceRecord(
                    displayName: normalizedURL.lastPathComponent,
                    bookmarkData: bookmark,
                    status: .scanning
                )
                context.insert(source)
                pendingSources.append(source)
            } catch {
                let cocoaError = error as NSError
                failures.append(
                    "\(normalizedURL.lastPathComponent)（\(cocoaError.domain) \(cocoaError.code)：\(error.localizedDescription)）"
                )
            }
        }

        guard !pendingSources.isEmpty else {
            if !failures.isEmpty {
                errorMessage = "無法加入資料夾：" + failures.joined(separator: "、")
            }
            return
        }

        do {
            try context.save()
        } catch {
            // Keep unrelated pending edits intact, but never leave this failed
            // batch queued for a later, unrelated context.save().
            for source in pendingSources {
                context.delete(source)
            }
            errorMessage = error.localizedDescription
            return
        }

        for source in pendingSources {
            Task { await scan(source: source, context: context) }
        }
        if !failures.isEmpty {
            errorMessage = "部分資料夾無法加入：" + failures.joined(separator: "、")
        }
    }

    func restoreAndScan(_ source: MediaSourceRecord, context: ModelContext) {
        Task { await scan(source: source, context: context) }
    }

    /// Re-checks persisted sources when the app shell appears. A source that
    /// was unavailable during the previous session is never removed, and a
    /// stale bookmark is refreshed in place when Apple can still resolve it.
    func refreshSourceStatuses(_ sources: [MediaSourceRecord], context: ModelContext) async {
        guard !sources.isEmpty else { return }
        let activityID = beginBackgroundActivity(kind: .scanning, title: "正在確認音樂來源")
        defer { endBackgroundActivity(activityID) }
        let probes = sources.map { (id: $0.id, bookmark: $0.bookmarkData) }
        let provider = sourceProvider
        let results = await Task.detached(priority: .utility) {
            probes.map { probe in
                do {
                    let resolution = try provider.resolveWithRefresh(bookmark: probe.bookmark)
                    let ownsScope = resolution.url.startAccessingSecurityScopedResource()
                    defer { if ownsScope { resolution.url.stopAccessingSecurityScopedResource() } }
                    let status: MediaSourceStatus = FileManager.default.isReadableFile(atPath: resolution.url.path)
                        ? .available : .offline
                    return SourceStatusProbeResult(id: probe.id, refreshedBookmark: resolution.refreshedBookmark, status: status)
                } catch {
                    return SourceStatusProbeResult(id: probe.id, refreshedBookmark: nil, status: .permissionRequired)
                }
            }
        }.value
        let sourcesByID = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        var didChange = false
        for result in results {
            guard let source = sourcesByID[result.id] else { continue }
            if let refreshedBookmark = result.refreshedBookmark {
                source.bookmarkData = refreshedBookmark
                source.updatedAt = .now
                didChange = true
            }
            if source.status != result.status {
                source.status = result.status
                didChange = true
            }
        }
        if didChange {
            try? context.save()
        }
    }

    /// 讓使用者以原生資料夾選擇器更新過期／撤銷的 bookmark，保留既有曲目與歌單。
    func reauthorizeSource(_ source: MediaSourceRecord, with url: URL, context: ModelContext) {
        do {
            source.bookmarkData = try sourceProvider.makeBookmark(for: url)
            source.status = .scanning
            source.updatedAt = .now
            try context.save()
            Task { await scan(source: source, context: context) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 從曲目所屬來源解析實體 URL，再交給原生雙節點播放管線。
    /// UI 只需要呼叫這個入口，不得自行拼接或繞過 security-scoped bookmark。
    func play(track: Track, context: ModelContext) {
        play(tracks: [track], startingAt: 0, context: context)
    }

    /// 關閉目前影片並釋放其 security-scoped 存取權。影片 utility window
    /// 或 iPad sheet 消失時呼叫，確保 lease 不會提早結束也不會永久佔用。
    func stopVideoPlayback() {
        let wasVideoPlayback = videoURL != nil || videoTrack != nil
        videoURL = nil
        videoTrack = nil
        videoAccessLeases.removeAll()
        if wasVideoPlayback {
            mixedQueue = nil
            if !playback.queue.tracks.isEmpty { playback.clearQueue() }
        }
    }

    /// Transport controls use this entry point so an empty queue still has a
    /// useful, accessible action instead of silently swallowing an engine
    /// error.
    func playOrResume(context: ModelContext) {
        guard videoURL == nil else { return }
        if playback.queue.current == nil {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let repository = SwiftDataLibraryRepository(container: context.container)
                do {
                    let candidates = try await repository.tracks(matching: "", limit: 200, offset: 0)
                    guard let first = candidates.first(where: { $0.availability == .available }) else {
                        errorMessage = "曲庫目前沒有可播放的歌曲。請先加入音樂來源並完成索引。"
                        return
                    }
                    play(track: first, context: context)
                } catch {
                    errorMessage = "無法載入曲庫：\(error.localizedDescription)"
                }
            }
            return
        }
        do {
            try playback.play()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// AVPlayer 結束目前影片後，沿用相同佇列銜接下一首；下一首若是
    /// 音訊，會回到原生音訊引擎，若仍是影片則更新影片表面。
    func advanceAfterVideo(context: ModelContext) {
        guard videoURL != nil else { return }
        let queue = playback.queue
        let nextIndex = queue.currentIndex + 1
        guard queue.tracks.indices.contains(nextIndex) else {
            stopVideoPlayback()
            return
        }
        play(tracks: queue.tracks, startingAt: nextIndex, context: context)
    }

    private func advanceAfterAudioQueue() {
        guard let mixedQueue, let context = activePlaybackContext,
              let currentID = currentTrackID,
              let currentIndex = mixedQueue.firstIndex(where: { $0.id == currentID }) else { return }
        let nextIndex = currentIndex + 1
        guard mixedQueue.indices.contains(nextIndex) else {
            self.mixedQueue = nil
            return
        }
        play(tracks: mixedQueue, startingAt: nextIndex, context: context)
    }

    /// 播放整個佇列（歌單可跨多個來源）；所有來源都在播放生命週期內持有 lease。
    func play(tracks: [Track], startingAt: Int = 0, context: ModelContext) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let activityID = beginBackgroundActivity(kind: .playback, title: "正在準備播放")
            defer { endBackgroundActivity(activityID) }
            do {
                guard !tracks.isEmpty else { return }
                let sources = try context.fetch(FetchDescriptor<MediaSourceRecord>())
                let sourcesByID = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
                var roots: [UUID: URL] = [:]
                var leases: [SecurityScopedResourceLease] = []
                var resolvedURLs: [UUID: URL] = [:]
                guard tracks.indices.contains(startingAt) else { return }
                let selectedTrack = tracks[startingAt]
                activePlaybackContext = context
                let selectedURL: URL
                if let cacheStore, let cachedURL = await cacheStore.cachedURL(trackID: selectedTrack.id) {
                    selectedURL = cachedURL
                } else {
                    guard let source = sourcesByID[selectedTrack.sourceID] else {
                        throw MediaSourceAccessError.accessDenied
                    }
                    let root = try resolve(source: source, context: context)
                    roots[selectedTrack.sourceID] = root
                    leases.append(try await sourceAccess.lease(for: root))
                    selectedURL = try Self.safeTrackURL(root: root, relativePath: selectedTrack.relativePath)
                }
                resolvedURLs[selectedTrack.id] = selectedURL
                let selectedAsset = AVURLAsset(url: selectedURL)
                let selectedAssetTracks: [AVAssetTrack]
                do {
                    selectedAssetTracks = try await selectedAsset.load(.tracks)
                } catch {
                    throw MediaScanError.unreadableFile(path: selectedTrack.relativePath)
                }
                guard !selectedAssetTracks.isEmpty else {
                    throw MediaScanError.unreadableFile(path: selectedTrack.relativePath)
                }
                let selectedAssetIsPlayable: Bool
                do {
                    selectedAssetIsPlayable = try await selectedAsset.load(.isPlayable)
                } catch {
                    throw MediaScanError.unreadableFile(path: selectedTrack.relativePath)
                }
                guard selectedAssetIsPlayable else {
                    throw MediaScanError.unsupportedFile(path: selectedTrack.relativePath)
                }
                if selectedAssetTracks.contains(where: { $0.mediaType == .video }) {
                    let selectedVideoTrack = selectedTrack
                    let url = selectedURL
                    playback.clearQueue()
                    playback.setQueue(PlaybackQueue(tracks: tracks, currentIndex: startingAt))
                    mixedQueue = tracks
                    playbackAccessLeases.removeAll()
                    videoAccessLeases = leases
                    videoTrack = selectedVideoTrack
                    videoURL = url
                    let repository = SwiftDataLibraryRepository(container: context.container)
                    try? await repository.recordPlayback(trackID: selectedVideoTrack.id, skipped: false)
                    return
                }

                stopVideoPlayback()
                // Newly scanned records carry an explicit media kind. Legacy
                // records default to audio, so movie-container extensions are
                // kept out of a later audio-only queue unless they are the
                // selected item that was just probed as audio-only above.
                let movieContainerExtensions: Set<String> = ["mp4", "mov", "m4v"]
                let nextVideoIndex = tracks.indices.dropFirst(startingAt + 1).first { index in
                    let track = tracks[index]
                    let ext = URL(fileURLWithPath: track.relativePath).pathExtension.lowercased()
                    return track.mediaKind == .video || movieContainerExtensions.contains(ext)
                } ?? tracks.count
                let audioTracks = Array(tracks[startingAt..<nextVideoIndex]).filter { track in
                    track.id == selectedTrack.id || track.mediaKind != .video
                }
                guard !audioTracks.isEmpty else {
                    throw MediaScanError.unsupportedFile(path: selectedTrack.relativePath)
                }
                guard let audioIndex = audioTracks.firstIndex(of: selectedTrack) else {
                    throw MediaScanError.unsupportedFile(path: selectedTrack.relativePath)
                }
                for track in audioTracks.dropFirst() {
                    if let cacheStore, let cachedURL = await cacheStore.cachedURL(trackID: track.id) {
                        resolvedURLs[track.id] = cachedURL
                        continue
                    }
                    guard let source = sourcesByID[track.sourceID] else {
                        throw MediaSourceAccessError.accessDenied
                    }
                    let root: URL
                    if let cached = roots[track.sourceID] {
                        root = cached
                    } else {
                        root = try resolve(source: source, context: context)
                        roots[track.sourceID] = root
                        leases.append(try await sourceAccess.lease(for: root))
                    }
                    resolvedURLs[track.id] = try Self.safeTrackURL(root: root, relativePath: track.relativePath)
                }
                try playback.load(PlaybackQueue(tracks: audioTracks, currentIndex: audioIndex), resolvedURLs: resolvedURLs)
                mixedQueue = nextVideoIndex < tracks.count ? tracks : nil
                playbackAccessLeases = leases
                try playback.play()
                let repository = SwiftDataLibraryRepository(container: context.container)
                try? await repository.recordPlayback(trackID: selectedTrack.id, skipped: false)
                if let cacheStore {
                    let policy = CachePolicy()
                    let prefetchTracks = Array(audioTracks.dropFirst().prefix(policy.prefetchCount))
                    let prefetchURLs = resolvedURLs
                    let cacheActivityID = beginBackgroundActivity(
                        kind: .cache,
                        title: "正在更新智慧快取",
                        detail: "預取接下來的歌曲"
                    )
                    Task.detached(priority: .utility) { [weak self] in
                        defer {
                            Task { @MainActor [weak self] in
                                self?.endBackgroundActivity(cacheActivityID)
                            }
                        }
                        for track in prefetchTracks {
                            guard let url = prefetchURLs[track.id] else { continue }
                            _ = try? await cacheStore.prefetch(trackID: track.id, sourceURL: url)
                        }
                        try? await cacheStore.trim(to: policy.smartBudgetBytes)
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private static func safeTrackURL(root: URL, relativePath: String) throws -> URL {
        let root = root.standardizedFileURL
        let candidate = root.appendingPathComponent(relativePath).standardizedFileURL
        guard candidate.path == root.path || candidate.path.hasPrefix(root.path + "/") else {
            throw MediaSourceAccessError.accessDenied
        }
        return candidate
    }

    /// 來源仍可使用時自動更新 stale bookmark；只有無法刷新才需要使用者重新授權。
    private func resolve(source: MediaSourceRecord, context: ModelContext) throws -> URL {
        let resolution = try sourceProvider.resolveWithRefresh(bookmark: source.bookmarkData)
        if let refreshedBookmark = resolution.refreshedBookmark {
            source.bookmarkData = refreshedBookmark
            source.updatedAt = .now
            try context.save()
        }
        return resolution.url
    }

    private func scan(source: MediaSourceRecord, context: ModelContext) async {
        let activityID = beginBackgroundActivity(
            kind: .scanning,
            title: "正在索引「\(source.displayName)」",
            detail: "準備讀取來源"
        )
        defer { endBackgroundActivity(activityID) }
        do {
            let url = try resolve(source: source, context: context)
            let accessLease = try await sourceAccess.lease(for: url)
            let sourceID = source.id
            source.status = .scanning
            let repository = SwiftDataLibraryRepository(container: context.container)
            let existing = try await repository.tracks(sourceID: sourceID)
            let existingByIdentifier = existing.reduce(into: [String: RustTrackSnapshot]()) { result, track in
                if result[track.fileIdentifier] == nil { result[track.fileIdentifier] = RustTrackSnapshot(track: track) }
            }
            let scanID = await repository.beginScan(sourceID: sourceID)
            let batchState = ScanBatchState()
            let rustCore = rustCore
            try await scanner.scan(
                url: url,
                batchSize: 400,
                accessAlreadyGranted: true,
                onBatch: { batch in
                    try await batchState.accept(batch.map(\.fileIdentifier))
                    let scannedBatch = batch.map(RustScannedFile.init(file:))
                    let existingBatch = batch.compactMap { existingByIdentifier[$0.fileIdentifier] }
                    let reconciliation = try await Task.detached(priority: .utility) {
                        try rustCore.reconcile(existing: existingBatch, scanned: scannedBatch, sourceReachable: true)
                    }.value
                    var byIdentifier = [String: ScannedMediaFile]()
                    for file in batch where byIdentifier[file.fileIdentifier] == nil {
                        byIdentifier[file.fileIdentifier] = file
                    }
                    let upserts = reconciliation.upserts.compactMap { byIdentifier[$0.file.identifier] }
                    try await repository.applyScanBatch(upserts, sourceID: sourceID, scanID: scanID)
                },
                onProgress: { [weak self] progress in
                    await MainActor.run {
                        let path = progress.currentPath.isEmpty ? nil : progress.currentPath
                        self?.updateBackgroundActivity(
                            activityID,
                            detail: path.map { "已處理 \(progress.processed) 首 · \($0)" }
                                ?? "已處理 \(progress.processed) 首"
                        )
                    }
                },
                onIssue: { [weak self] issue in
                    let shouldPresent = await batchState.registerIssue()
                    guard shouldPresent else { return }
                    await MainActor.run {
                        self?.errorMessage = issue.localizedDescription
                    }
                }
            )
            _ = accessLease
            let scanCompletedWithoutIssues = await batchState.completedWithoutIssues()
            try await repository.finishScan(
                sourceID: sourceID,
                scanID: scanID,
                sourceWasReachable: scanCompletedWithoutIssues
            )
            source.status = .available
            source.lastSuccessfulScan = .now
            source.updatedAt = .now
            try context.save()
        } catch {
            if case MediaSourceAccessError.staleBookmark = error {
                source.status = .permissionRequired
            } else {
                source.status = .offline
            }
            errorMessage = error.localizedDescription
            try? context.save()
        }
    }

    func searchTracks(query: String, context: ModelContext, limit: Int = 200, offset: Int = 0) async -> [Track] {
        let repository = SwiftDataLibraryRepository(container: context.container)
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeLimit = max(1, limit)
        let safeOffset = max(0, offset)
        if normalizedQuery.isEmpty {
            return (try? await repository.tracks(matching: "", limit: safeLimit, offset: safeOffset)) ?? []
        }
        let candidateLimit = max(safeLimit + safeOffset, 500)
        let snapshot = (try? await repository.tracks(
            matching: query, limit: candidateLimit, offset: 0
        )) ?? []
        let core = rustCore
        let rustTracks = snapshot.map(RustSearchTrack.init(track:))
        let ranked: [RustSearchResult]
        do {
            ranked = try await Task.detached(priority: .userInitiated) {
                try core.search(query: query, tracks: rustTracks, limit: safeLimit + safeOffset)
            }.value
        } catch {
            let normalized = normalizedQuery.lowercased()
            return snapshot.filter { normalized.isEmpty ||
                [$0.title, $0.artist, $0.album].contains(where: {
                    $0.range(of: normalized, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                })
            }.dropFirst(safeOffset).prefix(safeLimit).map { $0 }
        }
        let byID = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.id.uuidString, $0) })
        return ranked.dropFirst(safeOffset).prefix(safeLimit).compactMap { byID[$0.identifier] }
    }

    func trackIDs(matching query: String, context: ModelContext) async -> [UUID] {
        let repository = SwiftDataLibraryRepository(container: context.container)
        do {
            return try await repository.trackIDs(matching: query)
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func tracks(ids: [UUID], context: ModelContext) async -> [Track] {
        let repository = SwiftDataLibraryRepository(container: context.container)
        do {
            return try await repository.tracks(ids: ids)
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func excludeTracks(ids: Set<UUID>, context: ModelContext) async -> Bool {
        guard !ids.isEmpty else { return true }
        let activityID = beginBackgroundActivity(
            kind: .library,
            title: "正在從 CMV 移出曲目",
            detail: "保留原始檔案 · \(ids.count) 首"
        )
        defer { endBackgroundActivity(activityID) }
        do {
            let repository = SwiftDataLibraryRepository(container: context.container)
            try await repository.excludeTracks(ids: Array(ids))
            pinnedTrackIDs.subtract(ids)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func favoriteTracks(context: ModelContext, limit: Int = 200, offset: Int = 0) async -> [Track] {
        let repository = SwiftDataLibraryRepository(container: context.container)
        return (try? await repository.favoriteTracks(limit: limit, offset: max(0, offset))) ?? []
    }

    func play(playlist: Playlist, context: ModelContext) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let repository = SwiftDataLibraryRepository(container: context.container)
            guard let tracks = try? await repository.tracks(ids: playlist.trackIDs) else { return }
            play(tracks: tracks, context: context)
        }
    }

    func setFavorite(_ track: Track, context: ModelContext) {
        Task {
            let repository = SwiftDataLibraryRepository(container: context.container)
            try? await repository.setFavorite(trackID: track.id, isFavorite: !track.isFavorite)
        }
    }

    func setRating(_ track: Track, rating: Int, context: ModelContext) {
        Task {
            let repository = SwiftDataLibraryRepository(container: context.container)
            try? await repository.setRating(trackID: track.id, rating: rating)
        }
    }

    func refreshPinnedStatus(for tracks: [Track]) async {
        guard let cacheStore else { return }
        for track in tracks {
            if await cacheStore.isPinned(trackID: track.id) {
                pinnedTrackIDs.insert(track.id)
            } else {
                pinnedTrackIDs.remove(track.id)
            }
        }
    }

    func togglePinned(_ track: Track, context: ModelContext) {
        guard let cacheStore else {
            errorMessage = "無法建立離線快取。"
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let activityID = beginBackgroundActivity(
                kind: .cache,
                title: pinnedTrackIDs.contains(track.id) ? "正在取消離線釘選" : "正在儲存離線內容",
                detail: track.title
            )
            defer { endBackgroundActivity(activityID) }
            do {
                if pinnedTrackIDs.contains(track.id) {
                    try await cacheStore.unpin(trackID: track.id)
                    pinnedTrackIDs.remove(track.id)
                    return
                }
                let descriptor = FetchDescriptor<MediaSourceRecord>(predicate: #Predicate { source in
                    source.id == track.sourceID
                })
                guard let source = try context.fetch(descriptor).first else {
                    throw MediaSourceAccessError.accessDenied
                }
                let root = try resolve(source: source, context: context)
                let lease = try await sourceAccess.lease(for: root)
                let url = try Self.safeTrackURL(root: root, relativePath: track.relativePath)
                _ = try await cacheStore.pin(trackID: track.id, sourceURL: url)
                _ = lease
                pinnedTrackIDs.insert(track.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func playlists(context: ModelContext) async -> [Playlist] {
        let repository = SwiftDataLibraryRepository(container: context.container)
        return (try? await repository.playlists()) ?? []
    }

    func createPlaylist(context: ModelContext) {
        Task {
            let repository = SwiftDataLibraryRepository(container: context.container)
            _ = try? await repository.createPlaylist(name: "新歌單")
        }
    }

    func renamePlaylist(_ playlist: Playlist, name: String, context: ModelContext) async {
        let repository = SwiftDataLibraryRepository(container: context.container)
        try? await repository.renamePlaylist(id: playlist.id, name: name)
    }

    func deletePlaylist(_ playlist: Playlist, context: ModelContext) async {
        let repository = SwiftDataLibraryRepository(container: context.container)
        try? await repository.deletePlaylist(id: playlist.id)
    }

    func addTrack(_ track: Track, to playlist: Playlist, context: ModelContext) {
        Task {
            let repository = SwiftDataLibraryRepository(container: context.container)
            try? await repository.addTrack(trackID: track.id, toPlaylist: playlist.id)
        }
    }

    func addTracks(_ tracks: [Track], to playlist: Playlist, context: ModelContext) async -> Bool {
        guard !tracks.isEmpty else { return true }
        let activityID = beginBackgroundActivity(
            kind: .library,
            title: "正在加入歌單",
            detail: "\(tracks.count) 首 · \(playlist.name)"
        )
        defer { endBackgroundActivity(activityID) }
        do {
            let repository = SwiftDataLibraryRepository(container: context.container)
            try await repository.addTracks(trackIDs: tracks.map(\.id), toPlaylist: playlist.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    #if os(macOS)
    func revealInFinder(_ track: Track, context: ModelContext) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let descriptor = FetchDescriptor<MediaSourceRecord>(predicate: #Predicate { $0.id == track.sourceID })
                guard let source = try context.fetch(descriptor).first else {
                    throw MediaSourceAccessError.accessDenied
                }
                let root = try resolve(source: source, context: context)
                let lease = try await sourceAccess.lease(for: root)
                let url = try Self.safeTrackURL(root: root, relativePath: track.relativePath)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                _ = lease
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func moveToTrash(_ track: Track, context: ModelContext) async -> Bool {
        let activityID = beginBackgroundActivity(
            kind: .library,
            title: "正在移至垃圾桶",
            detail: track.title
        )
        defer { endBackgroundActivity(activityID) }
        let repository = SwiftDataLibraryRepository(container: context.container)
        let containingPlaylists = ((try? await repository.playlists()) ?? [])
            .filter { $0.trackIDs.contains(track.id) }
        let playlistSnapshot = Dictionary(uniqueKeysWithValues: containingPlaylists.map { ($0.id, $0.trackIDs) })
        do {
            let descriptor = FetchDescriptor<MediaSourceRecord>(predicate: #Predicate { $0.id == track.sourceID })
            guard let source = try context.fetch(descriptor).first else {
                throw MediaSourceAccessError.accessDenied
            }
            let root = try resolve(source: source, context: context)
            let lease = try await sourceAccess.lease(for: root)
            let url = try Self.safeTrackURL(root: root, relativePath: track.relativePath)
            // Persist the CMV-side removal before moving the physical file. A
            // database failure therefore cannot leave a deleted file visible.
            try await repository.excludeTracks(ids: [track.id])
            var trashedURL: NSURL?
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
            } catch {
                try await repository.restoreTracks(ids: [track.id], playlistTrackIDs: playlistSnapshot)
                throw error
            }
            _ = lease
            if let cacheStore { try? await cacheStore.unpin(trackID: track.id) }
            pinnedTrackIDs.remove(track.id)
            return true
        } catch {
            errorMessage = "無法將「\(track.title)」移至垃圾桶：\(error.localizedDescription)"
            return false
        }
    }
    #endif

    func analyze(trackID: UUID, url: URL) async throws -> AnalysisProfile {
        let activityID = beginBackgroundActivity(kind: .analysis, title: "正在分析音訊", detail: url.lastPathComponent)
        defer { endBackgroundActivity(activityID) }
        return try await analyzer.analyze(trackID: trackID, url: url)
    }

    func analyzeAndPersist(trackID: UUID, url: URL, context: ModelContext) async throws -> AnalysisProfile {
        let activityID = beginBackgroundActivity(kind: .analysis, title: "正在分析音訊", detail: url.lastPathComponent)
        defer { endBackgroundActivity(activityID) }
        let profile = try await analyzer.analyze(trackID: trackID, url: url)
        let repository = SwiftDataLibraryRepository(container: context.container)
        try await repository.setAnalysis(trackID: trackID, profile: profile)
        return profile
    }

    func makeSmartQueue(tracks: [Track], profiles: [UUID: AnalysisProfile],
                        history: [UUID: ListeningSignal], limit: Int = 25) async -> [DJSelection] {
        let activityID = beginBackgroundActivity(kind: .analysis, title: "智慧 DJ 正在選歌")
        defer { endBackgroundActivity(activityID) }
        return await smartDJ.makeQueue(from: tracks, profiles: profiles, history: history, limit: limit)
    }
}

private extension RustTrackSnapshot {
    init(track: Track) {
        self.init(
            identifier: track.fileIdentifier,
            relativePath: track.relativePath,
            fileSize: UInt64(max(0, track.fileSize)),
            modifiedAtMillis: Int64(track.modifiedAt.timeIntervalSince1970 * 1_000),
            title: track.title,
            availability: RustTrackAvailability(track.availability)
        )
    }
}

private extension RustTimelineTrack {
    init(_ track: PlaybackTimelineTrack) {
        self.init(
            sampleRateHz: track.sampleRateHz,
            totalFrames: track.totalFrames,
            startFrame: track.startFrame,
            replayGainDB: track.replayGainDB,
            peak: track.peak
        )
    }
}

private extension RustScannedFile {
    init(file: ScannedMediaFile) {
        self.init(
            identifier: file.fileIdentifier,
            relativePath: file.relativePath,
            fileSize: UInt64(max(0, file.fileSize)),
            modifiedAtMillis: Int64(file.modifiedAt.timeIntervalSince1970 * 1_000),
            title: file.title
        )
    }

    var scannedMediaFile: ScannedMediaFile {
        ScannedMediaFile(
            relativePath: relativePath,
            fileIdentifier: identifier,
            fileSize: Int64(clamping: fileSize),
            modifiedAt: Date(timeIntervalSince1970: Double(modifiedAtMillis) / 1_000),
            title: title
        )
    }
}

private extension RustTrackAvailability {
    init(_ availability: MediaAvailability) {
        switch availability {
        case .available: self = .available
        case .sourceOffline: self = .sourceOffline
        case .missing: self = .missing
        case .permissionRequired: self = .permissionRequired
        }
    }
}

private extension RustSearchTrack {
    init(track: Track) {
        self.init(identifier: track.id.uuidString, title: track.title, artist: track.artist,
                  album: track.album, favorite: track.isFavorite,
                  rating: UInt8(clamping: max(0, track.rating)))
    }
}

enum LibraryDestination: String, CaseIterable, Identifiable {
    case nowPlaying, songs, albums, artists, playlists, favorites, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .nowPlaying: "現在收聽"
        case .songs: "歌曲"
        case .albums: "專輯"
        case .artists: "歌手"
        case .playlists: "歌單"
        case .favorites: "最愛"
        case .settings: "設定"
        }
    }
    var symbol: String {
        switch self {
        case .nowPlaying: "sparkles"
        case .songs: "music.note"
        case .albums: "square.stack"
        case .artists: "person.2"
        case .playlists: "music.note.list"
        case .favorites: "heart"
        case .settings: "gearshape"
        }
    }
}
