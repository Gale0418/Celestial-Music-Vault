import Foundation
import AVFoundation
import SwiftUI
import SwiftData
import Observation
import Combine
import CMVDomain
import CMVLibrary
import CMVPlayback
import CMVThemes
import CMVCache
#if os(macOS)
import AppKit
#endif

private func canonicalSearchValue(_ value: String) -> String {
    value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
}

private func epochMilliseconds(_ date: Date) -> Int64 {
    let value = date.timeIntervalSince1970 * 1_000
    guard value.isFinite else { return 0 }
    if value >= Double(Int64.max) { return Int64.max }
    if value <= Double(Int64.min) { return Int64.min }
    return Int64(value.rounded())
}

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
    func identifierSnapshot() -> Set<String> { seenIdentifiers }
}

private struct SourceStatusProbeResult: Sendable {
    let id: UUID
    let originalBookmark: Data
    let refreshedBookmark: Data?
    let status: MediaSourceStatus
}

private struct SourceStateSnapshot {
    let bookmarkData: Data
    let status: MediaSourceStatus
    let lastSuccessfulScan: Date?
    let updatedAt: Date
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
        return DeterministicCacheEvictionPlanner().plan(entries: entries, budgetBytes: max(0, budgetBytes))
    }
}

struct AudioEnergySnapshot: Sendable {
    var level: Float
    var previousLevel: Float
    var samples: [Float]
    var previousSamples: [Float]
    var writeIndex: Int
    var previousWriteIndex: Int
    var publishedAt: TimeInterval
    var interpolationDuration: TimeInterval

    static let silent = AudioEnergySnapshot(
        level: 0,
        previousLevel: 0,
        samples: Array(repeating: 0, count: 64),
        previousSamples: Array(repeating: 0, count: 64),
        writeIndex: 0,
        previousWriteIndex: 0,
        publishedAt: 0,
        interpolationDuration: 1.0 / 30.0
    )
}

@MainActor
@Observable
final class AudioEnergyState {
    // The ring samples once per display tick. Meter publication must not create
    // a second SwiftUI invalidation stream between those ticks.
    @ObservationIgnored private(set) var snapshot = AudioEnergySnapshot.silent
    @ObservationIgnored private var lastPublishTime: TimeInterval = 0
    @ObservationIgnored private var smoothedLevel: Float = 0
    private let minimumPublishInterval: TimeInterval = 1.0 / 60.0

    func receive(_ rawLevel: Float) {
        guard rawLevel.isFinite else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let clamped = min(1, max(0, rawLevel))
        guard now - lastPublishTime >= minimumPublishInterval else { return }
        // Follow the producer's cadence (video is typically 30 Hz), not the
        // display clock. Bound long gaps so resuming never blends for seconds.
        let publicationInterval = min(0.1, max(minimumPublishInterval, now - lastPublishTime))
        lastPublishTime = now
        let blend: Float = clamped > smoothedLevel ? 0.62 : 0.20
        smoothedLevel += (clamped - smoothedLevel) * blend
        var next = snapshot
        next.previousLevel = snapshot.level
        next.previousSamples = snapshot.samples
        next.previousWriteIndex = snapshot.writeIndex
        next.level = smoothedLevel
        next.samples[next.writeIndex] = smoothedLevel
        next.writeIndex = (next.writeIndex + 1) % next.samples.count
        next.publishedAt = Date.timeIntervalSinceReferenceDate
        next.interpolationDuration = publicationInterval
        snapshot = next
    }

    func pause() {
        smoothedLevel = 0
        var next = snapshot
        next.previousLevel = snapshot.level
        next.level = 0
        next.publishedAt = Date.timeIntervalSinceReferenceDate
        snapshot = next
    }
}

@MainActor
@Observable
final class AppModel {
    private static let themeDefaultsKey = "CMV.selectedTheme"
    private static let videoPresentationDefaultsKey = "CMV.videoPresentationMode"
    private static let duplicatePathRepairDefaultsKey = "CMV.duplicatePathRepairVersion"
    var selection: LibraryDestination? = .nowPlaying
    let proStore = ProStore()
    var showingProUpgrade = false
    private(set) var pendingPinTrackIDs: Set<UUID> = []
    var showingImporter = false
    var showingQueue = true
    var errorMessage: String?
    private(set) var libraryReadError: String?
    private(set) var catalogReadError: String?
    private(set) var favoriteReadError: String?
    private(set) var playlistReadError: String?
    var selectedTheme: CMVThemeID {
        didSet { UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.themeDefaultsKey) }
    }
    var videoPresentationMode: VideoPresentationMode {
        didSet { UserDefaults.standard.set(videoPresentationMode.rawValue, forKey: Self.videoPresentationDefaultsKey) }
    }
    private(set) var backgroundActivities: [UUID: BackgroundActivity] = [:]
    private(set) var queuedScanCount = 0
    private(set) var pinnedTrackIDs: Set<UUID> = []
    private(set) var ratingOverrides: [UUID: Int] = [:]
    private(set) var favoriteOverrides: [UUID: Bool] = [:]
    let playback: NativePlaybackEngine
    let videoSession: VideoPlaybackSession
    private(set) var videoURL: URL?
    private(set) var videoTrack: Track?
    private(set) var currentTrackID: UUID?
    private var currentArtworkData: Data?
    @ObservationIgnored private var artworkLoadTask: Task<Void, Never>?
    @ObservationIgnored let audioEnergy = AudioEnergyState()
    private(set) var audioIsPlaying = false
    private(set) var audioOutputVolume: Float = 1
    private(set) var playbackControlsRevision = 0
    private(set) var playbackRevision = 0
    /// Low-frequency bridge for queue consumers. Unlike playbackRevision this
    /// does not change for elapsed-time, volume, or meter updates.
    private(set) var queueRevision = 0
    private(set) var playlistRevision = 0
    private(set) var mixedMediaShuffleEnabled = false

    var currentTrack: Track? {
        _ = queueRevision
        var track = videoTrack ?? playback.queue.current
        if track?.id == currentTrackID, track?.artworkData == nil {
            track?.artworkData = currentArtworkData
        }
        return track
    }
    var displayQueue: PlaybackQueue {
        _ = playbackRevision
        guard let mixedQueue, !mixedQueue.isEmpty else { return playback.queue }
        let index = mixedRouteIndex(in: mixedQueue)
            ?? playback.queue.currentIndex
        return PlaybackQueue(tracks: mixedQueue, currentIndex: index)
    }

    /// Queue-only view of the route. The panel must not subscribe to the
    /// playback revision used by elapsed-time and transport controls.
    var queuePanelDisplayQueue: PlaybackQueue {
        _ = queueRevision
        guard let mixedQueue, !mixedQueue.isEmpty else { return playback.queue }
        let index = mixedRouteIndex(in: mixedQueue)
            ?? playback.queue.currentIndex
        return PlaybackQueue(tracks: mixedQueue, currentIndex: index)
    }
    var isCurrentMediaPlaying: Bool {
        videoURL != nil ? videoSession.isPlaying : audioIsPlaying
    }
    var currentOutputVolume: Float {
        videoURL != nil ? videoSession.outputVolume : audioOutputVolume
    }
    var currentMediaElapsed: TimeInterval {
        _ = playbackRevision
        return videoURL != nil ? videoSession.currentTime : playback.elapsed
    }
    var currentMediaDuration: TimeInterval {
        _ = queueRevision
        return videoURL != nil ? videoSession.duration : (playback.queue.current?.duration ?? 0)
    }
    var canAdjustQueueOrder: Bool {
        videoURL == nil && !(mixedQueue?.contains { $0.mediaKind == .video } ?? false)
    }
    var canShuffleQueue: Bool { queuePanelDisplayQueue.tracks.count > 1 }
    var isShuffleEnabled: Bool {
        _ = playbackControlsRevision
        guard let mixedQueue, routeContainsVideo(mixedQueue) else { return playback.isShuffleEnabled }
        return mixedMediaShuffleEnabled
    }
    var canSkipVideoBackward: Bool { videoURL != nil && playback.queue.currentIndex > 0 }
    var canSkipVideoForward: Bool {
        videoURL != nil && playback.queue.currentIndex + 1 < playback.queue.tracks.count
    }

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
    private var playbackAccessLeases: [SecurityScopedResourceLease] = []
    private var videoAccessLeases: [SecurityScopedResourceLease] = []
    private var mixedQueue: [Track]?
    private var mixedQueueCurrentIndex: Int?
    private var mixedQueueSegmentStart: Int?
    private var activePlaybackContext: ModelContext?
    @ObservationIgnored private var playbackPreparationGeneration = 0
    @ObservationIgnored private var smartPrefetchTask: Task<Void, Never>?
    @ObservationIgnored private var scanningSourceIDs = Set<UUID>()
    @ObservationIgnored private var pendingRescanSourceIDs = Set<UUID>()
    @ObservationIgnored private var reimportRestoreSourceIDs = Set<UUID>()
    @ObservationIgnored private var pendingSourceScans: [(source: MediaSourceRecord, context: ModelContext)] = []
    @ObservationIgnored private var activeScanSources: [UUID: MediaSourceRecord] = [:]
    @ObservationIgnored private var ratingMutationGeneration: [UUID: Int] = [:]
    @ObservationIgnored private var favoriteMutationGeneration: [UUID: Int] = [:]
    @ObservationIgnored private var ratingMutationTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var favoriteMutationTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var playbackObservation: AnyCancellable?
    @ObservationIgnored private var transportObservations = Set<AnyCancellable>()
    @ObservationIgnored private var libraryRepository: SwiftDataLibraryRepository?
    @ObservationIgnored private var sourceImportTask: Task<Void, Never>?

    private func repository(for context: ModelContext) -> SwiftDataLibraryRepository {
        if let libraryRepository { return libraryRepository }
        let repository = SwiftDataLibraryRepository(container: context.container)
        libraryRepository = repository
        return repository
    }

    init() {
        selectedTheme = UserDefaults.standard.string(forKey: Self.themeDefaultsKey)
            .flatMap(CMVThemeID.init(rawValue:)) ?? .crimsonNebula
        videoPresentationMode = UserDefaults.standard.string(forKey: Self.videoPresentationDefaultsKey)
            .flatMap(VideoPresentationMode.init(rawValue:)) ?? .moonPortal
        videoSession = VideoPlaybackSession()
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
            guard let self else { return }
            self.currentTrackID = track?.id
            self.currentArtworkData = track?.artworkData
            self.artworkLoadTask?.cancel()
            self.loadCurrentArtworkIfNeeded()
            if let track,
               let mixedQueue = self.mixedQueue,
               let segmentStart = self.mixedQueueSegmentStart,
               mixedQueue.indices.contains(segmentStart + self.playback.queue.currentIndex),
               mixedQueue[segmentStart + self.playback.queue.currentIndex].id == track.id {
                self.mixedQueueCurrentIndex = segmentStart + self.playback.queue.currentIndex
            }
            self.queueRevision &+= 1
        }
        playback.onQueueFinished = { [weak self] in self?.advanceAfterAudioQueue() }
        playback.onQueueChanged = { [weak self] in self?.markQueueChanged() }
        playback.onOutputLevelChanged = { [weak self] level in self?.receiveOutputLevel(level) }
        playback.onPlaybackError = { [weak self] error in
            self?.errorMessage = "播放管線發生錯誤：\(error.localizedDescription)"
        }
        playbackObservation = playback.objectWillChange.sink { [weak self] _ in self?.playbackRevision &+= 1 }
        playback.$isPlaying.removeDuplicates().sink { [weak self] playing in
            self?.audioIsPlaying = playing
        }.store(in: &transportObservations)
        playback.$outputVolume.removeDuplicates().sink { [weak self] volume in
            self?.audioOutputVolume = volume
        }.store(in: &transportObservations)
        Publishers.Merge3(
            playback.$isShuffleEnabled.removeDuplicates().map { _ in () },
            playback.$isRepeatEnabled.removeDuplicates().map { _ in () },
            playback.$sleepTimerEndDate.removeDuplicates().map { _ in () }
        ).sink { [weak self] in
            self?.playbackControlsRevision &+= 1
        }.store(in: &transportObservations)
        playback.onRemotePlayRequested = { [weak self] in
            guard let self else { return }
            if self.videoURL != nil {
                self.videoSession.player.play()
            } else {
                do { try self.playback.play() } catch { self.errorMessage = error.localizedDescription }
            }
        }
        playback.onRemotePauseRequested = { [weak self] in
            guard let self else { return }
            if self.videoURL != nil { self.videoSession.player.pause() } else { self.playback.pause() }
        }
        playback.onRemoteNextRequested = { [weak self] in
            guard let self, let context = self.activePlaybackContext else { return }
            self.skipCurrentMediaForward(context: context)
        }
        playback.onRemotePreviousRequested = { [weak self] in
            guard let self, let context = self.activePlaybackContext else { return }
            self.skipCurrentMediaBackward(context: context)
        }
        playback.onRemoteSeekRequested = { [weak self] seconds in self?.seekCurrentMedia(to: seconds) }
        playback.onSleepTimerElapsed = { [weak self] in
            guard let self else { return }
            if self.videoURL != nil { self.videoSession.player.pause() }
            self.playback.pause()
        }
        videoSession.onPlaybackEnded = { [weak self] in
            guard let self, let context = self.activePlaybackContext else {
                self?.stopVideoPlayback()
                return
            }
            self.advanceAfterVideo(context: context)
        }
        videoSession.onOutputLevelChanged = { [weak self] level in
            guard let self, self.videoURL != nil else { return }
            self.receiveOutputLevel(level)
        }
        videoSession.onStateChanged = { [weak self] in
            guard let self, self.videoURL != nil else { return }
            if !self.videoSession.isPlaying { self.audioEnergy.pause() }
            self.playback.updateExternalNowPlaying(
                isPlaying: self.videoSession.isPlaying,
                elapsed: self.videoSession.currentTime,
                duration: self.videoSession.duration
            )
            self.playbackRevision &+= 1
        }
    }

    private func receiveOutputLevel(_ level: Float) { audioEnergy.receive(level) }

    private func markQueueChanged() {
        queueRevision &+= 1
    }

    private func mixedRouteIndex(in route: [Track]) -> Int? {
        if let mixedQueueCurrentIndex,
           route.indices.contains(mixedQueueCurrentIndex),
           (currentTrackID == nil || route[mixedQueueCurrentIndex].id == currentTrackID) {
            return mixedQueueCurrentIndex
        }
        return PlaybackRoutePosition.resolve(
            routeIDs: route.map(\.id),
            currentID: currentTrackID,
            preferredIndex: nil
        )
    }

    @discardableResult
    func beginBackgroundActivity(kind: BackgroundActivityKind, title: String, detail: String? = nil) -> UUID {
        let id = UUID()
        backgroundActivities[id] = BackgroundActivity(id: id, kind: kind, title: title, detail: detail, startedAt: .now)
        return id
    }

    func updateBackgroundActivity(_ id: UUID, detail: String?) {
        guard var activity = backgroundActivities[id] else { return }
        activity.detail = detail
        backgroundActivities[id] = activity
    }
    func endBackgroundActivity(_ id: UUID) { backgroundActivities[id] = nil }
    func addSource(_ url: URL, context: ModelContext) { addSources([url], context: context) }

    func addSources(_ urls: [URL], context: ModelContext) {
        guard !urls.isEmpty else { return }
        // Serialize imports so two drops cannot prepare duplicate sources while
        // bookmark resolution is suspended. Waiting does not occupy MainActor.
        let previous = sourceImportTask
        sourceImportTask = Task { @MainActor [weak self] in
            await previous?.value
            await self?.importSources(urls, context: context)
        }
    }

    private func importSources(_ urls: [URL], context: ModelContext) async {
        let activityID = beginBackgroundActivity(kind: .scanning, title: "正在加入音樂來源", detail: "確認資料夾與授權")
        defer { endBackgroundActivity(activityID) }
        let existingSources: [MediaSourceRecord]
        do {
            existingSources = try context.fetch(FetchDescriptor<MediaSourceRecord>())
        } catch {
            errorMessage = "無法讀取既有來源：\(error.localizedDescription)"
            return
        }
        let provider = sourceProvider
        let existingBookmarks = existingSources.map {
            (id: $0.id, name: $0.displayName, bookmark: $0.bookmarkData, rootPath: $0.rootPath)
        }
        let prepared = await Task.detached(priority: .utility) {
            func canonicalPath(_ path: String) -> String {
                URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
            }
            var existingIDsByPath = [String: UUID]()
            var unresolvedNames = Set<String>()
            for existing in existingBookmarks {
                let storedPath = canonicalPath(existing.rootPath)
                if !existing.rootPath.isEmpty, existingIDsByPath[storedPath] == nil {
                    existingIDsByPath[storedPath] = existing.id
                }
                if let path = try? provider.resolveWithRefresh(bookmark: existing.bookmark).url.standardizedFileURL.path {
                    let resolvedPath = canonicalPath(path)
                    if existingIDsByPath[resolvedPath] == nil { existingIDsByPath[resolvedPath] = existing.id }
                } else {
                    unresolvedNames.insert(existing.name)
                }
            }
            var handledPaths = Set<String>()
            var entries: [(name: String, path: String, bookmark: Data)] = []
            var reimports: [(id: UUID, path: String, bookmark: Data)] = []
            var failures: [String] = []
            for url in urls {
                let normalizedURL = url.standardizedFileURL
                let ownsAccess = url.startAccessingSecurityScopedResource()
                defer { if ownsAccess { url.stopAccessingSecurityScopedResource() } }
                do {
                    // hasDirectoryPath is only a URL spelling hint. Finder may
                    // drop a real directory without a trailing slash.
                    guard try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
                        failures.append("\(normalizedURL.lastPathComponent)（請加入包含音樂的資料夾，而非單一檔案）")
                        continue
                    }
                    let identityPath = canonicalPath(normalizedURL.path)
                    guard handledPaths.insert(identityPath).inserted else { continue }
                    let bookmark = try provider.makeBookmark(for: url)
                    if let existingID = existingIDsByPath[identityPath] {
                        reimports.append((existingID, normalizedURL.path, bookmark))
                    } else if unresolvedNames.contains(normalizedURL.lastPathComponent) {
                        failures.append("\(normalizedURL.lastPathComponent)（既有同名來源無法驗證，請到設定重新授權，避免建立重複曲庫）")
                    } else {
                        entries.append((normalizedURL.lastPathComponent, normalizedURL.path, bookmark))
                    }
                } catch {
                    let cocoaError = error as NSError
                    failures.append("\(normalizedURL.lastPathComponent)（\(cocoaError.domain) \(cocoaError.code)：\(error.localizedDescription)）")
                }
            }
            return (entries: entries, reimports: reimports, failures: failures)
        }.value
        var pendingSources: [MediaSourceRecord] = []
        let failures = prepared.failures
        for reimport in prepared.reimports {
            await repository(for: context).invalidateScan(sourceID: reimport.id)
        }
        for entry in prepared.entries {
            let source = MediaSourceRecord(displayName: entry.name, bookmarkData: entry.bookmark, status: .scanning)
            source.rootPath = entry.path
            context.insert(source)
            pendingSources.append(source)
        }
        let sourcesByID = Dictionary(uniqueKeysWithValues: existingSources.map { ($0.id, $0) })
        var priorReimportStates: [UUID: (bookmark: Data, rootPath: String, status: MediaSourceStatus,
                                        updatedAt: Date, pendingRestore: Bool)] = [:]
        let reimportedSources = prepared.reimports.compactMap { preparedSource -> MediaSourceRecord? in
            guard let source = sourcesByID[preparedSource.id] else { return nil }
            priorReimportStates[source.id] = (
                source.bookmarkData, source.rootPath, source.status, source.updatedAt, source.pendingReimportRestore
            )
            source.bookmarkData = preparedSource.bookmark
            source.rootPath = preparedSource.path
            source.status = .scanning
            source.pendingReimportRestore = true
            source.updatedAt = .now
            return source
        }
        guard !pendingSources.isEmpty || !reimportedSources.isEmpty else {
            if !failures.isEmpty { errorMessage = "無法加入資料夾：" + failures.joined(separator: "、") }
            return
        }
        do {
            try context.save()
        } catch {
            for source in pendingSources { context.delete(source) }
            for source in reimportedSources {
                guard let old = priorReimportStates[source.id] else { continue }
                source.bookmarkData = old.bookmark
                source.rootPath = old.rootPath
                source.status = old.status
                source.updatedAt = old.updatedAt
                source.pendingReimportRestore = old.pendingRestore
            }
            errorMessage = error.localizedDescription
            return
        }
        for source in reimportedSources {
            scheduleScan(source, context: context)
        }
        for source in pendingSources { scheduleScan(source, context: context) }
        if !failures.isEmpty { errorMessage = "部分資料夾無法加入：" + failures.joined(separator: "、") }
    }

    func restoreAndScan(_ source: MediaSourceRecord, context: ModelContext) { scheduleScan(source, context: context) }

    func refreshSourceStatuses(_ sources: [MediaSourceRecord], context: ModelContext) async {
        // This is a local database repair and must not wait behind potentially
        // slow or offline NAS bookmark probes. An empty source list means the
        // SwiftData query has not populated yet, so the repository repairs all
        // sources directly from persisted track records.
        await repairRemountDuplicatesIfNeeded(sources: sources, context: context)
        guard !sources.isEmpty else { return }
        for source in sources where source.status == .scanning {
            guard !scanningSourceIDs.contains(source.id),
                  !pendingSourceScans.contains(where: { $0.source.id == source.id }) else { continue }
            scheduleScan(source, context: context)
        }
        let activityID = beginBackgroundActivity(kind: .scanning, title: "正在確認音樂來源")
        defer { endBackgroundActivity(activityID) }
        let probes = sources.filter { source in
            source.status != .scanning && !scanningSourceIDs.contains(source.id)
                && !pendingSourceScans.contains(where: { $0.source.id == source.id })
        }.map { (id: $0.id, bookmark: $0.bookmarkData) }
        let provider = sourceProvider
        let results = await Task.detached(priority: .utility) {
            probes.map { probe in
                do {
                    let resolution = try provider.resolveWithRefresh(bookmark: probe.bookmark)
                    guard resolution.url.startAccessingSecurityScopedResource() else {
                        return SourceStatusProbeResult(id: probe.id, originalBookmark: probe.bookmark, refreshedBookmark: nil, status: .permissionRequired)
                    }
                    defer { resolution.url.stopAccessingSecurityScopedResource() }
                    let status: MediaSourceStatus = FileManager.default.isReadableFile(atPath: resolution.url.path)
                        ? .available : .offline
                    return SourceStatusProbeResult(id: probe.id, originalBookmark: probe.bookmark, refreshedBookmark: resolution.refreshedBookmark, status: status)
                } catch {
                    let status: MediaSourceStatus
                    if let accessError = error as? MediaSourceAccessError,
                       accessError == .staleBookmark || accessError == .accessDenied {
                        status = .permissionRequired
                    } else {
                        status = .offline
                    }
                    return SourceStatusProbeResult(id: probe.id, originalBookmark: probe.bookmark, refreshedBookmark: nil, status: status)
                }
            }
        }.value
        let sourcesByID = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        var originals: [UUID: SourceStateSnapshot] = [:]
        var didChange = false
        for result in results {
            guard !Task.isCancelled,
                  let source = sourcesByID[result.id],
                  source.bookmarkData == result.originalBookmark,
                  source.status != .scanning,
                  !scanningSourceIDs.contains(source.id),
                  !pendingSourceScans.contains(where: { $0.source.id == source.id })
            else { continue }
            originals[source.id] = SourceStateSnapshot(
                bookmarkData: source.bookmarkData,
                status: source.status,
                lastSuccessfulScan: source.lastSuccessfulScan,
                updatedAt: source.updatedAt
            )
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
            do {
                try context.save()
            } catch {
                for (id, original) in originals {
                    guard let source = sourcesByID[id] else { continue }
                    source.bookmarkData = original.bookmarkData
                    source.status = original.status
                    source.lastSuccessfulScan = original.lastSuccessfulScan
                    source.updatedAt = original.updatedAt
                }
                errorMessage = "無法保存音樂來源狀態：\(error.localizedDescription)"
            }
        }
    }

    private func repairRemountDuplicatesIfNeeded(sources: [MediaSourceRecord], context: ModelContext) async {
        let repairVersion = 1
        guard UserDefaults.standard.integer(forKey: Self.duplicatePathRepairDefaultsKey) < repairVersion else { return }
        let activityID = beginBackgroundActivity(kind: .library, title: "正在整理曲庫", detail: "合併 NAS 重連造成的重複項目")
        defer { endBackgroundActivity(activityID) }
        do {
            let repaired = try await repository(for: context)
                .repairDuplicateTracksByRelativePath(sourceIDs: sources.map(\.id))
            if repaired > 0 {
                for source in sources { source.updatedAt = .now }
                try context.save()
                updateBackgroundActivity(activityID, detail: "已合併 \(repaired) 筆重複項目")
            }
            UserDefaults.standard.set(repairVersion, forKey: Self.duplicatePathRepairDefaultsKey)
        } catch {
            errorMessage = "無法整理重複曲目：\(error.localizedDescription)"
        }
    }

    func reauthorizeSource(_ source: MediaSourceRecord, with url: URL, context: ModelContext) async {
        let originalRootPath = source.rootPath
        let original = SourceStateSnapshot(
            bookmarkData: source.bookmarkData,
            status: source.status,
            lastSuccessfulScan: source.lastSuccessfulScan,
            updatedAt: source.updatedAt
        )
        do {
            let bookmark = try sourceProvider.makeBookmark(for: url)
            await repository(for: context).invalidateScan(sourceID: source.id)
            source.bookmarkData = bookmark
            source.rootPath = url.standardizedFileURL.path
            source.status = .scanning
            source.updatedAt = .now
            try context.save()
            scheduleScan(source, context: context)
        } catch {
            source.bookmarkData = original.bookmarkData
            source.rootPath = originalRootPath
            source.status = original.status
            source.lastSuccessfulScan = original.lastSuccessfulScan
            source.updatedAt = original.updatedAt
            errorMessage = error.localizedDescription
        }
    }

    func play(track: Track, context: ModelContext) { play(tracks: [track], startingAt: 0, context: context) }

    func stopVideoPlayback(invalidatePendingPreparation: Bool = true) {
        if invalidatePendingPreparation {
            playbackPreparationGeneration &+= 1
            smartPrefetchTask?.cancel()
            smartPrefetchTask = nil
        }
        let wasVideoPlayback = videoURL != nil || videoTrack != nil
        videoSession.stop()
        videoURL = nil
        videoTrack = nil
        videoAccessLeases.removeAll()
        if wasVideoPlayback {
            mixedQueue = nil
            mixedQueueCurrentIndex = nil
            mixedQueueSegmentStart = nil
            markQueueChanged()
            if !playback.queue.tracks.isEmpty { playback.clearQueue() }
            playbackAccessLeases.removeAll()
        }
    }

    func toggleCurrentMediaPlayback(context: ModelContext) {
        if videoURL != nil {
            videoSession.togglePlayback()
        } else if playback.isPlaying {
            playback.pause()
            smartPrefetchTask?.cancel()
            smartPrefetchTask = nil
        } else {
            playOrResume(context: context)
        }
    }

    func skipCurrentMediaForward(context: ModelContext) {
        smartPrefetchTask?.cancel()
        smartPrefetchTask = nil
        if videoURL != nil {
            guard canSkipVideoForward else { return }
            advanceAfterVideo(context: context)
            return
        }
        if playback.queue.currentIndex + 1 < playback.queue.tracks.count {
            do { try playback.skipForward() } catch { errorMessage = error.localizedDescription }
            return
        }
        guard let mixedQueue,
              let currentIndex = mixedRouteIndex(in: mixedQueue),
              mixedQueue.indices.contains(currentIndex + 1) else { return }
        play(tracks: mixedQueue, startingAt: currentIndex + 1, context: context)
    }

    private var shouldReturnToPreviousMixedMedia: Bool {
        playback.elapsed <= 3 && playback.queue.currentIndex == 0
    }

    private func playPreviousMixedMedia(context: ModelContext) -> Bool {
        guard shouldReturnToPreviousMixedMedia,
              let mixedQueue,
              let currentIndex = mixedRouteIndex(in: mixedQueue),
              mixedQueue.indices.contains(currentIndex - 1) else { return false }
        play(tracks: mixedQueue, startingAt: currentIndex - 1, context: context)
        return true
    }

    func skipCurrentMediaBackward(context: ModelContext) {
        smartPrefetchTask?.cancel()
        smartPrefetchTask = nil
        guard videoURL != nil else {
            if !playPreviousMixedMedia(context: context) {
                do { try playback.skipBackward() } catch { errorMessage = error.localizedDescription }
            }
            return
        }
        let queue = playback.queue
        let previousIndex = queue.currentIndex - 1
        guard queue.tracks.indices.contains(previousIndex) else { return }
        play(tracks: queue.tracks, startingAt: previousIndex, context: context)
    }

    func setCurrentMediaVolume(_ value: Float) {
        if videoURL != nil { videoSession.setVolume(value) } else { playback.setVolume(value) }
    }
    func seekCurrentMedia(to seconds: TimeInterval) {
        if videoURL != nil { videoSession.seek(to: seconds) } else { playback.seek(to: seconds) }
    }

    func toggleShuffle() {
        guard canShuffleQueue else { return }
        guard var route = mixedQueue,
              routeContainsVideo(route),
              let currentIndex = mixedRouteIndex(in: route) else {
            playback.toggleShuffle()
            return
        }
        mixedMediaShuffleEnabled.toggle()
        guard mixedMediaShuffleEnabled else {
            playbackRevision &+= 1
            return
        }
        let protectedEndIndex: Int
        if videoURL != nil {
            protectedEndIndex = currentIndex
        } else {
            let segmentStart = mixedQueueSegmentStart
                ?? max(0, currentIndex - playback.queue.currentIndex)
            protectedEndIndex = min(
                route.count - 1,
                segmentStart + playback.queue.tracks.count - 1
            )
        }
        let shuffleStart = protectedEndIndex + 1
        if shuffleStart < route.count {
            var upcoming = Array(route[shuffleStart...])
            upcoming.shuffle()
            route.replaceSubrange(shuffleStart..., with: upcoming)
            mixedQueue = route
            markQueueChanged()
            if videoURL != nil { playback.setQueue(PlaybackQueue(tracks: route, currentIndex: currentIndex)) }
        }
        playbackRevision &+= 1
    }

    private func routeContainsVideo(_ tracks: [Track]) -> Bool {
        let movieExtensions: Set<String> = ["mp4", "mov", "m4v"]
        return tracks.contains { track in
            track.mediaKind == .video || movieExtensions.contains(URL(fileURLWithPath: track.relativePath).pathExtension.lowercased())
        }
    }

    func playStandaloneVideo(url: URL) {
        smartPrefetchTask?.cancel()
        smartPrefetchTask = nil
        playbackPreparationGeneration &+= 1
        let requestGeneration = playbackPreparationGeneration
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let lease = try await sourceAccess.lease(for: url)
                guard requestGeneration == playbackPreparationGeneration else { return }
                playback.clearQueue()
                playbackAccessLeases.removeAll()
                videoAccessLeases = [lease]
                mixedQueue = nil
                mixedQueueCurrentIndex = nil
                mixedQueueSegmentStart = nil
                markQueueChanged()
                activePlaybackContext = nil
                let metadata = Track(
                    sourceID: UUID(), relativePath: url.lastPathComponent, fileIdentifier: url.path,
                    title: url.deletingPathExtension().lastPathComponent, fileSize: 0, modifiedAt: .now, mediaKind: .video
                )
                playback.setQueue(PlaybackQueue(tracks: [metadata]))
                videoTrack = metadata
                videoURL = url
                videoSession.load(url: url, autoplay: true)
            } catch {
                errorMessage = "無法開啟影片：\(error.localizedDescription)"
            }
        }
    }

    func playOrResume(context: ModelContext) {
        guard videoURL == nil else { return }
        if playback.queue.current == nil {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let repository = repository(for: context)
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
        do { try playback.play() } catch { errorMessage = error.localizedDescription }
    }

    func advanceAfterVideo(context: ModelContext) {
        guard videoURL != nil else { return }
        let queue = playback.queue
        let nextIndex = queue.currentIndex + 1
        guard queue.tracks.indices.contains(nextIndex) else { stopVideoPlayback(); return }
        play(tracks: queue.tracks, startingAt: nextIndex, context: context)
    }

    private func advanceAfterAudioQueue() {
        if mixedQueue == nil {
            guard let context = activePlaybackContext else { playbackAccessLeases.removeAll(); return }
            let audioQueue = playback.queue
            let nextIndex = audioQueue.currentIndex + 1
            guard audioQueue.tracks.indices.contains(nextIndex) else {
                playbackAccessLeases.removeAll()
                activePlaybackContext = nil
                return
            }
            play(tracks: audioQueue.tracks, startingAt: nextIndex, context: context)
            return
        }
        guard let mixedQueue, let context = activePlaybackContext,
              let currentIndex = mixedRouteIndex(in: mixedQueue) else {
            playbackAccessLeases.removeAll()
            return
        }
        let nextIndex = currentIndex + 1
        guard mixedQueue.indices.contains(nextIndex) else {
            self.mixedQueue = nil
            mixedQueueCurrentIndex = nil
            mixedQueueSegmentStart = nil
            mixedMediaShuffleEnabled = false
            markQueueChanged()
            playbackAccessLeases.removeAll()
            return
        }
        play(tracks: mixedQueue, startingAt: nextIndex, context: context)
    }

    func play(tracks: [Track], startingAt: Int = 0, context: ModelContext) {
        if mixedQueue?.map(\.id) != tracks.map(\.id) { mixedMediaShuffleEnabled = false }
        smartPrefetchTask?.cancel()
        smartPrefetchTask = nil
        playbackPreparationGeneration &+= 1
        let requestGeneration = playbackPreparationGeneration
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
                var cachedTrackIDs = Set<UUID>()
                guard tracks.indices.contains(startingAt) else { return }
                let selectedTrack = tracks[startingAt]
                let selectedURL: URL
                if let cacheStore, let cachedURL = await cacheStore.cachedURL(trackID: selectedTrack.id) {
                    selectedURL = cachedURL
                    cachedTrackIDs.insert(selectedTrack.id)
                } else {
                    guard let source = sourcesByID[selectedTrack.sourceID] else { throw MediaSourceAccessError.accessDenied }
                    let root = try await resolve(source: source, context: context)
                    roots[selectedTrack.sourceID] = root
                    leases.append(try await sourceAccess.lease(for: root))
                    selectedURL = try Self.safeTrackURL(root: root, relativePath: selectedTrack.relativePath)
                }
                guard requestGeneration == playbackPreparationGeneration else { return }
                resolvedURLs[selectedTrack.id] = selectedURL
                let selectedAsset = AVURLAsset(url: selectedURL)
                let selectedAssetTracks: [AVAssetTrack]
                do { selectedAssetTracks = try await selectedAsset.load(.tracks) }
                catch { throw MediaScanError.unreadableFile(path: selectedTrack.relativePath) }
                guard requestGeneration == playbackPreparationGeneration else { return }
                guard !selectedAssetTracks.isEmpty else { throw MediaScanError.unreadableFile(path: selectedTrack.relativePath) }
                let selectedAssetIsPlayable: Bool
                do { selectedAssetIsPlayable = try await selectedAsset.load(.isPlayable) }
                catch { throw MediaScanError.unreadableFile(path: selectedTrack.relativePath) }
                guard requestGeneration == playbackPreparationGeneration else { return }
                guard selectedAssetIsPlayable else { throw MediaScanError.unsupportedFile(path: selectedTrack.relativePath) }
                if selectedAssetTracks.contains(where: { $0.mediaType == .video }) {
                    disableAudioOnlyQueueModesForMixedMedia(tracks)
                    playback.clearQueue()
                    playback.setQueue(PlaybackQueue(tracks: tracks, currentIndex: startingAt))
                    mixedQueue = tracks
                    mixedQueueCurrentIndex = startingAt
                    mixedQueueSegmentStart = nil
                    markQueueChanged()
                    playbackAccessLeases.removeAll()
                    videoAccessLeases = leases
                    activePlaybackContext = context
                    videoTrack = selectedTrack
                    videoURL = selectedURL
                    videoSession.load(url: selectedURL, autoplay: true)
                    let repository = repository(for: context)
                    try? await repository.recordPlayback(trackID: selectedTrack.id, skipped: false)
                    return
                }

                stopVideoPlayback(invalidatePendingPreparation: false)
                let movieContainerExtensions: Set<String> = ["mp4", "mov", "m4v"]
                let nextVideoIndex = tracks.indices.dropFirst(startingAt + 1).first { index in
                    let track = tracks[index]
                    let ext = URL(fileURLWithPath: track.relativePath).pathExtension.lowercased()
                    return track.mediaKind == .video || movieContainerExtensions.contains(ext)
                } ?? tracks.count
                let audioTracks = Array(tracks[startingAt..<nextVideoIndex]).filter { track in
                    track.id == selectedTrack.id || track.mediaKind != .video
                }
                guard !audioTracks.isEmpty else { throw MediaScanError.unsupportedFile(path: selectedTrack.relativePath) }
                guard let audioIndex = audioTracks.firstIndex(of: selectedTrack) else {
                    throw MediaScanError.unsupportedFile(path: selectedTrack.relativePath)
                }
                let remainingAudioTracks = Array(audioTracks.dropFirst())
                let cachedURLs = await cacheStore?.cachedURLs(trackIDs: remainingAudioTracks.map(\.id)) ?? [:]
                guard requestGeneration == playbackPreparationGeneration else { return }
                for track in remainingAudioTracks {
                    if let cachedURL = cachedURLs[track.id] {
                        resolvedURLs[track.id] = cachedURL
                        cachedTrackIDs.insert(track.id)
                        continue
                    }
                    guard let source = sourcesByID[track.sourceID] else { throw MediaSourceAccessError.accessDenied }
                    let root: URL
                    if let cached = roots[track.sourceID] {
                        root = cached
                    } else {
                        root = try await resolve(source: source, context: context)
                        roots[track.sourceID] = root
                        leases.append(try await sourceAccess.lease(for: root))
                        guard requestGeneration == playbackPreparationGeneration else { return }
                    }
                    resolvedURLs[track.id] = try Self.safeTrackURL(root: root, relativePath: track.relativePath)
                }
                guard requestGeneration == playbackPreparationGeneration else { return }
                if nextVideoIndex < tracks.count { disableAudioOnlyQueueModesForMixedMedia(tracks) }
                if nextVideoIndex == tracks.count, mixedMediaShuffleEnabled {
                    if !playback.isShuffleEnabled { playback.toggleShuffle() }
                    mixedMediaShuffleEnabled = false
                }
                try await playback.load(PlaybackQueue(tracks: audioTracks, currentIndex: audioIndex), resolvedURLs: resolvedURLs)
                guard requestGeneration == playbackPreparationGeneration else { return }
                mixedQueue = nextVideoIndex < tracks.count ? tracks : nil
                if mixedQueue != nil {
                    mixedQueueSegmentStart = startingAt
                    mixedQueueCurrentIndex = startingAt + audioIndex
                } else {
                    mixedQueueSegmentStart = nil
                    mixedQueueCurrentIndex = nil
                }
                markQueueChanged()
                activePlaybackContext = context
                loadCurrentArtworkIfNeeded()
                playbackAccessLeases = leases
                try playback.play()
                let repository = repository(for: context)
                try? await repository.recordPlayback(trackID: selectedTrack.id, skipped: false)
                if proStore.hasPro, let cacheStore {
                    let policy = CachePolicy()
                    let prefetchTracks = Array(audioTracks.dropFirst().filter { !cachedTrackIDs.contains($0.id) }.prefix(policy.prefetchCount))
                    guard !prefetchTracks.isEmpty else { return }
                    let prefetchURLs = resolvedURLs
                    let cacheActivityID = beginBackgroundActivity(kind: .cache, title: "正在更新智慧快取", detail: "預取接下來的歌曲")
                    smartPrefetchTask = Task.detached(priority: .utility) { [weak self] in
                        defer {
                            Task { @MainActor [weak self] in
                                self?.endBackgroundActivity(cacheActivityID)
                                if self?.playbackPreparationGeneration == requestGeneration { self?.smartPrefetchTask = nil }
                            }
                        }
                        do { try await Task.sleep(for: .seconds(2)) } catch { return }
                        let shouldPrefetch = await MainActor.run { [weak self] in
                            guard let self else { return false }
                            return self.proStore.hasPro && self.playbackPreparationGeneration == requestGeneration && self.playback.isPlaying
                        }
                        guard shouldPrefetch else { return }
                        for track in prefetchTracks {
                            guard !Task.isCancelled else { return }
                            let shouldContinue = await MainActor.run { [weak self] in
                                guard let self else { return false }
                                return self.proStore.hasPro && self.playbackPreparationGeneration == requestGeneration && self.playback.isPlaying
                            }
                            guard shouldContinue else { return }
                            guard let url = prefetchURLs[track.id] else { continue }
                            _ = try? await cacheStore.prefetch(trackID: track.id, sourceURL: url)
                        }
                        try? await cacheStore.trim(to: policy.smartBudgetBytes)
                    }
                }
            } catch {
                guard requestGeneration == playbackPreparationGeneration else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func disableAudioOnlyQueueModesForMixedMedia(_ tracks: [Track]) {
        let movieExtensions: Set<String> = ["mp4", "mov", "m4v"]
        guard tracks.contains(where: { track in
            track.mediaKind == .video || movieExtensions.contains(URL(fileURLWithPath: track.relativePath).pathExtension.lowercased())
        }) else { return }
        if playback.isShuffleEnabled { playback.toggleShuffle() }
        if playback.isRepeatEnabled { playback.toggleRepeat() }
    }

    nonisolated private static func safeTrackURL(root: URL, relativePath: String) throws -> URL {
        let root = root.standardizedFileURL
        let candidate = root.appendingPathComponent(relativePath).standardizedFileURL
        guard candidate.path == root.path || candidate.path.hasPrefix(root.path + "/") else {
            throw MediaSourceAccessError.accessDenied
        }
        return candidate
    }

    private func resolve(source: MediaSourceRecord, context: ModelContext) async throws -> URL {
        let bookmark = source.bookmarkData
        let provider = sourceProvider
        let resolution = try await Task.detached(priority: .utility) {
            try provider.resolveWithRefresh(bookmark: bookmark)
        }.value
        try Task.checkCancellation()
        // A user can reauthorize the source while a slow network bookmark is
        // resolving. Never overwrite that newer authorization with this result.
        guard source.bookmarkData == bookmark else { throw CancellationError() }
        if let refreshedBookmark = resolution.refreshedBookmark {
            let oldBookmark = source.bookmarkData
            let oldUpdatedAt = source.updatedAt
            source.bookmarkData = refreshedBookmark
            source.updatedAt = .now
            do {
                try context.save()
            } catch {
                source.bookmarkData = oldBookmark
                source.updatedAt = oldUpdatedAt
                throw error
            }
        }
        return resolution.url
    }

    private func scheduleScan(_ source: MediaSourceRecord, context: ModelContext) {
        if scanningSourceIDs.contains(source.id) {
            pendingRescanSourceIDs.insert(source.id)
            return
        }
        guard !pendingSourceScans.contains(where: { $0.source.id == source.id }) else { return }
        pendingSourceScans.append((source, context))
        startNextScan()
    }

    private func startNextScan() {
        // Metadata reads on a mounted NAS can each issue several requests.
        // One active scan keeps the shared scanner and storage responsive.
        guard scanningSourceIDs.isEmpty, !pendingSourceScans.isEmpty else {
            queuedScanCount = pendingSourceScans.count
            return
        }
        let next = pendingSourceScans.removeFirst()
        scanningSourceIDs.insert(next.source.id)
        activeScanSources[next.source.id] = next.source
        queuedScanCount = pendingSourceScans.count
        Task { await scan(source: next.source, context: next.context) }
    }

    private func scanBookmarkIsCurrent(sourceID: UUID, bookmark: Data) -> Bool {
        activeScanSources[sourceID]?.bookmarkData == bookmark
    }

    private func scan(source: MediaSourceRecord, context: ModelContext) async {
        // A reimport is a one-scan intent. A failed or partial pass must not
        // authorize a later ordinary rescan to restore excluded records.
        let restoreOnSuccessfulScan = source.pendingReimportRestore || reimportRestoreSourceIDs.remove(source.id) != nil
        defer {
            scanningSourceIDs.remove(source.id)
            activeScanSources.removeValue(forKey: source.id)
            if pendingRescanSourceIDs.remove(source.id) != nil {
                pendingSourceScans.append((source, context))
            }
            startNextScan()
        }
        let activityID = beginBackgroundActivity(kind: .scanning, title: "正在索引「\(source.displayName)」", detail: "準備讀取來源")
        defer { endBackgroundActivity(activityID) }
        let original = SourceStateSnapshot(
            bookmarkData: source.bookmarkData,
            status: source.status,
            lastSuccessfulScan: source.lastSuccessfulScan,
            updatedAt: source.updatedAt
        )
        var scanBookmark = original.bookmarkData
        do {
            let url = try await resolve(source: source, context: context)
            scanBookmark = source.bookmarkData
            let accessLease = try await sourceAccess.lease(for: url)
            guard source.bookmarkData == scanBookmark else { throw CancellationError() }
            let sourceID = source.id
            source.status = .scanning
            let repository = repository(for: context)
            updateBackgroundActivity(activityID, detail: "正在整理既有曲目")
            var existing = try await repository.scanSnapshots(sourceID: sourceID)
            if Set(existing.map(\.relativePath)).count != existing.count {
                _ = try await repository.repairDuplicateTracksByRelativePath(sourceIDs: [sourceID])
                existing = try await repository.scanSnapshots(sourceID: sourceID)
            }
            updateBackgroundActivity(activityID, detail: "已整理 \(existing.count) 首，正在檢查檔案")
            // Keep the O(n) snapshot conversion off MainActor for large libraries.
            let existingByIdentifierSnapshot = try await Task.detached(priority: .utility) {
                var snapshots = [String: RustTrackSnapshot]()
                var identifiersByRelativePath = [String: String]()
                snapshots.reserveCapacity(existing.count)
                for track in existing {
                    guard snapshots[track.fileIdentifier] == nil else {
                        throw LibraryRepositoryError.invalidReconciliation
                    }
                    snapshots[track.fileIdentifier] = RustTrackSnapshot(scan: track)
                    guard identifiersByRelativePath[track.relativePath] == nil else {
                        throw LibraryRepositoryError.invalidReconciliation
                    }
                    identifiersByRelativePath[track.relativePath] = track.fileIdentifier
                }
                return (byIdentifier: snapshots, identifierByRelativePath: identifiersByRelativePath)
            }.value
            let scanID = await repository.beginScan(sourceID: sourceID)
            let batchState = ScanBatchState()
            let rustCore = rustCore
            let activeBookmark = scanBookmark
            try await scanner.scan(
                url: url,
                batchSize: 400,
                accessAlreadyGranted: true,
                onBatch: { batch in
                    let normalizedBatch = batch.map { scanned -> ScannedMediaFile in
                        guard existingByIdentifierSnapshot.byIdentifier[scanned.fileIdentifier] == nil,
                              let stableIdentifier = existingByIdentifierSnapshot.identifierByRelativePath[scanned.relativePath]
                        else { return scanned }
                        var normalized = scanned
                        normalized.fileIdentifier = stableIdentifier
                        return normalized
                    }
                    for scanned in normalizedBatch {
                        if let previous = existingByIdentifierSnapshot.byIdentifier[scanned.fileIdentifier],
                           previous.relativePath != scanned.relativePath {
                            // A genuine move keeps its filesystem identity;
                            // only a still-present old path means two files
                            // are claiming the same identity.
                            let oldURL = try Self.safeTrackURL(root: url, relativePath: previous.relativePath)
                            if FileManager.default.fileExists(atPath: oldURL.path) {
                                throw LibraryRepositoryError.invalidReconciliation
                            }
                        }
                    }
                    try await batchState.accept(normalizedBatch.map(\.fileIdentifier))
                    let scannedBatch = normalizedBatch.map(RustScannedFile.init(file:))
                    let existingBatch = normalizedBatch.compactMap {
                        existingByIdentifierSnapshot.byIdentifier[$0.fileIdentifier]
                    }
                    let reconciliation = try await Task.detached(priority: .utility) {
                        try rustCore.reconcile(existing: existingBatch, scanned: scannedBatch, sourceReachable: true)
                    }.value
                    var byIdentifier = [String: ScannedMediaFile]()
                    for file in normalizedBatch where byIdentifier[file.fileIdentifier] == nil {
                        byIdentifier[file.fileIdentifier] = file
                    }
                    let upserts = reconciliation.upserts.compactMap { byIdentifier[$0.file.identifier] }
                    guard await self.scanBookmarkIsCurrent(sourceID: sourceID, bookmark: activeBookmark) else {
                        throw CancellationError()
                    }
                    try await repository.applyScanBatch(upserts, sourceID: sourceID, scanID: scanID)
                },
                onProgress: { [weak self] progress in
                    await MainActor.run {
                        let path = progress.currentPath.isEmpty ? nil : progress.currentPath
                        self?.updateBackgroundActivity(
                            activityID,
                            detail: path.map {
                                let elapsed = progress.currentFileElapsedSeconds.map { " · 已讀取 \($0) 秒" } ?? ""
                                return "已檢查 \(progress.processed) 首 · 正在讀取 \($0)\(elapsed)"
                            } ?? "已檢查 \(progress.processed) 首"
                        )
                    }
                },
                onIssue: { [weak self] issue in
                    let shouldPresent = await batchState.registerIssue()
                    guard shouldPresent else { return }
                    await MainActor.run { self?.errorMessage = issue.localizedDescription }
                }
            )
            _ = accessLease
            guard source.bookmarkData == scanBookmark else { throw CancellationError() }
            let scanCompletedWithoutIssues = await batchState.completedWithoutIssues()
            if scanCompletedWithoutIssues {
                let seenIdentifiers = await batchState.identifierSnapshot()
                if restoreOnSuccessfulScan,
                   !pendingRescanSourceIDs.contains(sourceID) {
                    guard source.bookmarkData == scanBookmark else { throw CancellationError() }
                    _ = try await repository.restoreTracks(sourceID: sourceID, seenIdentifiers: seenIdentifiers, scanID: scanID)
                }
                let missingIdentifiers = await Task.detached(priority: .utility) {
                    ScanCompletionPlanner.missingIdentifiers(
                        existing: existing,
                        seenIdentifiers: seenIdentifiers,
                        completedWithoutIssues: true
                    )
                }.value
                guard source.bookmarkData == scanBookmark else { throw CancellationError() }
                try await repository.applyReconciliation(
                    upserts: [],
                    missingIdentifiers: missingIdentifiers,
                    sourceID: sourceID,
                    scanID: scanID
                )
            }
            source.status = .available
            // A newer queued pass owns the reimport intent when this pass was
            // superseded before restoration. Do not consume it prematurely.
            if restoreOnSuccessfulScan, !pendingRescanSourceIDs.contains(source.id) {
                source.pendingReimportRestore = false
            }
            if scanCompletedWithoutIssues { source.lastSuccessfulScan = .now }
            source.updatedAt = .now
            do {
                try context.save()
            } catch {
                source.status = original.status
                source.lastSuccessfulScan = original.lastSuccessfulScan
                source.updatedAt = original.updatedAt
                errorMessage = "索引已完成，但無法保存來源狀態：\(error.localizedDescription)"
            }
        } catch is CancellationError {
            // Cancellation (including a newer authorization winning the race)
            // is not evidence that the source went offline.
            if source.bookmarkData == scanBookmark, source.status == .scanning {
                source.status = original.status == .scanning ? .available : original.status
                if restoreOnSuccessfulScan, !pendingRescanSourceIDs.contains(source.id) {
                    source.pendingReimportRestore = false
                }
                do { try context.save() }
                catch { errorMessage = "無法保存取消索引狀態：\(error.localizedDescription)" }
            }
        } catch {
            guard source.bookmarkData == scanBookmark else { return }
            let scanError = error
            if restoreOnSuccessfulScan, !pendingRescanSourceIDs.contains(source.id) {
                source.pendingReimportRestore = false
            }
            if let accessError = scanError as? MediaSourceAccessError,
               accessError == .staleBookmark || accessError == .accessDenied {
                source.status = .permissionRequired
            } else if scanError as? LibraryRepositoryError == .invalidReconciliation {
                source.status = .available
            } else {
                source.status = .offline
            }
            source.updatedAt = .now
            do {
                try context.save()
                errorMessage = (scanError as? LibraryRepositoryError) == .invalidReconciliation
                    ? "索引發現重複的檔案識別或路徑，已停止更新以保護歌單與評分；請檢查來源後重新索引。"
                    : scanError.localizedDescription
            } catch {
                let saveError = error
                source.bookmarkData = original.bookmarkData
                source.status = original.status
                source.lastSuccessfulScan = original.lastSuccessfulScan
                source.updatedAt = original.updatedAt
                errorMessage = "來源錯誤：\(scanError.localizedDescription)；且無法保存狀態：\(saveError.localizedDescription)"
            }
        }
    }

    func searchTracks(
        query: String,
        context: ModelContext,
        sort: LibraryTrackSort? = nil,
        ascending: Bool = true,
        limit: Int = 200,
        offset: Int = 0,
        includeArtwork: Bool = true
    ) async -> [Track] {
        libraryReadError = nil
        let repository = repository(for: context)
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeLimit = max(1, limit)
        let safeOffset = max(0, offset)
        if let sort {
            do {
                return try await repository.tracks(matching: normalizedQuery, sort: sort, ascending: ascending, limit: safeLimit, offset: safeOffset, includeArtwork: includeArtwork)
            } catch {
                let message = "無法讀取曲庫：\(error.localizedDescription)"
                errorMessage = message
                libraryReadError = message
                return []
            }
        }
        if normalizedQuery.isEmpty {
            do { return try await repository.tracks(matching: "", limit: safeLimit, offset: safeOffset, includeArtwork: includeArtwork) }
            catch {
                let message = "無法讀取曲庫：\(error.localizedDescription)"
                errorMessage = message
                libraryReadError = message
                return []
            }
        }
        let candidates: [LibrarySearchCandidate]
        do { candidates = try await repository.searchCandidates(matching: normalizedQuery) }
        catch {
            let message = "無法搜尋曲庫：\(error.localizedDescription)"
            errorMessage = message
            libraryReadError = message
            return []
        }
        let core = rustCore
        let rustTracks = candidates.map(RustSearchTrack.init(candidate:))
        let canonicalQuery = canonicalSearchValue(normalizedQuery)
        let ranked: [RustSearchResult]
        do {
            ranked = try await Task.detached(priority: .userInitiated) {
                try core.search(query: canonicalQuery, tracks: rustTracks, limit: safeLimit + safeOffset)
            }.value
        } catch {
            let tokens = canonicalQuery.split(whereSeparator: \.isWhitespace).map(String.init)
            let sorted = candidates.sorted { lhs, rhs in
                let lhsScore = Self.fallbackSearchScore(lhs, tokens: tokens)
                let rhsScore = Self.fallbackSearchScore(rhs, tokens: tokens)
                if lhsScore != rhsScore { return lhsScore > rhsScore }
                let titleOrder = lhs.title.localizedStandardCompare(rhs.title)
                if titleOrder != .orderedSame { return titleOrder == .orderedAscending }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            let pageIDs = sorted.dropFirst(safeOffset).prefix(safeLimit).map(\.id)
            do { return try await repository.tracks(ids: pageIDs, includeArtwork: includeArtwork) }
            catch {
                let message = "無法載入搜尋結果：\(error.localizedDescription)"
                errorMessage = message
                libraryReadError = message
                return []
            }
        }
        let pageIDs = ranked.dropFirst(safeOffset).prefix(safeLimit).compactMap { UUID(uuidString: $0.identifier) }
        do { return try await repository.tracks(ids: pageIDs, includeArtwork: includeArtwork) }
        catch {
            let message = "無法載入搜尋結果：\(error.localizedDescription)"
            errorMessage = message
            libraryReadError = message
            return []
        }
    }

    func catalogGroups(kind: LibraryCatalogKind, context: ModelContext) async -> [LibraryCatalogGroup] {
        catalogReadError = nil
        let repository = repository(for: context)
        do {
            return try await repository.catalogGroups(kind: kind)
        } catch is CancellationError {
            return []
        } catch {
            let message = "無法整理曲庫目錄：\(error.localizedDescription)"
            errorMessage = message
            catalogReadError = message
            return []
        }
    }

    func trackIDs(matching query: String, context: ModelContext, sort: LibraryTrackSort = .title, ascending: Bool = true) async -> [UUID] {
        let repository = repository(for: context)
        do { return try await repository.trackIDs(matching: query, sort: sort, ascending: ascending) }
        catch { errorMessage = error.localizedDescription; return [] }
    }

    func tracks(ids: [UUID], context: ModelContext, includeArtwork: Bool = true) async -> [Track] {
        let repository = repository(for: context)
        do { return try await repository.tracks(ids: ids, includeArtwork: includeArtwork) }
        catch { errorMessage = error.localizedDescription; return [] }
    }

    func catalogGroupTrackIDs(kind: LibraryCatalogKind, key: String, context: ModelContext) async -> [UUID] {
        do { return try await repository(for: context).catalogGroupTrackIDs(kind: kind, key: key) }
        catch { errorMessage = "無法載入群組曲目：\(error.localizedDescription)"; return [] }
    }

    func excludeTracks(ids: Set<UUID>, context: ModelContext) async -> Bool {
        guard !ids.isEmpty else { return true }
        let activityID = beginBackgroundActivity(kind: .library, title: "正在從 CMV 移出曲目", detail: "保留原始檔案 · \(ids.count) 首")
        defer { endBackgroundActivity(activityID) }
        do {
            let repository = repository(for: context)
            try await repository.excludeTracks(ids: Array(ids))
            if let cacheStore {
                var failedToUnpin = 0
                for id in ids {
                    do {
                        try await cacheStore.unpin(trackID: id)
                        pinnedTrackIDs.remove(id)
                    } catch { failedToUnpin += 1 }
                }
                if failedToUnpin > 0 {
                    errorMessage = "曲目已移出 CMV，但有 \(failedToUnpin) 份離線副本清理失敗。請稍後重試。"
                }
            } else {
                pinnedTrackIDs.subtract(ids)
            }
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func favoriteTracks(context: ModelContext, limit: Int = 200, offset: Int = 0) async -> [Track] {
        favoriteReadError = nil
        let repository = repository(for: context)
        do { return try await repository.favoriteTracks(limit: limit, offset: max(0, offset)) }
        catch {
            let message = "無法讀取最愛歌曲：\(error.localizedDescription)"
            errorMessage = message
            favoriteReadError = message
            return []
        }
    }

    func play(playlist: Playlist, context: ModelContext) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let playable = try await playablePlaylistEntries(playlist, context: context)
                guard !playable.isEmpty else {
                    errorMessage = "「\(playlist.name)」沒有目前可播放的曲目。請檢查來源或重新加入音樂。"
                    return
                }
                play(tracks: playable.map(\.track), context: context)
                if playable.count < playlist.trackIDs.count {
                    errorMessage = "已略過歌單中 \(playlist.trackIDs.count - playable.count) 首目前無法播放的曲目。"
                }
            }
            catch { errorMessage = "無法播放「\(playlist.name)」：\(error.localizedDescription)" }
        }
    }

    private func loadCurrentArtworkIfNeeded() {
        guard let track = playback.queue.current,
              track.artworkData == nil,
              currentArtworkData == nil,
              let context = activePlaybackContext else { return }
        let trackID = track.id
        artworkLoadTask?.cancel()
        artworkLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let fullTrack = try? await repository(for: context).tracks(ids: [trackID]).first
            guard !Task.isCancelled, currentTrackID == trackID else { return }
            currentArtworkData = fullTrack?.artworkData
            queueRevision &+= 1
        }
    }

    func addToPlaybackQueue(_ tracks: [Track], context: ModelContext) {
        guard !tracks.isEmpty else { return }
        let currentDisplayQueue = displayQueue
        guard currentTrackID != nil, !currentDisplayQueue.tracks.isEmpty else {
            play(tracks: tracks, context: context)
            return
        }
        let currentDisplayIndex = currentDisplayQueue.currentIndex
        var updated = currentDisplayQueue.tracks
        var queuedIDs = Set(updated.map(\.id))
        let additions = tracks.filter { queuedIDs.insert($0.id).inserted }
        guard !additions.isEmpty else { return }
        updated.append(contentsOf: additions)
        mixedQueue = updated
        if mixedQueueCurrentIndex == nil,
           updated.indices.contains(currentDisplayIndex) {
            mixedQueueCurrentIndex = currentDisplayIndex
            mixedQueueSegmentStart = videoURL == nil ? 0 : nil
        }
        markQueueChanged()
        activePlaybackContext = context
        if videoURL != nil {
            let currentIndex = mixedRouteIndex(in: updated) ?? 0
            playback.setQueue(PlaybackQueue(tracks: updated, currentIndex: currentIndex))
        } else if updated.allSatisfy({ $0.mediaKind == .audio }) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let pendingTracks = Array(updated.dropFirst(playback.queue.tracks.count))
                    guard !pendingTracks.isEmpty else { return }
                    let sourceRecords = try context.fetch(FetchDescriptor<MediaSourceRecord>())
                    let sourcesByID = Dictionary(uniqueKeysWithValues: sourceRecords.map { ($0.id, $0) })
                    let cached = await cacheStore?.cachedURLs(trackIDs: pendingTracks.map(\.id)) ?? [:]
                    var urls = cached
                    var roots: [UUID: URL] = [:]
                    var leases: [SecurityScopedResourceLease] = []
                    for track in pendingTracks where urls[track.id] == nil {
                        guard let source = sourcesByID[track.sourceID] else { throw MediaSourceAccessError.accessDenied }
                        let root: URL
                        if let cachedRoot = roots[track.sourceID] { root = cachedRoot }
                        else {
                            root = try await resolve(source: source, context: context)
                            roots[track.sourceID] = root
                            leases.append(try await sourceAccess.lease(for: root))
                        }
                        urls[track.id] = try Self.safeTrackURL(root: root, relativePath: track.relativePath)
                    }
                    guard activePlaybackContext === context,
                          updated.map(\.id) == displayQueue.tracks.map(\.id) else { return }
                    let remaining = Array(updated.dropFirst(playback.queue.tracks.count))
                    guard !remaining.isEmpty else { return }
                    playbackAccessLeases.append(contentsOf: leases)
                    playback.appendToQueue(remaining, resolvedURLs: urls)
                    mixedQueue = nil
                    mixedQueueCurrentIndex = nil
                    mixedQueueSegmentStart = nil
                    markQueueChanged()
                } catch {
                    if updated.map(\.id) == displayQueue.tracks.map(\.id) {
                        mixedQueue = nil
                        mixedQueueCurrentIndex = nil
                        mixedQueueSegmentStart = nil
                        markQueueChanged()
                    }
                    errorMessage = "無法加入接下來播放：\(error.localizedDescription)"
                }
            }
        }
    }

    func addPlaylistToPlaybackQueue(_ playlist: Playlist, context: ModelContext) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let activityID = beginBackgroundActivity(kind: .playback, title: "正在加入接下來播放", detail: playlist.name)
            defer { endBackgroundActivity(activityID) }
            do {
                let tracks = try await playablePlaylistEntries(playlist, context: context).map(\.track)
                guard !tracks.isEmpty else {
                    errorMessage = "「\(playlist.name)」沒有目前可播放的曲目。請檢查來源或重新加入音樂。"
                    return
                }
                addToPlaybackQueue(tracks, context: context)
                if tracks.count < playlist.trackIDs.count {
                    errorMessage = "已略過歌單中 \(playlist.trackIDs.count - tracks.count) 首目前無法播放的曲目。"
                }
            } catch { errorMessage = "無法將「\(playlist.name)」加入佇列：\(error.localizedDescription)" }
        }
    }

    private func playablePlaylistEntries(_ playlist: Playlist, context: ModelContext) async throws -> [PlaylistTrackEntry] {
        let entries = try await repository(for: context).playlistEntries(ids: playlist.trackIDs, includeArtwork: false)
        let sourceRecords = try context.fetch(FetchDescriptor<MediaSourceRecord>())
        let unavailableSources = Set(sourceRecords.filter {
            $0.status == .offline || $0.status == .permissionRequired
        }.map(\.id))
        await refreshPinnedStatus(for: entries.map(\.track).filter {
            $0.availability != .available || unavailableSources.contains($0.sourceID)
        })
        return entries.filter { entry in
            guard !entry.isExcluded else { return false }
            let sourceUnavailable = unavailableSources.contains(entry.track.sourceID)
            let trackUnavailable = entry.track.availability != .available
            return (!sourceUnavailable && !trackUnavailable) || pinnedTrackIDs.contains(entry.id)
        }
    }

    func clearPlaybackQueue() {
        // Invalidate preparation before clearing: a pending bookmark/file open
        // must not resurrect the queue after the user has emptied it.
        playbackPreparationGeneration &+= 1
        smartPrefetchTask?.cancel()
        smartPrefetchTask = nil
        mixedQueue = nil
        mixedQueueCurrentIndex = nil
        mixedQueueSegmentStart = nil
        markQueueChanged()
        mixedMediaShuffleEnabled = false
        activePlaybackContext = nil
        if videoURL != nil { stopVideoPlayback() }
        else { playback.clearQueue(); playbackAccessLeases.removeAll() }
    }

    func setFavorite(_ track: Track, context: ModelContext) {
        let previous = isFavorite(for: track)
        let desired = !previous
        favoriteOverrides[track.id] = desired
        let generation = (favoriteMutationGeneration[track.id] ?? 0) &+ 1
        favoriteMutationGeneration[track.id] = generation
        let prior = favoriteMutationTasks[track.id]
        favoriteMutationTasks[track.id] = Task { @MainActor [weak self] in
            await prior?.value
            guard let self else { return }
            do { try await repository(for: context).setFavorite(trackID: track.id, isFavorite: desired) }
            catch {
                if favoriteMutationGeneration[track.id] == generation {
                    favoriteOverrides[track.id] = previous
                    errorMessage = "無法更新最愛：\(error.localizedDescription)"
                }
            }
            if favoriteMutationGeneration[track.id] == generation { favoriteMutationTasks[track.id] = nil }
        }
    }

    func setRating(_ track: Track, rating: Int, context: ModelContext) {
        let previous = self.rating(for: track)
        let desired = min(5, max(0, rating))
        ratingOverrides[track.id] = desired
        let generation = (ratingMutationGeneration[track.id] ?? 0) &+ 1
        ratingMutationGeneration[track.id] = generation
        let prior = ratingMutationTasks[track.id]
        ratingMutationTasks[track.id] = Task { @MainActor [weak self] in
            await prior?.value
            guard let self else { return }
            do { try await repository(for: context).setRating(trackID: track.id, rating: desired) }
            catch {
                if ratingMutationGeneration[track.id] == generation {
                    ratingOverrides[track.id] = previous
                    errorMessage = "無法更新評分：\(error.localizedDescription)"
                }
            }
            if ratingMutationGeneration[track.id] == generation { ratingMutationTasks[track.id] = nil }
        }
    }

    func rating(for track: Track) -> Int { ratingOverrides[track.id] ?? track.rating }
    func isFavorite(for track: Track) -> Bool { favoriteOverrides[track.id] ?? track.isFavorite }

    func refreshPinnedStatus(for tracks: [Track]) async {
        guard let cacheStore else { return }
        let ids = tracks.map(\.id)
        let pinned = await cacheStore.pinnedTrackIDs(in: ids)
        pinnedTrackIDs.subtract(ids)
        pinnedTrackIDs.formUnion(pinned)
    }

    func selectTheme(_ theme: CMVThemeID) {
        guard theme == selectedTheme || theme == .crimsonNebula || requirePro(.additionalThemes) else { return }
        selectedTheme = theme
    }

    @discardableResult
    func requirePro(_ feature: ProFeature) -> Bool {
        guard ProAccessPolicy.allows(feature, hasPro: proStore.hasPro) else {
            showingProUpgrade = true
            return false
        }
        return true
    }

    func togglePinned(_ track: Track, context: ModelContext) {
        guard !pendingPinTrackIDs.contains(track.id) else { return }
        // Removing offline content stays available even after a refund.
        guard pinnedTrackIDs.contains(track.id) || requirePro(.smartOfflineCache) else { return }
        guard let cacheStore else { errorMessage = "無法建立離線快取。"; return }
        pendingPinTrackIDs.insert(track.id)
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { pendingPinTrackIDs.remove(track.id) }
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
                let descriptor = FetchDescriptor<MediaSourceRecord>(predicate: #Predicate { source in source.id == track.sourceID })
                guard let source = try context.fetch(descriptor).first else { throw MediaSourceAccessError.accessDenied }
                let root = try await resolve(source: source, context: context)
                let lease = try await sourceAccess.lease(for: root)
                let url = try Self.safeTrackURL(root: root, relativePath: track.relativePath)
                guard requirePro(.smartOfflineCache) else { return }
                _ = try await cacheStore.pin(trackID: track.id, sourceURL: url)
                _ = lease
                pinnedTrackIDs.insert(track.id)
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func playlists(context: ModelContext) async -> [Playlist] {
        playlistReadError = nil
        let repository = repository(for: context)
        do { return try await repository.playlists() }
        catch {
            let message = "無法讀取歌單：\(error.localizedDescription)"
            errorMessage = message
            playlistReadError = message
            return []
        }
    }

    func playlistEntries(_ playlist: Playlist, context: ModelContext) async -> [PlaylistTrackEntry]? {
        do { return try await repository(for: context).playlistEntries(ids: playlist.trackIDs, includeArtwork: false) }
        catch { errorMessage = "無法讀取「\(playlist.name)」：\(error.localizedDescription)"; return nil }
    }

    func removeTrack(_ trackID: UUID, from playlist: Playlist, context: ModelContext) async -> Bool {
        do {
            try await repository(for: context).removeTrack(trackID: trackID, fromPlaylist: playlist.id)
            playlistRevision &+= 1
            return true
        } catch {
            errorMessage = "無法從「\(playlist.name)」移除曲目：\(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func cleanUnavailableTracks(from playlist: Playlist, context: ModelContext) async -> Int? {
        do {
            let repository = repository(for: context)
            let missingIDs = try await repository.missingPlaylistTrackIDs(ids: playlist.trackIDs)
            let verifiedPinned = await cacheStore?.pinnedTrackIDs(in: Array(missingIDs)) ?? []
            pinnedTrackIDs.subtract(missingIDs)
            pinnedTrackIDs.formUnion(verifiedPinned)
            let removed = try await repository.removeUnavailableTracks(
                fromPlaylist: playlist.id, playableMissingIDs: verifiedPinned
            )
            if removed > 0 { playlistRevision &+= 1 }
            return removed
        } catch {
            errorMessage = "無法清理「\(playlist.name)」：\(error.localizedDescription)"
            return nil
        }
    }

    func createPlaylist(context: ModelContext) async -> Playlist? {
        let repository = repository(for: context)
        do {
            let playlist = try await repository.createPlaylist(name: "新歌單")
            playlistRevision &+= 1
            return playlist
        } catch { errorMessage = "無法建立歌單：\(error.localizedDescription)"; return nil }
    }

    func renamePlaylist(_ playlist: Playlist, name: String, context: ModelContext) async {
        do { try await repository(for: context).renamePlaylist(id: playlist.id, name: name); playlistRevision &+= 1 }
        catch { errorMessage = "無法重新命名歌單：\(error.localizedDescription)" }
    }
    func deletePlaylist(_ playlist: Playlist, context: ModelContext) async {
        do { try await repository(for: context).deletePlaylist(id: playlist.id); playlistRevision &+= 1 }
        catch { errorMessage = "無法刪除歌單：\(error.localizedDescription)" }
    }
    func addTrack(_ track: Track, to playlist: Playlist, context: ModelContext) async -> Bool {
        do {
            try await repository(for: context).addTrack(trackID: track.id, toPlaylist: playlist.id)
            playlistRevision &+= 1
            return true
        } catch {
            errorMessage = "無法將「\(track.title)」加入「\(playlist.name)」：\(error.localizedDescription)"
            return false
        }
    }
    func addTracks(_ tracks: [Track], to playlist: Playlist, context: ModelContext) async -> Bool {
        guard !tracks.isEmpty else { return true }
        let activityID = beginBackgroundActivity(kind: .library, title: "正在加入歌單", detail: "\(tracks.count) 首 · \(playlist.name)")
        defer { endBackgroundActivity(activityID) }
        do {
            try await repository(for: context).addTracks(trackIDs: tracks.map(\.id), toPlaylist: playlist.id)
            playlistRevision &+= 1
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    #if os(macOS)
    func revealInFinder(_ track: Track, context: ModelContext) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let descriptor = FetchDescriptor<MediaSourceRecord>(predicate: #Predicate { $0.id == track.sourceID })
                guard let source = try context.fetch(descriptor).first else { throw MediaSourceAccessError.accessDenied }
                let root = try await resolve(source: source, context: context)
                let lease = try await sourceAccess.lease(for: root)
                let url = try Self.safeTrackURL(root: root, relativePath: track.relativePath)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                _ = lease
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func moveToTrash(_ track: Track, context: ModelContext) async -> Bool {
        let activityID = beginBackgroundActivity(kind: .library, title: "正在移至垃圾桶", detail: track.title)
        defer { endBackgroundActivity(activityID) }
        let repository = repository(for: context)
        let playlistSnapshot: [UUID: [UUID]]
        do {
            let containingPlaylists = try await repository.playlists().filter { $0.trackIDs.contains(track.id) }
            playlistSnapshot = Dictionary(uniqueKeysWithValues: containingPlaylists.map { ($0.id, $0.trackIDs) })
        } catch {
            errorMessage = "無法讀取歌單狀態，已取消移至垃圾桶：\(error.localizedDescription)"
            return false
        }
        do {
            let descriptor = FetchDescriptor<MediaSourceRecord>(predicate: #Predicate { $0.id == track.sourceID })
            guard let source = try context.fetch(descriptor).first else { throw MediaSourceAccessError.accessDenied }
            let root = try await resolve(source: source, context: context)
            let lease = try await sourceAccess.lease(for: root)
            let url = try Self.safeTrackURL(root: root, relativePath: track.relativePath)
            try await repository.excludeTracks(ids: [track.id])
            var trashedURL: NSURL?
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
            } catch {
                let trashError = error
                do {
                    try await repository.restoreTracks(ids: [track.id], playlistTrackIDs: playlistSnapshot)
                } catch {
                    errorMessage = "移至垃圾桶失敗，且 CMV 資料回復也失敗：\(trashError.localizedDescription)；\(error.localizedDescription)"
                    return false
                }
                throw trashError
            }
            _ = lease
            if let cacheStore {
                do {
                    try await cacheStore.unpin(trackID: track.id)
                    pinnedTrackIDs.remove(track.id)
                } catch {
                    errorMessage = "檔案已移至垃圾桶，但離線副本清理失敗：\(error.localizedDescription)"
                }
            } else {
                pinnedTrackIDs.remove(track.id)
            }
            return true
        } catch {
            if errorMessage == nil || !(errorMessage?.contains("回復也失敗") ?? false) {
                errorMessage = "無法將「\(track.title)」移至垃圾桶：\(error.localizedDescription)"
            }
            return false
        }
    }
    #endif

    func analyze(trackID: UUID, url: URL) async throws -> AnalysisProfile {
        guard requirePro(.smartDJ) else { throw ProOperationError.requiresPro }
        let activityID = beginBackgroundActivity(kind: .analysis, title: "正在分析音訊", detail: url.lastPathComponent)
        defer { endBackgroundActivity(activityID) }
        return try await analyzer.analyze(trackID: trackID, url: url)
    }
    func analyzeAndPersist(trackID: UUID, url: URL, context: ModelContext) async throws -> AnalysisProfile {
        guard requirePro(.smartDJ) else { throw ProOperationError.requiresPro }
        let activityID = beginBackgroundActivity(kind: .analysis, title: "正在分析音訊", detail: url.lastPathComponent)
        defer { endBackgroundActivity(activityID) }
        let profile = try await analyzer.analyze(trackID: trackID, url: url)
        try await repository(for: context).setAnalysis(trackID: trackID, profile: profile)
        return profile
    }
    func makeSmartQueue(tracks: [Track], profiles: [UUID: AnalysisProfile],
                        history: [UUID: ListeningSignal], limit: Int = 25) async -> [DJSelection] {
        guard requirePro(.smartDJ) else { return [] }
        let activityID = beginBackgroundActivity(kind: .analysis, title: "智慧 DJ 正在選歌")
        defer { endBackgroundActivity(activityID) }
        return await smartDJ.makeQueue(from: tracks, profiles: profiles, history: history, limit: limit)
    }

    private static func fallbackSearchScore(_ candidate: LibrarySearchCandidate, tokens: [String]) -> Int {
        var score = (candidate.isFavorite ? 50 : 0) + min(5, max(0, candidate.rating)) * 10
        let fields = [
            (canonicalSearchValue(candidate.title), 1_000),
            (canonicalSearchValue(candidate.artist), 600),
            (canonicalSearchValue(candidate.album), 500)
        ]
        for token in tokens {
            var matched = false
            for (field, weight) in fields {
                if field == token { score += weight; matched = true }
                else if field.split(whereSeparator: \.isWhitespace).contains(where: { $0 == token }) { score += weight / 2; matched = true }
                else if field.contains(token) { score += weight / 3; matched = true }
            }
            if !matched { return 0 }
        }
        return score
    }
}

private extension RustTrackSnapshot {
    init(scan track: ScanTrackSnapshot) {
        self.init(
            identifier: track.fileIdentifier,
            relativePath: track.relativePath,
            fileSize: UInt64(max(0, track.fileSize)),
            modifiedAtMillis: epochMilliseconds(track.modifiedAt),
            title: track.title,
            availability: RustTrackAvailability(track.availability)
        )
    }
}
private extension RustTimelineTrack {
    init(_ track: PlaybackTimelineTrack) {
        self.init(sampleRateHz: track.sampleRateHz, totalFrames: track.totalFrames, startFrame: track.startFrame,
                  replayGainDB: track.replayGainDB, peak: track.peak)
    }
}
private extension RustScannedFile {
    init(file: ScannedMediaFile) {
        self.init(identifier: file.fileIdentifier, relativePath: file.relativePath,
                  fileSize: UInt64(max(0, file.fileSize)), modifiedAtMillis: epochMilliseconds(file.modifiedAt), title: file.title)
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
                  album: track.album, favorite: track.isFavorite, rating: UInt8(clamping: max(0, track.rating)))
    }
    init(candidate: LibrarySearchCandidate) {
        self.init(identifier: candidate.id.uuidString, title: canonicalSearchValue(candidate.title),
                  artist: canonicalSearchValue(candidate.artist), album: canonicalSearchValue(candidate.album),
                  favorite: candidate.isFavorite, rating: UInt8(clamping: max(0, candidate.rating)))
    }
}

enum LibraryDestination: String, CaseIterable, Identifiable {
    case nowPlaying, queue, songs, albums, artists, playlists, favorites, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .nowPlaying: "現在收聽"
        case .queue: "歌單"
        case .songs: "曲庫"
        case .albums: "專輯"
        case .artists: "歌手"
        case .playlists: "我的歌單"
        case .favorites: "最愛"
        case .settings: "設定"
        }
    }
    var symbol: String {
        switch self {
        case .nowPlaying: "sparkles"
        case .queue: "text.line.first.and.arrowtriangle.forward"
        case .songs: "music.note"
        case .albums: "square.stack"
        case .artists: "person.2"
        case .playlists: "music.note.list"
        case .favorites: "heart"
        case .settings: "gearshape"
        }
    }
}

private enum ProOperationError: LocalizedError {
    case requiresPro
    var errorDescription: String? { "本機聲學分析與 Smart DJ 需要 CMV Pro。" }
}
