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

private func cmvLocalized(_ key: String) -> String {
    AppLanguage.localized(key)
}

private func cmvLocalized(_ key: String, arguments: CVarArg...) -> String {
    let preference = UserDefaults.standard.string(forKey: AppLanguage.preferenceKey) ?? "system"
    return String(
        format: AppLanguage.localized(key),
        locale: AppLanguage.locale(for: preference),
        arguments: arguments
    )
}

private func epochMilliseconds(_ date: Date) -> Int64 {
    let value = date.timeIntervalSince1970 * 1_000
    guard value.isFinite else { return 0 }
    if value >= Double(Int64.max) { return Int64.max }
    if value <= Double(Int64.min) { return Int64.min }
    return Int64(value.rounded())
}

/// 描述歌曲頁的播放順序；只保存查詢條件與 UUID 順序，避免播放時一次
/// 建立整個曲庫的 Track 物件。
struct LibraryPlaybackQuery: Sendable {
    let query: String
    let sort: LibraryTrackSort?
    let ascending: Bool
    let randomTrackIDs: [UUID]?
    let nextOffset: Int
    let pageSize: Int
}

private struct LibraryPlaybackContinuation: Sendable {
    var query: LibraryPlaybackQuery
    var exhausted = false
}

struct BatchPinResult {
    let pinned: Int
    let alreadyPinned: Int
    let failed: Int
    let cancelled: Bool
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
    @ObservationIgnored private var currentTrackID: UUID?
    @ObservationIgnored private var tempoByTrackID: [UUID: Double] = [:]
    @ObservationIgnored private var adaptiveLevelFloor: Float = 0
    @ObservationIgnored private var previousRawLevel: Float = 0
    @ObservationIgnored private var lastOnsetTime: TimeInterval?
    @ObservationIgnored private var tempoCandidates: [Double] = []
    private(set) var estimatedTempoBPM: Double?
    private let minimumPublishInterval: TimeInterval = 1.0 / 60.0

    /// A stored analysis wins. Otherwise the live meter estimates once, then
    /// locks the result for the rest of the track instead of chasing volume.
    func beginTrack(_ trackID: UUID?, knownBPM: Double?) {
        guard currentTrackID != trackID else { return }
        currentTrackID = trackID
        adaptiveLevelFloor = 0
        previousRawLevel = 0
        lastOnsetTime = nil
        tempoCandidates.removeAll(keepingCapacity: true)
        guard let trackID else {
            estimatedTempoBPM = nil
            return
        }
        let tempo = Self.normalizedTempo(knownBPM) ?? tempoByTrackID[trackID]
        estimatedTempoBPM = tempo
    }

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
        updateTempoEstimate(rawLevel: clamped, at: now)
    }

    func pause() {
        smoothedLevel = 0
        var next = snapshot
        next.previousLevel = snapshot.level
        next.level = 0
        next.publishedAt = Date.timeIntervalSinceReferenceDate
        snapshot = next
    }

    private func updateTempoEstimate(rawLevel: Float, at time: TimeInterval) {
        guard let currentTrackID, estimatedTempoBPM == nil else { return }
        let threshold = max(0.09, adaptiveLevelFloor * 1.30 + 0.045)
        let crossedOnset = rawLevel >= threshold && previousRawLevel < threshold
        previousRawLevel = rawLevel
        adaptiveLevelFloor += (rawLevel - adaptiveLevelFloor) * (rawLevel > adaptiveLevelFloor ? 0.025 : 0.08)
        guard crossedOnset,
              lastOnsetTime.map({ time - $0 >= 0.24 }) ?? true else { return }

        if let lastOnsetTime {
            let interval = time - lastOnsetTime
            if interval >= 0.25, interval <= 2.0 {
                var candidate = 60 / interval
                while candidate > 180 { candidate /= 2 }
                while candidate < 60 { candidate *= 2 }
                tempoCandidates.append(candidate)
                if tempoCandidates.count > 9 { tempoCandidates.removeFirst() }
            }
        }
        self.lastOnsetTime = time

        guard tempoCandidates.count >= 6 else { return }
        let sorted = tempoCandidates.sorted()
        let median = sorted[sorted.count / 2]
        let deviations = sorted.map { abs($0 - median) }.sorted()
        let medianDeviation = deviations[deviations.count / 2]
        guard medianDeviation <= median * 0.24 else { return }
        let lockedTempo = median.rounded()
        tempoByTrackID[currentTrackID] = lockedTempo
        estimatedTempoBPM = lockedTempo
    }

    private static func normalizedTempo(_ bpm: Double?) -> Double? {
        guard let bpm, bpm.isFinite, bpm > 0 else { return nil }
        return min(180, max(60, bpm))
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
    private(set) var batchPinProgress: (completed: Int, total: Int)?
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
    private(set) var libraryRevision = 0
    private var lastMetadataUndo: MetadataUndoReceipt?
    private var metadataOperationInFlight = false
    var hasMetadataUndo: Bool { lastMetadataUndo != nil && !metadataOperationInFlight }
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
        if let stagedPlaybackQueue { return stagedPlaybackQueue }
        guard let mixedQueue, !mixedQueue.isEmpty else { return playback.queue }
        let index = mixedRouteIndex(in: mixedQueue)
            ?? playback.queue.currentIndex
        return PlaybackQueue(tracks: mixedQueue, currentIndex: index)
    }

    /// Queue-only view of the route. The panel must not subscribe to the
    /// playback revision used by elapsed-time and transport controls.
    var queuePanelDisplayQueue: PlaybackQueue {
        _ = queueRevision
        if let stagedPlaybackQueue { return stagedPlaybackQueue }
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
    @ObservationIgnored private let videoThumbnailCache: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.totalCostLimit = 32 * 1_024 * 1_024
        return cache
    }()
    private var playbackAccessLeases: [SecurityScopedResourceLease] = []
    private var videoAccessLeases: [SecurityScopedResourceLease] = []
    private var mixedQueue: [Track]?
    private var mixedQueueCurrentIndex: Int?
    private var mixedQueueSegmentStart: Int?
    private var activePlaybackContext: ModelContext?
    private var libraryPlaybackContinuation: LibraryPlaybackContinuation?
    @ObservationIgnored private let queueSnapshotStore: PlaybackQueueSnapshotStore
#if DEBUG && CMV_STOREKIT_TEST_HOST
    @ObservationIgnored var queueRestoreTestAfterSnapshot: (() async -> Void)?
#endif
    private var queueSnapshotRevision: Int64 = 0
    private var queueRestored = false
    private var mixedQueueBaseOrder: [Track]?
    private var playbackHistory: [UUID] = []
    private var queueMutationGeneration = 0
    private var stagedPlaybackQueue: PlaybackQueue?
    private var restoredQueueNeedsPreparation = false
    @ObservationIgnored private var libraryContinuationTask: Task<Void, Never>?
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

    func libraryTrackCount(context: ModelContext) async throws -> Int {
        try await repository(for: context).trackCount()
    }

    init(queueSnapshotStore: PlaybackQueueSnapshotStore = .defaultStore()) {
        self.queueSnapshotStore = queueSnapshotStore
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
            let previousTrackID = self.currentTrackID
            self.currentTrackID = track?.id
            if let track, previousTrackID != track.id {
                self.playbackHistory.removeAll { $0 == track.id }
                self.playbackHistory.append(track.id)
                if self.playbackHistory.count > PlaybackQueuePlanner.historyLimit {
                    self.playbackHistory.removeFirst(self.playbackHistory.count - PlaybackQueuePlanner.historyLimit)
                }
            }
            self.audioEnergy.beginTrack(track?.id, knownBPM: track?.analysis?.bpm)
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
            self.markQueueChanged()
        }
        playback.onQueueFinished = { [weak self] in self?.advanceAfterAudioQueue() }
        playback.onQueueChanged = { [weak self] in self?.markQueueChanged() }
        playback.onOutputLevelChanged = { [weak self] level in self?.receiveOutputLevel(level) }
        playback.onPlaybackError = { [weak self] error in
            self?.errorMessage = cmvLocalized("播放管線發生錯誤：%@", arguments: AppLanguage.localizedError(error))
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
            guard let self else { return }
            self.playbackControlsRevision &+= 1
            if self.queueRestored { self.persistPlaybackQueueSnapshot() }
        }.store(in: &transportObservations)
        playback.onRemotePlayRequested = { [weak self] in
            guard let self else { return }
            if self.videoURL != nil {
                self.videoSession.play()
            } else {
                do { try self.playback.play() }
                catch { self.errorMessage = cmvLocalized("播放失敗：%@", arguments: error.localizedDescription) }
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
        if queueRestored { persistPlaybackQueueSnapshot() }
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

    /// Apply a future-only route edit to the persisted mixed-media base order.
    /// Runtime queues only carry Track values, so duplicate occurrences are
    /// matched by their ordinal within the displayed route.
    private func mixedBaseOrder(
        old: PlaybackQueue,
        updated: PlaybackQueue,
        base: [Track],
        playNext: Bool
    ) -> [Track] {
        guard let current = old.current else { return updated.tracks }
        let currentOrdinal = old.tracks[..<old.currentIndex].reduce(into: 0) { count, track in
            if track.id == current.id { count += 1 }
        }
        guard let baseCurrentIndex = base.indices.first(where: {
            base[$0].id == current.id
        }), base[baseCurrentIndex].id == current.id else {
            return updated.tracks
        }
        let matchingBaseCurrent = base.indices.filter { base[$0].id == current.id }
            .dropFirst(currentOrdinal).first
        guard let matchingBaseCurrent else { return updated.tracks }

        let oldFuture = Array(old.tracks.dropFirst(old.currentIndex + 1))
        let newFuture = Array(updated.tracks.dropFirst(updated.currentIndex + 1))
        let basePrefix = Array(base.prefix(matchingBaseCurrent + 1))
        let baseIndicesForOldFuture = oldFuture.indices.map { offset -> Int? in
            let queueIndex = old.currentIndex + 1 + offset
            let id = old.tracks[queueIndex].id
            let ordinal = old.tracks[..<queueIndex].reduce(into: 0) { count, track in
                if track.id == id { count += 1 }
            }
            return base.indices.filter { base[$0].id == id }.dropFirst(ordinal).first
        }
        var matchedOld = Array(repeating: false, count: oldFuture.count)
        var desiredMatches: [Int?] = []
        for track in newFuture {
            if let oldIndex = oldFuture.indices.first(where: {
                !matchedOld[$0] && oldFuture[$0].id == track.id
            }) {
                matchedOld[oldIndex] = true
                desiredMatches.append(oldIndex)
            } else {
                desiredMatches.append(nil)
            }
        }
        let allExistingMatched = desiredMatches.allSatisfy { $0 != nil }
            && matchedOld.allSatisfy { $0 }
            && baseIndicesForOldFuture.allSatisfy { $0 != nil }
        if allExistingMatched {
            return basePrefix + desiredMatches.compactMap { match in
                guard let match, let baseIndex = baseIndicesForOldFuture[match] else { return nil }
                return base[baseIndex]
            }
        }

        let removedBaseIndices = Set(baseIndicesForOldFuture.enumerated().compactMap { offset, baseIndex in
            matchedOld[offset] ? nil : baseIndex
        })
        let retainedFuture = base.enumerated().compactMap { index, track -> Track? in
            guard index > matchingBaseCurrent else { return nil }
            return removedBaseIndices.contains(index) ? nil : track
        }
        let firstMatchedOffset = desiredMatches.firstIndex { $0 != nil } ?? newFuture.count
        let leadingInsertions = newFuture.enumerated().compactMap { offset, track in
            offset < firstMatchedOffset && desiredMatches[offset] == nil ? track : nil
        }
        let trailingInsertions = newFuture.enumerated().compactMap { offset, track in
            offset >= firstMatchedOffset && desiredMatches[offset] == nil ? track : nil
        }
        if playNext {
            return basePrefix + leadingInsertions + retainedFuture + trailingInsertions
        }
        return basePrefix + retainedFuture + leadingInsertions + trailingInsertions
    }

    private func playbackOccurrenceSignature() -> (trackID: UUID, ordinal: Int)? {
        let queue = playback.queue
        guard let current = queue.current else { return nil }
        let ordinal = queue.tracks[..<queue.currentIndex].reduce(into: 0) { count, track in
            if track.id == current.id { count += 1 }
        }
        return (current.id, ordinal)
    }

    private func rebaseQueueToCurrent(_ queue: PlaybackQueue, after oldIndex: Int) -> PlaybackQueue? {
        guard let currentTrackID else { return nil }
        let start = min(queue.tracks.count, max(0, oldIndex + 1))
        let index = queue.tracks.indices.dropFirst(start).first { queue.tracks[$0].id == currentTrackID }
            ?? queue.tracks.firstIndex { $0.id == currentTrackID }
        var result = queue
        if let index {
            result.currentIndex = index
        } else if let active = playback.queue.current {
            let insertion = min(queue.tracks.count, max(0, oldIndex + 1))
            result.tracks.insert(active, at: insertion)
            result.currentIndex = insertion
        } else {
            return nil
        }
        return result
    }

    @discardableResult
    func beginBackgroundActivity(kind: BackgroundActivityKind, title: String, detail: String? = nil,
                                 localizedTitleKey: String? = nil, localizedTitleArgument: String? = nil) -> UUID {
        let id = UUID()
        backgroundActivities[id] = BackgroundActivity(id: id, kind: kind, title: title,
                                                       localizedTitleKey: localizedTitleKey,
                                                       localizedTitleArgument: localizedTitleArgument,
                                                       detail: detail, startedAt: .now)
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
        let activityID = beginBackgroundActivity(
            kind: .scanning,
            title: cmvLocalized("正在加入音樂來源"),
            detail: cmvLocalized("確認資料夾與授權")
        )
        defer { endBackgroundActivity(activityID) }
        let existingSources: [MediaSourceRecord]
        do {
            existingSources = try context.fetch(FetchDescriptor<MediaSourceRecord>())
        } catch {
            errorMessage = cmvLocalized("無法讀取既有來源：%@", arguments: error.localizedDescription)
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
                        failures.append(cmvLocalized(
                            "%@（請加入包含音樂的資料夾，而非單一檔案）",
                            arguments: normalizedURL.lastPathComponent
                        ))
                        continue
                    }
                    let identityPath = canonicalPath(normalizedURL.path)
                    guard handledPaths.insert(identityPath).inserted else { continue }
                    let bookmark = try provider.makeBookmark(for: url)
                    if let existingID = existingIDsByPath[identityPath] {
                        reimports.append((existingID, normalizedURL.path, bookmark))
                    } else if unresolvedNames.contains(normalizedURL.lastPathComponent) {
                        failures.append(cmvLocalized(
                            "%@（既有同名來源無法驗證，請到設定重新授權，避免建立重複曲庫）",
                            arguments: normalizedURL.lastPathComponent
                        ))
                    } else {
                        entries.append((normalizedURL.lastPathComponent, normalizedURL.path, bookmark))
                    }
                } catch {
                    let cocoaError = error as NSError
                    failures.append(cmvLocalized(
                        "%@（%@ %lld：%@）",
                        arguments: normalizedURL.lastPathComponent,
                        cocoaError.domain,
                        Int64(cocoaError.code),
                        error.localizedDescription
                    ))
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
            if !failures.isEmpty {
                errorMessage = cmvLocalized("無法加入資料夾：%@", arguments: failures.joined(separator: "、"))
            }
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
            errorMessage = cmvLocalized("無法保存音樂來源：%@", arguments: error.localizedDescription)
            return
        }
        for source in reimportedSources {
            scheduleScan(source, context: context)
        }
        for source in pendingSources { scheduleScan(source, context: context) }
        if !failures.isEmpty {
            errorMessage = cmvLocalized("部分資料夾無法加入：%@", arguments: failures.joined(separator: "、"))
        }
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
        let activityID = beginBackgroundActivity(kind: .scanning, title: cmvLocalized("正在確認音樂來源"))
        defer { endBackgroundActivity(activityID) }
        let probes = sources.filter { source in
            source.status != .scanning && !scanningSourceIDs.contains(source.id)
                && !pendingSourceScans.contains(where: { $0.source.id == source.id })
        }.map { (id: $0.id, bookmark: $0.bookmarkData) }
        let provider = sourceProvider
        let probeTask = Task.detached(priority: .utility) {
            var results: [SourceStatusProbeResult] = []
            for probe in probes {
                guard !Task.isCancelled else { break }
                let result: SourceStatusProbeResult
                do {
                    let resolution = try provider.resolveWithRefresh(bookmark: probe.bookmark)
                    if resolution.url.startAccessingSecurityScopedResource() {
                        defer { resolution.url.stopAccessingSecurityScopedResource() }
                        let status: MediaSourceStatus = FileManager.default.isReadableFile(atPath: resolution.url.path)
                            ? .available : .offline
                        result = SourceStatusProbeResult(id: probe.id, originalBookmark: probe.bookmark, refreshedBookmark: resolution.refreshedBookmark, status: status)
                    } else {
                        result = SourceStatusProbeResult(id: probe.id, originalBookmark: probe.bookmark, refreshedBookmark: nil, status: .permissionRequired)
                    }
                } catch {
                    let status: MediaSourceStatus
                    if let accessError = error as? MediaSourceAccessError,
                       accessError == .staleBookmark || accessError == .accessDenied {
                        status = .permissionRequired
                    } else {
                        status = .offline
                    }
                    result = SourceStatusProbeResult(id: probe.id, originalBookmark: probe.bookmark, refreshedBookmark: nil, status: status)
                }
                results.append(result)
            }
            return results
        }
        // Cancel remaining probes when the view's task ends. A synchronous
        // provider call already in progress must finish before scope release.
        let results = await withTaskCancellationHandler {
            await probeTask.value
        } onCancel: {
            probeTask.cancel()
        }
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
                errorMessage = cmvLocalized("無法保存音樂來源狀態：%@", arguments: error.localizedDescription)
            }
        }
    }

    private func repairRemountDuplicatesIfNeeded(sources: [MediaSourceRecord], context: ModelContext) async {
        let repairVersion = 1
        guard UserDefaults.standard.integer(forKey: Self.duplicatePathRepairDefaultsKey) < repairVersion else { return }
        let activityID = beginBackgroundActivity(
            kind: .library,
            title: cmvLocalized("正在整理曲庫"),
            detail: cmvLocalized("合併 NAS 重連造成的重複項目")
        )
        defer { endBackgroundActivity(activityID) }
        do {
            let repaired = try await repository(for: context)
                .repairDuplicateTracksByRelativePath(sourceIDs: sources.map(\.id))
            if repaired > 0 {
                for source in sources { source.updatedAt = .now }
                try context.save()
                updateBackgroundActivity(
                    activityID,
                    detail: cmvLocalized("已合併 %lld 筆重複項目", arguments: Int64(repaired))
                )
            }
            UserDefaults.standard.set(repairVersion, forKey: Self.duplicatePathRepairDefaultsKey)
        } catch {
            errorMessage = cmvLocalized("無法整理重複曲目：%@", arguments: error.localizedDescription)
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
            errorMessage = cmvLocalized("無法重新授權音樂來源：%@", arguments: AppLanguage.localizedError(error))
        }
    }

    func play(track: Track, context: ModelContext) { play(tracks: [track], startingAt: 0, context: context) }

    func play(tracks: [Track], startingAt: Int = 0, context: ModelContext,
              libraryQuery: LibraryPlaybackQuery?) {
        cancelLibraryPlaybackContinuation()
        if let libraryQuery {
            libraryPlaybackContinuation = LibraryPlaybackContinuation(query: libraryQuery)
        }
        play(tracks: tracks, startingAt: startingAt, context: context,
             preserveLibraryPlaybackContinuation: true)
    }

    private func cancelLibraryPlaybackContinuation() {
        libraryContinuationTask?.cancel()
        libraryContinuationTask = nil
        libraryPlaybackContinuation = nil
    }

    /// Restore the compact queue snapshot once the SwiftData context is ready.
    /// Restoration only hydrates queue metadata and never starts playback.
    func restorePlaybackQueueIfNeeded(context: ModelContext) async {
        guard !queueRestored else { return }
        guard playback.queue.tracks.isEmpty, mixedQueue == nil, currentTrackID == nil else {
            queueRestored = true
            return
        }
        let initialQueueRevision = queueRevision
        let initialPreparationGeneration = playbackPreparationGeneration
        let restoreGuardReason: () -> String? = {
            if Task.isCancelled { return "cancelled" }
            if self.queueRestored { return "restore_superseded" }
            if self.playbackPreparationGeneration != initialPreparationGeneration { return "playback_preparation" }
            if self.queueRevision != initialQueueRevision { return "queue_revision" }
            if !self.playback.queue.tracks.isEmpty { return "route_nonempty" }
            if self.mixedQueue != nil { return "mixed_nonempty" }
            if self.currentTrackID != nil { return "current_non_nil" }
            return nil
        }
        let rebaseCurrentRouteAfterMutation: () -> Bool = {
            guard self.queueRevision != initialQueueRevision, self.queueRestored else { return false }
            self.persistPlaybackQueueSnapshot()
            return true
        }
        guard let snapshot = await queueSnapshotStore.load() else {
            if rebaseCurrentRouteAfterMutation() { return }
            guard restoreGuardReason() == nil else { return }
            queueRestored = true
            return
        }
        // `load()` advances the store's revision even for a valid empty snapshot.
        // Adopt it before any early return so the next mutation cannot be rejected
        // as stale by the actor-backed store.
        queueSnapshotRevision = max(queueSnapshotRevision, snapshot.revision)
        if rebaseCurrentRouteAfterMutation() { return }
        guard restoreGuardReason() == nil else { return }
        guard !snapshot.entries.isEmpty else {
            queueRestored = true
            return
        }
#if DEBUG && CMV_STOREKIT_TEST_HOST
        await queueRestoreTestAfterSnapshot?()
#endif
        do {
            let ids = Array(Set(snapshot.entries.map(\.trackID)))
            let fetched = try await repository(for: context).tracks(ids: ids, includeArtwork: false)
            if rebaseCurrentRouteAfterMutation() { return }
            guard restoreGuardReason() == nil else { return }
            let tracksByID = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
            let restoredEntries = snapshot.entries.compactMap { entry -> (PlaybackQueueOccurrence, Track)? in
                guard let track = tracksByID[entry.trackID] else { return nil }
                return (entry, track)
            }
            let tracks = restoredEntries.map(\.1)
            guard !tracks.isEmpty else {
                // Every saved ID is gone. This is a completed restore attempt,
                // so a later panel task must not retry the same stale snapshot.
                queueRestored = true
                return
            }
            let restoredCurrentIndex = snapshot.current.flatMap { current in
                restoredEntries.firstIndex { $0.0.occurrenceID == current.occurrenceID }
            }
            let nextAvailable = Set(snapshot.entries.dropFirst(snapshot.currentIndex).map(\.occurrenceID))
            let currentIndex = restoredCurrentIndex
                ?? restoredEntries.firstIndex { nextAvailable.contains($0.0.occurrenceID) }
                ?? tracks.count - 1
            if restoredCurrentIndex == nil {
                errorMessage = cmvLocalized("先前播放的曲目已無法使用，已選擇其他可用曲目；按播放後才會開始。")
            }
            let restoredQueue = PlaybackQueue(tracks: tracks, currentIndex: currentIndex)
            mixedQueue = tracks.contains(where: { routeContainsVideo([$0]) }) ? tracks : nil
            let restoredBaseEntries = snapshot.baseEntries.compactMap { entry -> (PlaybackQueueOccurrence, Track)? in
                guard let track = tracksByID[entry.trackID] else { return nil }
                return (entry, track)
            }
            let restoredOccurrenceIDs = Set(restoredEntries.map { $0.0.occurrenceID })
            let hasCompleteBase = restoredBaseEntries.count == restoredEntries.count
                && Set(restoredBaseEntries.map { $0.0.occurrenceID }) == restoredOccurrenceIDs
            let baseTracks = hasCompleteBase ? restoredBaseEntries.map(\.1) : tracks
            mixedQueueBaseOrder = mixedQueue != nil && hasCompleteBase ? baseTracks : nil
            mixedQueueCurrentIndex = mixedQueue == nil ? nil : currentIndex
            mixedQueueSegmentStart = nil
            activePlaybackContext = context
            playbackHistory = snapshot.history.compactMap { occurrenceID in
                restoredEntries.first { $0.0.occurrenceID == occurrenceID }?.1.id
            }
            if let continuation = snapshot.continuation {
                let query = LibraryPlaybackQuery(
                    query: continuation.query,
                    sort: continuation.sortRawValue.flatMap(LibraryTrackSort.init(rawValue:)),
                    ascending: continuation.ascending,
                    randomTrackIDs: continuation.randomTrackIDs,
                    nextOffset: continuation.nextOffset,
                    pageSize: continuation.pageSize
                )
                libraryPlaybackContinuation = LibraryPlaybackContinuation(
                    query: query,
                    exhausted: continuation.exhausted
                )
            }
            let baseIndex = snapshot.current.flatMap { current in
                restoredBaseEntries.firstIndex { $0.0.occurrenceID == current.occurrenceID }
            } ?? currentIndex
            let restoredBaseQueue = PlaybackQueue(
                tracks: baseTracks,
                currentIndex: hasCompleteBase ? baseIndex : currentIndex
            )
            // setQueue can synchronously publish queue callbacks. Mark restore
            // complete first so those callbacks persist the hydrated snapshot.
            queueRestored = true
            playback.setQueue(restoredQueue, baseQueue: restoredBaseQueue)
            playback.restoreQueueModes(
                shuffleEnabled: snapshot.shuffleEnabled && mixedQueue == nil && hasCompleteBase,
                repeatEnabled: snapshot.repeatMode == .all
            )
            mixedMediaShuffleEnabled = snapshot.shuffleEnabled && mixedQueue != nil && hasCompleteBase
            restoredQueueNeedsPreparation = true
            markQueueChanged()
        } catch {
            guard restoreGuardReason() == nil else { return }
            // A stale queue entry is harmless; preserve the snapshot and let
            // the next mutation overwrite it after valid IDs are available.
            errorMessage = cmvLocalized("無法還原播放佇列：%@", arguments: error.localizedDescription)
        }
    }

    private func persistPlaybackQueueSnapshot() {
        let queue = queuePanelDisplayQueue
        guard !queue.tracks.isEmpty else {
            queueSnapshotRevision &+= 1
            let empty = PlaybackQueueSnapshot(revision: queueSnapshotRevision)
            Task { try? await queueSnapshotStore.save(empty) }
            return
        }
        queueSnapshotRevision &+= 1
        var occurrencePool: [UUID: [UUID]] = [:]
        let entries = queue.tracks.map { track -> PlaybackQueueOccurrence in
            let occurrence = PlaybackQueueOccurrence(trackID: track.id)
            occurrencePool[track.id, default: []].append(occurrence.occurrenceID)
            return occurrence
        }
        let baseTracks = mixedQueueBaseOrder ?? (mixedQueue == nil ? playback.baseQueueSnapshot.tracks : queue.tracks)
        let baseEntries = baseTracks.map { track -> PlaybackQueueOccurrence in
            if var occurrences = occurrencePool[track.id], !occurrences.isEmpty {
                let occurrenceID = occurrences.removeFirst()
                occurrencePool[track.id] = occurrences
                return PlaybackQueueOccurrence(occurrenceID: occurrenceID, trackID: track.id)
            }
            return PlaybackQueueOccurrence(trackID: track.id)
        }
        let historyOccurrences = playbackHistory.compactMap { trackID in
            entries.first { $0.trackID == trackID }?.occurrenceID
        }
        let continuation = libraryPlaybackContinuation.map { value in
            PlaybackQueueContinuationSnapshot(
                query: value.query.query,
                sortRawValue: value.query.sort?.rawValue,
                ascending: value.query.ascending,
                randomTrackIDs: value.query.randomTrackIDs,
                nextOffset: value.query.nextOffset,
                pageSize: value.query.pageSize,
                exhausted: value.exhausted
            )
        }
            let snapshot = PlaybackQueueSnapshot(
            revision: queueSnapshotRevision,
            entries: entries,
            baseEntries: baseEntries,
            currentIndex: queue.currentIndex,
            history: historyOccurrences,
            continuation: continuation,
            shuffleEnabled: isShuffleEnabled,
            repeatMode: playback.isRepeatEnabled ? .all : .off
        )
        Task { try? await queueSnapshotStore.save(snapshot) }
    }

    var canContinueLibraryPlayback: Bool {
        libraryPlaybackContinuation?.exhausted == false
    }

    func stopVideoPlayback(invalidatePendingPreparation: Bool = true) {
        stagedPlaybackQueue = nil
        if invalidatePendingPreparation {
            playbackPreparationGeneration &+= 1
            smartPrefetchTask?.cancel()
            smartPrefetchTask = nil
            cancelLibraryPlaybackContinuation()
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
            guard canSkipVideoForward || canContinueLibraryPlayback else { return }
            advanceAfterVideo(context: context, manualSkip: true)
            return
        }
        if playback.queue.currentIndex + 1 < playback.queue.tracks.count {
            if restoredQueueNeedsPreparation {
                play(tracks: playback.queue.tracks, startingAt: playback.queue.currentIndex + 1,
                     context: context, preserveLibraryPlaybackContinuation: true)
                return
            }
            do { try playback.skipForward() }
            catch { errorMessage = cmvLocalized("無法播放下一首：%@", arguments: AppLanguage.localizedError(error)) }
            return
        }
        if restoredQueueNeedsPreparation {
            play(tracks: playback.queue.tracks, startingAt: playback.queue.currentIndex,
                 context: context, preserveLibraryPlaybackContinuation: true)
            return
        }
        if canContinueLibraryPlayback {
            continueLibraryPlayback(context: context, advanceOnLoad: true)
            return
        }
        guard let mixedQueue,
              let currentIndex = mixedRouteIndex(in: mixedQueue),
              mixedQueue.indices.contains(currentIndex + 1) else { return }
        play(tracks: mixedQueue, startingAt: currentIndex + 1, context: context,
             preserveLibraryPlaybackContinuation: true)
    }

    private var shouldReturnToPreviousMixedMedia: Bool {
        playback.elapsed <= 3 && playback.queue.currentIndex == 0
    }

    private func playPreviousMixedMedia(context: ModelContext) -> Bool {
        guard shouldReturnToPreviousMixedMedia,
              let mixedQueue,
              let currentIndex = mixedRouteIndex(in: mixedQueue),
              mixedQueue.indices.contains(currentIndex - 1) else { return false }
        play(tracks: mixedQueue, startingAt: currentIndex - 1, context: context,
             preserveLibraryPlaybackContinuation: true)
        return true
    }

    func skipCurrentMediaBackward(context: ModelContext) {
        smartPrefetchTask?.cancel()
        smartPrefetchTask = nil
        guard videoURL != nil else {
            if !playPreviousMixedMedia(context: context) {
                if restoredQueueNeedsPreparation {
                    let queue = playback.queue
                    guard queue.tracks.indices.contains(queue.currentIndex - 1) else {
                        play(tracks: queue.tracks, startingAt: queue.currentIndex,
                             context: context, preserveLibraryPlaybackContinuation: true)
                        return
                    }
                    play(tracks: queue.tracks, startingAt: queue.currentIndex - 1,
                         context: context, preserveLibraryPlaybackContinuation: true)
                    return
                }
                do { try playback.skipBackward() }
                catch { errorMessage = cmvLocalized("無法播放上一首：%@", arguments: AppLanguage.localizedError(error)) }
            }
            return
        }
        let queue = playback.queue
        let previousIndex = queue.currentIndex - 1
        guard queue.tracks.indices.contains(previousIndex) else { return }
        play(tracks: queue.tracks, startingAt: previousIndex, context: context,
             preserveLibraryPlaybackContinuation: true)
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
            markQueueChanged()
            return
        }
        if !mixedMediaShuffleEnabled { mixedQueueBaseOrder = route }
        mixedMediaShuffleEnabled.toggle()
        guard mixedMediaShuffleEnabled else {
            playbackRevision &+= 1
            let base = mixedQueueBaseOrder
            mixedQueue = base ?? route
            mixedQueueBaseOrder = nil
            if let restored = mixedQueue, let currentTrackID {
                let ordinal = route[..<currentIndex].filter { $0.id == currentTrackID }.count
                mixedQueueCurrentIndex = restored.indices.filter { restored[$0].id == currentTrackID }
                    .dropFirst(ordinal).first
            }
            markQueueChanged()
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
        markQueueChanged()
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
        restoredQueueNeedsPreparation = false
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
                audioEnergy.beginTrack(metadata.id, knownBPM: nil)
                videoSession.load(url: url, autoplay: true)
            } catch {
                errorMessage = cmvLocalized("無法開啟影片：%@", arguments: error.localizedDescription)
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
                        errorMessage = cmvLocalized("曲庫目前沒有可播放的歌曲。請先加入音樂來源並完成索引。")
                        return
                    }
                    play(track: first, context: context)
                } catch {
                    errorMessage = cmvLocalized("無法載入曲庫：%@", arguments: error.localizedDescription)
                }
            }
            return
        }
        if restoredQueueNeedsPreparation {
            play(tracks: playback.queue.tracks, startingAt: playback.queue.currentIndex,
                 context: context, preserveLibraryPlaybackContinuation: true)
            return
        }
        do { try playback.play() }
        catch { errorMessage = cmvLocalized("播放失敗：%@", arguments: error.localizedDescription) }
    }

    /// 在目前曲目結束後載入曲庫播放來源的下一批曲目。只在需要時建立
    /// Track，並以 preparation generation 讓新的播放或清空佇列取消工作。
    private func continueLibraryPlayback(context: ModelContext, advanceOnLoad: Bool = false) {
        guard libraryContinuationTask == nil,
              let continuation = libraryPlaybackContinuation,
              !continuation.exhausted else { return }
        let requestGeneration = playbackPreparationGeneration
        let requestedTrackID = currentTrack?.id
        libraryContinuationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { libraryContinuationTask = nil }
            let query = continuation.query
            let offset = query.nextOffset
            let activityID = beginBackgroundActivity(kind: .playback,
                                                      title: cmvLocalized("正在準備播放"))
            defer { endBackgroundActivity(activityID) }
            guard requestGeneration == playbackPreparationGeneration,
                  !Task.isCancelled else { return }

            let page: [Track]
            if let randomTrackIDs = query.randomTrackIDs {
                let end = min(offset + query.pageSize, randomTrackIDs.count)
                let ids = offset < end ? Array(randomTrackIDs[offset..<end]) : []
                page = await tracks(ids: ids, context: context, includeArtwork: false)
            } else {
                page = await searchTracks(query: query.query, context: context,
                                          sort: query.sort, ascending: query.ascending,
                                          limit: query.pageSize, offset: offset,
                                          includeArtwork: false)
            }
            guard requestGeneration == playbackPreparationGeneration,
                  !Task.isCancelled else { return }

            var next = continuation
            next.exhausted = page.count < query.pageSize
            next.query = LibraryPlaybackQuery(query: query.query, sort: query.sort,
                                              ascending: query.ascending,
                                              randomTrackIDs: query.randomTrackIDs,
                                              nextOffset: offset + query.pageSize,
                                              pageSize: query.pageSize)
            libraryPlaybackContinuation = next
            guard !page.isEmpty else {
                libraryPlaybackContinuation = nil
                // A manual Next at the end of the catalog must not stop the
                // track that is still playing while the last page is checked.
                if advanceOnLoad { return }
                if videoURL != nil {
                    stopVideoPlayback(invalidatePendingPreparation: false)
                } else {
                    playbackAccessLeases.removeAll()
                    activePlaybackContext = nil
                }
                return
            }

            let priorRoute = mixedQueue ?? playback.queue.tracks
            let movieExtensions: Set<String> = ["mp4", "mov", "m4v"]
            let containsVideo = page.contains { track in
                track.mediaKind == .video || movieExtensions.contains(URL(fileURLWithPath: track.relativePath).pathExtension.lowercased())
            }
            // Keep already loaded route entries when crossing a page boundary.
            // This preserves queue history for mixed-media previous/next while
            // still materializing only one new page at a time.
            // Mixed-media playback only needs a bounded amount of history for
            // previous/queue context. Keeping the tail avoids rebuilding an
            // ever-growing 50k-track route at every page boundary while the
            // continuation offset still owns the complete logical order.
            let historyLimit = max(1, query.pageSize * 2)
            let priorHistory = priorRoute.count > historyLimit
                ? Array(priorRoute.suffix(historyLimit))
                : priorRoute
            let pageStart = priorHistory.count
            let route = priorHistory + page
            // A route that has already crossed a video boundary must be
            // rebuilt as one bounded route even when this page is audio-only;
            // otherwise mixedQueue would not contain the newly appended audio
            // and mixedRouteIndex could no longer resolve the current track.
            if videoURL != nil || containsVideo || mixedQueue != nil {
                play(tracks: route, startingAt: pageStart, context: context,
                     preserveLibraryPlaybackContinuation: true)
            } else {
                await appendLibraryAudioPage(page, context: context,
                                             requestGeneration: requestGeneration,
                                             advanceOnLoad: advanceOnLoad,
                                             requestedTrackID: requestedTrackID)
            }
        }
    }

    private func appendLibraryAudioPage(_ tracks: [Track], context: ModelContext,
                                        requestGeneration: Int, advanceOnLoad: Bool,
                                        requestedTrackID: UUID?) async {
        guard requestGeneration == playbackPreparationGeneration,
              activePlaybackContext === context, videoURL == nil,
              !tracks.isEmpty else { return }
        do {
            let sources = try context.fetch(FetchDescriptor<MediaSourceRecord>())
            let sourcesByID = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
            let cachedURLs = await cacheStore?.cachedURLs(trackIDs: tracks.map(\.id)) ?? [:]
            var roots: [UUID: URL] = [:]
            var leases: [SecurityScopedResourceLease] = []
            var resolvedURLs = cachedURLs
            for track in tracks where resolvedURLs[track.id] == nil {
                guard let source = sourcesByID[track.sourceID] else {
                    throw MediaSourceAccessError.accessDenied
                }
                let root: URL
                if let cachedRoot = roots[track.sourceID] {
                    root = cachedRoot
                } else {
                    root = try await resolve(source: source, context: context)
                    roots[track.sourceID] = root
                    leases.append(try await sourceAccess.lease(for: root))
                }
                resolvedURLs[track.id] = try Self.safeTrackURL(root: root, relativePath: track.relativePath)
            }
            guard requestGeneration == playbackPreparationGeneration,
                  activePlaybackContext === context, videoURL == nil else { return }
            playbackAccessLeases.append(contentsOf: leases)
            let previousCount = playback.queue.tracks.count
            let stillOnRequestedTrack = playback.queue.current?.id == requestedTrackID
            playback.appendToQueue(tracks, resolvedURLs: resolvedURLs)
            markQueueChanged()
            if advanceOnLoad && stillOnRequestedTrack && playback.queue.currentIndex == previousCount - 1 {
                // A manual Next switches immediately; skipForward preserves
                // whether the player was playing or paused.
                try playback.skipForward()
            } else if !advanceOnLoad || playback.queue.currentIndex == previousCount {
                // At natural EOF appendToQueue already selects the first new
                // track. Do not skip it a second time.
                try playback.play()
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = cmvLocalized("無法準備播放：%@", arguments: AppLanguage.localizedError(error))
            libraryPlaybackContinuation = nil
        }
    }

    func advanceAfterVideo(context: ModelContext, manualSkip: Bool = false) {
        guard videoURL != nil else { return }
        let queue = playback.queue
        let nextIndex = queue.currentIndex + 1
        guard queue.tracks.indices.contains(nextIndex) else {
            if canContinueLibraryPlayback {
                continueLibraryPlayback(context: context, advanceOnLoad: manualSkip)
            } else {
                stopVideoPlayback()
            }
            return
        }
        play(tracks: queue.tracks, startingAt: nextIndex, context: context,
             preserveLibraryPlaybackContinuation: true)
    }

    private func advanceAfterAudioQueue() {
        if mixedQueue == nil {
            guard let context = activePlaybackContext else { playbackAccessLeases.removeAll(); return }
            let audioQueue = playback.queue
            let nextIndex = audioQueue.currentIndex + 1
            guard audioQueue.tracks.indices.contains(nextIndex) else {
                if canContinueLibraryPlayback {
                    continueLibraryPlayback(context: context)
                    return
                }
                playbackAccessLeases.removeAll()
                activePlaybackContext = nil
                return
            }
            play(tracks: audioQueue.tracks, startingAt: nextIndex, context: context,
                 preserveLibraryPlaybackContinuation: true)
            return
        }
        guard let mixedQueue, let context = activePlaybackContext,
              let currentIndex = mixedRouteIndex(in: mixedQueue) else {
            playbackAccessLeases.removeAll()
            return
        }
        let nextIndex = currentIndex + 1
        guard mixedQueue.indices.contains(nextIndex) else {
            if canContinueLibraryPlayback {
                continueLibraryPlayback(context: context)
                return
            }
            self.mixedQueue = nil
            mixedQueueCurrentIndex = nil
            mixedQueueSegmentStart = nil
            mixedMediaShuffleEnabled = false
            markQueueChanged()
            playbackAccessLeases.removeAll()
            return
        }
        play(tracks: mixedQueue, startingAt: nextIndex, context: context,
             preserveLibraryPlaybackContinuation: true)
    }

    func play(tracks: [Track], startingAt: Int = 0, context: ModelContext) {
        cancelLibraryPlaybackContinuation()
        play(tracks: tracks, startingAt: startingAt, context: context,
             preserveLibraryPlaybackContinuation: true)
    }

    private func play(tracks: [Track], startingAt: Int, context: ModelContext,
                      preserveLibraryPlaybackContinuation: Bool) {
        let restoringAudioQueue = restoredQueueNeedsPreparation && mixedQueue == nil
            && playback.queue.tracks.map(\.id) == tracks.map(\.id)
        let restoredBaseQueue = restoringAudioQueue ? playback.baseQueueSnapshot : nil
        queueRestored = true
        queueMutationGeneration &+= 1
        stagedPlaybackQueue = nil
        if !preserveLibraryPlaybackContinuation {
            cancelLibraryPlaybackContinuation()
        }
        if mixedQueue?.map(\.id) != tracks.map(\.id) { mixedMediaShuffleEnabled = false }
        smartPrefetchTask?.cancel()
        smartPrefetchTask = nil
        playbackPreparationGeneration &+= 1
        let requestGeneration = playbackPreparationGeneration
        Task { @MainActor [weak self] in
            guard let self else { return }
            let activityID = beginBackgroundActivity(kind: .playback, title: cmvLocalized("正在準備播放"))
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
                    restoredQueueNeedsPreparation = false
                    mixedQueue = tracks
                    mixedQueueCurrentIndex = startingAt
                    mixedQueueSegmentStart = nil
                    markQueueChanged()
                    playbackAccessLeases.removeAll()
                    videoAccessLeases = leases
                    activePlaybackContext = context
                    videoTrack = selectedTrack
                    videoURL = selectedURL
                    audioEnergy.beginTrack(selectedTrack.id, knownBPM: selectedTrack.analysis?.bpm)
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
                let audioRange = restoringAudioQueue ? 0..<nextVideoIndex : startingAt..<nextVideoIndex
                let audioTracks = Array(tracks[audioRange]).filter { track in
                    track.id == selectedTrack.id || track.mediaKind != .video
                }
                guard !audioTracks.isEmpty else { throw MediaScanError.unsupportedFile(path: selectedTrack.relativePath) }
                guard let audioIndex = restoringAudioQueue ? startingAt : audioTracks.firstIndex(of: selectedTrack) else {
                    throw MediaScanError.unsupportedFile(path: selectedTrack.relativePath)
                }
                let tracksToResolve = restoringAudioQueue ? audioTracks : Array(audioTracks.dropFirst(audioIndex + 1))
                let cachedURLs = await cacheStore?.cachedURLs(trackIDs: tracksToResolve.map(\.id)) ?? [:]
                guard requestGeneration == playbackPreparationGeneration else { return }
                for track in tracksToResolve {
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
                try await playback.load(PlaybackQueue(tracks: audioTracks, currentIndex: audioIndex),
                                        resolvedURLs: resolvedURLs, restoredBaseQueue: restoredBaseQueue)
                guard requestGeneration == playbackPreparationGeneration else { return }
                restoredQueueNeedsPreparation = false
                let keepsLibraryMixedRoute = preserveLibraryPlaybackContinuation
                    && libraryPlaybackContinuation != nil
                    && routeContainsVideo(tracks)
                mixedQueue = nextVideoIndex < tracks.count || keepsLibraryMixedRoute ? tracks : nil
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
                    let cacheActivityID = beginBackgroundActivity(
                        kind: .cache,
                        title: cmvLocalized("正在更新智慧快取"),
                        detail: cmvLocalized("預取接下來的歌曲")
                    )
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
                errorMessage = cmvLocalized("無法準備播放：%@", arguments: AppLanguage.localizedError(error))
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

    /// Generate only for visible library cards. Keep the source lease alive
    /// through AVFoundation's asynchronous frame request; never persist frames
    /// in the track database or trigger a library-wide thumbnail scan.
    func videoThumbnail(for track: Track, maximumPixelSize: Int, context: ModelContext) async -> CGImage? {
        guard track.mediaKind == .video, maximumPixelSize > 0 else { return nil }
        let cacheKey = "\(track.id.uuidString)-\(track.modifiedAt.timeIntervalSince1970)-\(maximumPixelSize)" as NSString
        if let cached = videoThumbnailCache.object(forKey: cacheKey) { return cached }
        do {
            let url: URL
            let lease: SecurityScopedResourceLease?
            if let cacheStore, let cachedURL = await cacheStore.cachedURL(trackID: track.id) {
                url = cachedURL
                lease = nil
            } else {
                guard track.availability == .available,
                      let source = try context.fetch(FetchDescriptor<MediaSourceRecord>())
                        .first(where: { $0.id == track.sourceID }) else { return nil }
                let root = try await resolve(source: source, context: context)
                lease = try await sourceAccess.lease(for: root)
                url = try Self.safeTrackURL(root: root, relativePath: track.relativePath)
            }
            defer { withExtendedLifetime(lease) {} }
            try Task.checkCancellation()
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maximumPixelSize, height: maximumPixelSize)
            let previewSeconds = track.duration.isFinite ? min(2, max(0, track.duration * 0.1)) : 0
            let previewTime = CMTime(seconds: previewSeconds, preferredTimescale: 600)
            let frame = try await generator.image(at: previewTime).image
            try Task.checkCancellation()
            videoThumbnailCache.setObject(frame, forKey: cacheKey, cost: frame.bytesPerRow * frame.height)
            return frame
        } catch {
            // Offline, unsupported, or inaccessible videos keep the film icon.
            return nil
        }
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
        let activityID = beginBackgroundActivity(
            kind: .scanning,
            title: cmvLocalized("正在索引「%@」", arguments: source.displayName),
            detail: cmvLocalized("準備讀取來源"),
            localizedTitleKey: "正在索引「%@」",
            localizedTitleArgument: source.displayName
        )
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
            updateBackgroundActivity(activityID, detail: cmvLocalized("正在整理既有曲目"))
            var existing = try await repository.scanSnapshots(sourceID: sourceID)
            if Set(existing.map(\.relativePath)).count != existing.count {
                _ = try await repository.repairDuplicateTracksByRelativePath(sourceIDs: [sourceID])
                existing = try await repository.scanSnapshots(sourceID: sourceID)
            }
            updateBackgroundActivity(
                activityID,
                detail: cmvLocalized("已整理 %lld 首，正在檢查檔案", arguments: Int64(existing.count))
            )
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
                                let elapsed = progress.currentFileElapsedSeconds.map {
                                    cmvLocalized(" · 已讀取 %.1f 秒", arguments: $0)
                                } ?? ""
                                return cmvLocalized(
                                    "已檢查 %lld 首 · 正在讀取 %@%@",
                                    arguments: Int64(progress.processed), $0, elapsed
                                )
                            } ?? cmvLocalized("已檢查 %lld 首", arguments: Int64(progress.processed))
                        )
                    }
                },
                onIssue: { [weak self] issue in
                    let shouldPresent = await batchState.registerIssue()
                    guard shouldPresent else { return }
                    await MainActor.run {
                        self?.errorMessage = cmvLocalized("掃描發現問題：%@", arguments: AppLanguage.localizedError(issue))
                    }
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
                errorMessage = cmvLocalized("索引已完成，但無法保存來源狀態：%@", arguments: error.localizedDescription)
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
                catch {
                    errorMessage = cmvLocalized("無法保存取消索引狀態：%@", arguments: error.localizedDescription)
                }
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
                    ? cmvLocalized("索引發現重複的檔案識別或路徑，已停止更新以保護歌單與評分；請檢查來源後重新索引。")
                    : cmvLocalized("索引失敗：%@", arguments: scanError.localizedDescription)
            } catch {
                let saveError = error
                source.bookmarkData = original.bookmarkData
                source.status = original.status
                source.lastSuccessfulScan = original.lastSuccessfulScan
                source.updatedAt = original.updatedAt
                errorMessage = cmvLocalized(
                    "來源錯誤：%@；且無法保存狀態：%@",
                    arguments: scanError.localizedDescription, saveError.localizedDescription
                )
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
                let message = cmvLocalized("無法讀取曲庫：%@", arguments: error.localizedDescription)
                errorMessage = message
                libraryReadError = message
                return []
            }
        }
        if normalizedQuery.isEmpty {
            do { return try await repository.tracks(matching: "", limit: safeLimit, offset: safeOffset, includeArtwork: includeArtwork) }
            catch {
                let message = cmvLocalized("無法讀取曲庫：%@", arguments: error.localizedDescription)
                errorMessage = message
                libraryReadError = message
                return []
            }
        }
        let candidates: [LibrarySearchCandidate]
        do { candidates = try await repository.searchCandidates(matching: normalizedQuery) }
        catch {
            let message = cmvLocalized("無法搜尋曲庫：%@", arguments: error.localizedDescription)
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
                let message = cmvLocalized("無法載入搜尋結果：%@", arguments: error.localizedDescription)
                errorMessage = message
                libraryReadError = message
                return []
            }
        }
        let pageIDs = ranked.dropFirst(safeOffset).prefix(safeLimit).compactMap { UUID(uuidString: $0.identifier) }
        do { return try await repository.tracks(ids: pageIDs, includeArtwork: includeArtwork) }
        catch {
            let message = cmvLocalized("無法載入搜尋結果：%@", arguments: error.localizedDescription)
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
            let message = cmvLocalized("無法整理曲庫目錄：%@", arguments: error.localizedDescription)
            errorMessage = message
            catalogReadError = message
            return []
        }
    }

    func trackIDs(matching query: String, context: ModelContext, sort: LibraryTrackSort = .title, ascending: Bool = true) async -> [UUID] {
        let repository = repository(for: context)
        do { return try await repository.trackIDs(matching: query, sort: sort, ascending: ascending) }
        catch {
            errorMessage = cmvLocalized("無法讀取曲目識別：%@", arguments: error.localizedDescription)
            return []
        }
    }

    func tracks(ids: [UUID], context: ModelContext, includeArtwork: Bool = true) async -> [Track] {
        let repository = repository(for: context)
        do { return try await repository.tracks(ids: ids, includeArtwork: includeArtwork) }
        catch {
            errorMessage = cmvLocalized("無法載入曲目：%@", arguments: error.localizedDescription)
            return []
        }
    }

    func catalogGroupTrackIDs(kind: LibraryCatalogKind, key: String, context: ModelContext) async -> [UUID] {
        do { return try await repository(for: context).catalogGroupTrackIDs(kind: kind, key: key) }
        catch {
            errorMessage = cmvLocalized("無法載入群組曲目：%@", arguments: error.localizedDescription)
            return []
        }
    }

    func excludeTracks(ids: Set<UUID>, context: ModelContext) async -> Bool {
        guard !ids.isEmpty else { return true }
        let activityID = beginBackgroundActivity(
            kind: .library,
            title: cmvLocalized("正在從 CMV 移出曲目"),
            detail: cmvLocalized("保留原始檔案 · %lld 首", arguments: Int64(ids.count))
        )
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
                    errorMessage = cmvLocalized(
                        "曲目已移出 CMV，但有 %lld 份離線副本清理失敗。請稍後重試。",
                        arguments: Int64(failedToUnpin)
                    )
                }
            } else {
                pinnedTrackIDs.subtract(ids)
            }
            return true
        } catch {
            errorMessage = cmvLocalized("無法從 CMV 移出曲目：%@", arguments: error.localizedDescription)
            return false
        }
    }

    func favoriteTracks(context: ModelContext, limit: Int = 200, offset: Int = 0) async -> [Track] {
        favoriteReadError = nil
        let repository = repository(for: context)
        do { return try await repository.favoriteTracks(limit: limit, offset: max(0, offset)) }
        catch {
            let message = cmvLocalized("無法讀取最愛歌曲：%@", arguments: error.localizedDescription)
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
                    errorMessage = cmvLocalized(
                        "「%@」沒有目前可播放的曲目。請檢查來源或重新加入音樂。",
                        arguments: playlist.name
                    )
                    return
                }
                play(tracks: playable.map(\.track), context: context)
                if playable.count < playlist.trackIDs.count {
                    errorMessage = cmvLocalized(
                        "已略過歌單中 %lld 首目前無法播放的曲目。",
                        arguments: Int64(playlist.trackIDs.count - playable.count)
                    )
                }
            }
            catch {
                errorMessage = cmvLocalized(
                    "無法播放「%@」：%@",
                    arguments: playlist.name, error.localizedDescription
                )
            }
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
        enqueuePlaybackTracks(tracks, playNext: false, context: context)
    }

    /// 插入目前曲目之後，保留既有 future queue 的相對順序。
    func playNext(_ tracks: [Track], context: ModelContext) {
        enqueuePlaybackTracks(tracks, playNext: true, context: context)
    }

    private func enqueuePlaybackTracks(_ tracks: [Track], playNext: Bool, context: ModelContext) {
        guard !tracks.isEmpty else { return }
        let currentDisplayQueue = queuePanelDisplayQueue
        guard currentTrackID != nil, !currentDisplayQueue.tracks.isEmpty else {
            // An empty queue is a paused queue seed, not a play request.  In
            // particular, Add to Up Next from an idle multi-selection must not
            // resolve source bookmarks or start the first selected track.  Put
            // the compact route in the engine so the existing Play/Next paths
            // can prepare it lazily when the user explicitly starts playback.
            queueMutationGeneration &+= 1
            playbackPreparationGeneration &+= 1
            stagedPlaybackQueue = nil
            smartPrefetchTask?.cancel()
            smartPrefetchTask = nil
            cancelLibraryPlaybackContinuation()
            playback.pause()

            let seededQueue = PlaybackQueue(tracks: tracks, currentIndex: 0)
            let hasVideo = routeContainsVideo(tracks)
            mixedQueue = hasVideo ? tracks : nil
            mixedQueueCurrentIndex = hasVideo ? 0 : nil
            mixedQueueSegmentStart = nil
            mixedQueueBaseOrder = hasVideo ? tracks : nil
            restoredQueueNeedsPreparation = true
            queueRestored = true
            activePlaybackContext = context
            playback.setQueue(seededQueue, baseQueue: seededQueue)
            markQueueChanged()
            return
        }
        let currentIndex = currentDisplayQueue.currentIndex
        var updated = currentDisplayQueue.tracks
        let insertion = playNext
            ? min(updated.count, currentIndex + 1)
            : updated.count
        updated.insert(contentsOf: tracks, at: insertion)
        queueMutationGeneration &+= 1
        let mutation = queueMutationGeneration
        let hasVideo = routeContainsVideo(updated)
        if hasVideo {
            stagedPlaybackQueue = nil
            if mixedMediaShuffleEnabled {
                let base = mixedQueueBaseOrder ?? currentDisplayQueue.tracks
                mixedQueueBaseOrder = mixedBaseOrder(
                    old: currentDisplayQueue,
                    updated: PlaybackQueue(tracks: updated, currentIndex: currentIndex),
                    base: base,
                    playNext: playNext
                )
            } else {
                mixedQueueBaseOrder = nil
            }
            mixedQueue = updated
            mixedQueueCurrentIndex = currentIndex + (insertion <= currentIndex ? tracks.count : 0)
            mixedQueueSegmentStart = videoURL == nil ? (mixedQueueSegmentStart ?? 0) : nil
        } else {
            stagedPlaybackQueue = PlaybackQueue(tracks: updated, currentIndex: currentIndex)
            mixedQueue = nil
            mixedQueueCurrentIndex = nil
            mixedQueueSegmentStart = nil
            mixedQueueBaseOrder = nil
        }
        activePlaybackContext = context
        if !hasVideo { markQueueChanged() }
        if videoURL != nil {
            stagedPlaybackQueue = nil
            let index = min(updated.count - 1, currentIndex + (insertion <= currentIndex ? tracks.count : 0))
            playback.setQueue(PlaybackQueue(tracks: updated, currentIndex: index))
            markQueueChanged()
            return
        }
        let anchor = playbackOccurrenceSignature()

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                var current = queuePanelDisplayQueue
                guard queueMutationGeneration == mutation,
                      current.tracks.map(\.id) == updated.map(\.id) else { return }
                let routeIndex = current.currentIndex
                var firstVideo = updated.indices.dropFirst(routeIndex + 1).first { index in
                    let track = updated[index]
                    return track.mediaKind == .video || ["mp4", "mov", "m4v"].contains(URL(fileURLWithPath: track.relativePath).pathExtension.lowercased())
                } ?? updated.count
                var audioFuture = Array(updated[(routeIndex + 1)..<firstVideo]).filter { $0.mediaKind == .audio }
                let sourceRecords = try context.fetch(FetchDescriptor<MediaSourceRecord>())
                let sourcesByID = Dictionary(uniqueKeysWithValues: sourceRecords.map { ($0.id, $0) })
                let cached = await cacheStore?.cachedURLs(trackIDs: audioFuture.map(\.id)) ?? [:]
                var urls = cached
                var roots: [UUID: URL] = [:]
                var leases: [SecurityScopedResourceLease] = []
                for track in audioFuture where urls[track.id] == nil {
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
                guard queueMutationGeneration == mutation,
                      activePlaybackContext === context,
                      videoURL == nil else { return }
                if let anchor,
                   let latestAnchor = playbackOccurrenceSignature(),
                   anchor.trackID != latestAnchor.trackID || anchor.ordinal != latestAnchor.ordinal {
                    guard let rebased = rebaseQueueToCurrent(current, after: routeIndex) else { return }
                    current = rebased
                    stagedPlaybackQueue = rebased
                    markQueueChanged()
                    let committedIndex = rebased.currentIndex
                    firstVideo = rebased.tracks.indices.dropFirst(committedIndex + 1).first { index in
                        let track = rebased.tracks[index]
                        return track.mediaKind == .video || ["mp4", "mov", "m4v"].contains(URL(fileURLWithPath: track.relativePath).pathExtension.lowercased())
                    } ?? rebased.tracks.count
                    audioFuture = Array(rebased.tracks[(committedIndex + 1)..<firstVideo]).filter { $0.mediaKind == .audio }
                }
                playbackAccessLeases.append(contentsOf: leases)
                playback.replaceFutureQueue(audioFuture, resolvedURLs: urls, playNext: playNext)
                guard queueMutationGeneration == mutation else { return }
                stagedPlaybackQueue = nil
                markQueueChanged()
            } catch {
                guard queueMutationGeneration == mutation else { return }
                stagedPlaybackQueue = nil
                errorMessage = cmvLocalized("無法更新接下來播放：%@", arguments: error.localizedDescription)
            }
        }
    }

    func movePlaybackQueueItem(from source: Int, to destination: Int, context: ModelContext) {
        let queue = queuePanelDisplayQueue
        guard queue.tracks.indices.contains(source), source > queue.currentIndex else { return }
        let boundary = min(max(queue.currentIndex + 1, destination), queue.tracks.count)
        let target = boundary > source ? boundary - 1 : boundary
        guard target != source else { return }
        mutateFutureQueue(context: context) { queue in
            var result = queue
            let boundary = min(max(queue.currentIndex + 1, destination), queue.tracks.count)
            let target = boundary > source ? boundary - 1 : boundary
            let item = result.tracks.remove(at: source)
            result.tracks.insert(item, at: target)
            return result
        }
    }

    func removePlaybackQueueItem(at index: Int, context: ModelContext) {
        let queue = queuePanelDisplayQueue
        guard queue.tracks.indices.contains(index), index > queue.currentIndex else { return }
        mutateFutureQueue(context: context) { queue in
            var result = queue
            result.tracks.remove(at: index)
            return result
        }
    }

    private func mutateFutureQueue(context: ModelContext, _ transform: @escaping (PlaybackQueue) -> PlaybackQueue) {
        let old = queuePanelDisplayQueue
        let updated = transform(old)
        queueMutationGeneration &+= 1
        let mutation = queueMutationGeneration
        if routeContainsVideo(updated.tracks) {
            stagedPlaybackQueue = nil
            if mixedMediaShuffleEnabled {
                let base = mixedQueueBaseOrder ?? old.tracks
                mixedQueueBaseOrder = mixedBaseOrder(old: old, updated: updated, base: base, playNext: false)
            } else {
                mixedQueueBaseOrder = nil
            }
            mixedQueue = updated.tracks
            mixedQueueCurrentIndex = updated.currentIndex
        } else {
            stagedPlaybackQueue = updated
            mixedQueue = nil
            mixedQueueCurrentIndex = nil
            mixedQueueSegmentStart = nil
        }
        activePlaybackContext = context
        if !routeContainsVideo(updated.tracks) { markQueueChanged() }
        guard videoURL == nil else {
            playback.setQueue(updated)
            markQueueChanged()
            return
        }
        let anchor = playbackOccurrenceSignature()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard queueMutationGeneration == mutation else { return }
                var route = queuePanelDisplayQueue
                var firstVideo = route.tracks.indices.dropFirst(route.currentIndex + 1).first { index in
                    let track = route.tracks[index]
                    return track.mediaKind == .video || ["mp4", "mov", "m4v"].contains(URL(fileURLWithPath: track.relativePath).pathExtension.lowercased())
                } ?? route.tracks.count
                var audioFuture = Array(route.tracks[(route.currentIndex + 1)..<firstVideo]).filter { $0.mediaKind == .audio }
                let sourceRecords = try context.fetch(FetchDescriptor<MediaSourceRecord>())
                let sourcesByID = Dictionary(uniqueKeysWithValues: sourceRecords.map { ($0.id, $0) })
                let cached = await cacheStore?.cachedURLs(trackIDs: audioFuture.map(\.id)) ?? [:]
                var urls = cached
                var roots: [UUID: URL] = [:]
                var leases: [SecurityScopedResourceLease] = []
                for track in audioFuture where urls[track.id] == nil {
                    guard let source = sourcesByID[track.sourceID] else { throw MediaSourceAccessError.accessDenied }
                    let root: URL
                    if let cachedRoot = roots[track.sourceID] {
                        root = cachedRoot
                    } else {
                        root = try await resolve(source: source, context: context)
                        roots[track.sourceID] = root
                        leases.append(try await sourceAccess.lease(for: root))
                    }
                    urls[track.id] = try Self.safeTrackURL(root: root, relativePath: track.relativePath)
                }
                guard queueMutationGeneration == mutation, videoURL == nil else { return }
                if let anchor,
                   let latestAnchor = playbackOccurrenceSignature(),
                   anchor.trackID != latestAnchor.trackID || anchor.ordinal != latestAnchor.ordinal {
                    guard let rebased = rebaseQueueToCurrent(route, after: route.currentIndex) else { return }
                    route = rebased
                    stagedPlaybackQueue = rebased
                    markQueueChanged()
                    firstVideo = rebased.tracks.indices.dropFirst(rebased.currentIndex + 1).first { index in
                        let track = rebased.tracks[index]
                        return track.mediaKind == .video || ["mp4", "mov", "m4v"].contains(URL(fileURLWithPath: track.relativePath).pathExtension.lowercased())
                    } ?? rebased.tracks.count
                    audioFuture = Array(rebased.tracks[(rebased.currentIndex + 1)..<firstVideo]).filter { $0.mediaKind == .audio }
                }
                playbackAccessLeases.append(contentsOf: leases)
                playback.replaceFutureQueue(audioFuture, resolvedURLs: urls)
                guard queueMutationGeneration == mutation else { return }
                stagedPlaybackQueue = nil
                markQueueChanged()
            } catch {
                guard queueMutationGeneration == mutation else { return }
                stagedPlaybackQueue = nil
                errorMessage = cmvLocalized("無法整理接下來播放：%@", arguments: error.localizedDescription)
            }
        }
    }

    func addPlaylistToPlaybackQueue(_ playlist: Playlist, context: ModelContext) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let activityID = beginBackgroundActivity(
                kind: .playback,
                title: cmvLocalized("正在加入接下來播放"),
                detail: playlist.name
            )
            defer { endBackgroundActivity(activityID) }
            do {
                let tracks = try await playablePlaylistEntries(playlist, context: context).map(\.track)
                guard !tracks.isEmpty else {
                    errorMessage = cmvLocalized(
                        "「%@」沒有目前可播放的曲目。請檢查來源或重新加入音樂。",
                        arguments: playlist.name
                    )
                    return
                }
                addToPlaybackQueue(tracks, context: context)
                if tracks.count < playlist.trackIDs.count {
                    errorMessage = cmvLocalized(
                        "已略過歌單中 %lld 首目前無法播放的曲目。",
                        arguments: Int64(playlist.trackIDs.count - tracks.count)
                    )
                }
            } catch {
                errorMessage = cmvLocalized(
                    "無法將「%@」加入佇列：%@",
                    arguments: playlist.name, error.localizedDescription
                )
            }
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
        }, verifyContent: true)
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
        queueMutationGeneration &+= 1
        stagedPlaybackQueue = nil
        restoredQueueNeedsPreparation = false
        smartPrefetchTask?.cancel()
        smartPrefetchTask = nil
        cancelLibraryPlaybackContinuation()
        mixedQueue = nil
        mixedQueueCurrentIndex = nil
        mixedQueueSegmentStart = nil
        mixedMediaShuffleEnabled = false
        mixedQueueBaseOrder = nil
        activePlaybackContext = nil
        if videoURL != nil { stopVideoPlayback() }
        else { playback.clearQueue(); playbackAccessLeases.removeAll() }
        markQueueChanged()
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
                    errorMessage = cmvLocalized("無法更新最愛：%@", arguments: error.localizedDescription)
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
                    errorMessage = cmvLocalized("無法更新評分：%@", arguments: error.localizedDescription)
                }
            }
            if ratingMutationGeneration[track.id] == generation { ratingMutationTasks[track.id] = nil }
        }
    }

    func rating(for track: Track) -> Int { ratingOverrides[track.id] ?? track.rating }
    func isFavorite(for track: Track) -> Bool { favoriteOverrides[track.id] ?? track.isFavorite }

    func refreshPinnedStatus(for tracks: [Track], verifyContent: Bool = false) async {
        guard let cacheStore else { return }
        let ids = tracks.map(\.id)
        let pinned = if verifyContent {
            await cacheStore.pinnedTrackIDs(in: ids)
        } else {
            await cacheStore.presentPinnedTrackIDs(in: ids)
        }
        pinnedTrackIDs.subtract(ids)
        pinnedTrackIDs.formUnion(pinned)
    }

    func selectTheme(_ theme: CMVThemeID) {
        let isFreeTheme = theme == .crimsonNebula || theme == .amberDawn
        guard theme == selectedTheme || isFreeTheme || requirePro(.additionalThemes) else { return }
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
        guard let cacheStore else {
            errorMessage = cmvLocalized("無法建立離線快取。")
            return
        }
        pendingPinTrackIDs.insert(track.id)
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { pendingPinTrackIDs.remove(track.id) }
            let activityID = beginBackgroundActivity(
                kind: .cache,
                title: pinnedTrackIDs.contains(track.id)
                    ? cmvLocalized("正在取消離線釘選")
                    : cmvLocalized("正在儲存離線內容"),
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
            } catch { errorMessage = cmvLocalized("離線內容處理失敗：%@", arguments: error.localizedDescription) }
        }
    }

    /// Pin selected library records one at a time so a large selection never
    /// starts thousands of file copies or materializes their artwork at once.
    func pinTracks(ids: [UUID], context: ModelContext) async -> BatchPinResult {
        guard batchPinProgress == nil else {
            return BatchPinResult(pinned: 0, alreadyPinned: 0, failed: 0, cancelled: false)
        }
        guard requirePro(.smartOfflineCache) else {
            return BatchPinResult(pinned: 0, alreadyPinned: 0, failed: 0, cancelled: false)
        }
        var seen = Set<UUID>()
        let uniqueIDs = ids.filter { seen.insert($0).inserted }
        guard !uniqueIDs.isEmpty else {
            return BatchPinResult(pinned: 0, alreadyPinned: 0, failed: 0, cancelled: false)
        }
        guard let cacheStore else {
            errorMessage = cmvLocalized("無法建立離線快取。")
            return BatchPinResult(pinned: 0, alreadyPinned: 0, failed: uniqueIDs.count, cancelled: false)
        }

        let activityID = beginBackgroundActivity(kind: .cache,
                                                 title: cmvLocalized("正在儲存離線內容"),
                                                 detail: "0/\(uniqueIDs.count)")
        batchPinProgress = (0, uniqueIDs.count)
        defer {
            batchPinProgress = nil
            endBackgroundActivity(activityID)
        }
        let repository = repository(for: context)
        let sources: [UUID: MediaSourceRecord]
        do {
            sources = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<MediaSourceRecord>())
                .map { ($0.id, $0) })
        } catch {
            errorMessage = cmvLocalized("離線內容處理失敗：%@", arguments: error.localizedDescription)
            return BatchPinResult(pinned: 0, alreadyPinned: 0, failed: uniqueIDs.count, cancelled: false)
        }

        var roots: [UUID: URL] = [:]
        var leases: [UUID: SecurityScopedResourceLease] = [:]
        var unavailableSources = Set<UUID>()
        var pinnedCount = 0
        var alreadyPinnedCount = 0
        var failedCount = 0
        var completed = 0
        for start in stride(from: 0, to: uniqueIDs.count, by: 64) {
            if Task.isCancelled || !proStore.hasPro { break }
            let chunk = Array(uniqueIDs[start..<min(start + 64, uniqueIDs.count)])
            // A batch promise means playable offline copies, not just files
            // with a sidecar. Recheck existing pins before counting them done.
            let verifiedPinned = await cacheStore.pinnedTrackIDs(in: chunk)
            pinnedTrackIDs.subtract(chunk)
            pinnedTrackIDs.formUnion(verifiedPinned)
            if Task.isCancelled || !proStore.hasPro { break }
            let tracks: [Track]
            do { tracks = try await repository.tracks(ids: chunk, includeArtwork: false) }
            catch {
                failedCount += chunk.count
                completed += chunk.count
                batchPinProgress = (completed, uniqueIDs.count)
                updateBackgroundActivity(activityID, detail: "\(completed)/\(uniqueIDs.count)")
                continue
            }
            failedCount += chunk.count - tracks.count
            completed += chunk.count - tracks.count
            for track in tracks {
                if Task.isCancelled || !proStore.hasPro { break }
                defer {
                    completed += 1
                    batchPinProgress = (completed, uniqueIDs.count)
                    updateBackgroundActivity(activityID, detail: "\(completed)/\(uniqueIDs.count)")
                }
                guard !pendingPinTrackIDs.contains(track.id) else {
                    failedCount += 1
                    continue
                }
                if pinnedTrackIDs.contains(track.id) {
                    alreadyPinnedCount += 1
                    continue
                }
                pendingPinTrackIDs.insert(track.id)
                defer { pendingPinTrackIDs.remove(track.id) }
                do {
                    guard !unavailableSources.contains(track.sourceID),
                          let source = sources[track.sourceID] else {
                        throw MediaSourceAccessError.accessDenied
                    }
                    let root: URL
                    if let cached = roots[track.sourceID] {
                        root = cached
                    } else {
                        do {
                            root = try await resolve(source: source, context: context)
                            leases[track.sourceID] = try await sourceAccess.lease(for: root)
                            roots[track.sourceID] = root
                        } catch {
                            unavailableSources.insert(track.sourceID)
                            throw error
                        }
                    }
                    let url = try Self.safeTrackURL(root: root, relativePath: track.relativePath)
                    try Task.checkCancellation()
                    _ = try await cacheStore.pin(trackID: track.id, sourceURL: url)
                    pinnedTrackIDs.insert(track.id)
                    pinnedCount += 1
                } catch is CancellationError {
                    if Task.isCancelled { break }
                    failedCount += 1
                } catch {
                    failedCount += 1
                }
            }
        }
        withExtendedLifetime(leases) {}
        let cancelled = Task.isCancelled || !proStore.hasPro
        if failedCount > 0 {
            errorMessage = cmvLocalized("離線內容處理失敗：%@", arguments: "\(failedCount)/\(uniqueIDs.count)")
        }
        return BatchPinResult(pinned: pinnedCount, alreadyPinned: alreadyPinnedCount,
                              failed: failedCount, cancelled: cancelled)
    }

    func updateMetadata(ids: [UUID], patch: TrackMetadataPatch, context: ModelContext) async -> Bool {
        guard !ids.isEmpty, patch.hasChanges else { return false }
        guard !metadataOperationInFlight else { return false }
        guard requirePro(.advancedLibrary) else { return false }
        metadataOperationInFlight = true
        let activityID = beginBackgroundActivity(kind: .library,
                                                 title: cmvLocalized("正在更新歌曲資訊"),
                                                 detail: "\(ids.count)")
        defer {
            metadataOperationInFlight = false
            endBackgroundActivity(activityID)
        }
        do {
            let receipt = try await repository(for: context).updateMetadataWithUndo(for: ids, with: patch)
            lastMetadataUndo = receipt.entries.isEmpty ? nil : receipt
            libraryRevision &+= 1
            return true
        } catch {
            errorMessage = cmvLocalized("無法更新歌曲資訊：%@", arguments: error.localizedDescription)
            return false
        }
    }

    /// One-step undo retains heterogeneous original fields and never overwrites a later edit.
    func undoLastMetadata(context: ModelContext) async {
        guard !metadataOperationInFlight, let receipt = lastMetadataUndo else { return }
        metadataOperationInFlight = true
        defer { metadataOperationInFlight = false }
        do {
            let result = try await repository(for: context).undoMetadata(receipt)
            lastMetadataUndo = nil
            if !result.restoredIDs.isEmpty { libraryRevision &+= 1 }
            if !result.conflictIDs.isEmpty {
                errorMessage = cmvLocalized("部分歌曲資訊已再次變更，未覆蓋後續修改。")
            }
        } catch {
            errorMessage = cmvLocalized("無法復原歌曲資訊：%@", arguments: error.localizedDescription)
        }
    }

    func playlists(context: ModelContext) async -> [Playlist] {
        playlistReadError = nil
        let repository = repository(for: context)
        do { return try await repository.playlists() }
        catch {
            let message = cmvLocalized("無法讀取歌單：%@", arguments: error.localizedDescription)
            errorMessage = message
            playlistReadError = message
            return []
        }
    }

    func playlistEntries(_ playlist: Playlist, context: ModelContext) async -> [PlaylistTrackEntry]? {
        do { return try await repository(for: context).playlistEntries(ids: playlist.trackIDs, includeArtwork: false) }
        catch {
            errorMessage = cmvLocalized(
                "無法讀取「%@」：%@",
                arguments: playlist.name, error.localizedDescription
            )
            return nil
        }
    }

    func removeTrack(_ trackID: UUID, from playlist: Playlist, context: ModelContext) async -> Bool {
        do {
            try await repository(for: context).removeTrack(trackID: trackID, fromPlaylist: playlist.id)
            playlistRevision &+= 1
            return true
        } catch {
            errorMessage = cmvLocalized(
                "無法從「%@」移除曲目：%@",
                arguments: playlist.name, error.localizedDescription
            )
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
            errorMessage = cmvLocalized(
                "無法清理「%@」：%@",
                arguments: playlist.name, error.localizedDescription
            )
            return nil
        }
    }

    func createPlaylist(context: ModelContext) async -> Playlist? {
        let repository = repository(for: context)
        do {
            let playlist = try await repository.createPlaylist(name: cmvLocalized("新歌單"))
            playlistRevision &+= 1
            return playlist
        } catch {
            errorMessage = cmvLocalized("無法建立歌單：%@", arguments: error.localizedDescription)
            return nil
        }
    }

    func renamePlaylist(_ playlist: Playlist, name: String, context: ModelContext) async {
        do { try await repository(for: context).renamePlaylist(id: playlist.id, name: name); playlistRevision &+= 1 }
        catch { errorMessage = cmvLocalized("無法重新命名歌單：%@", arguments: error.localizedDescription) }
    }
    func deletePlaylist(_ playlist: Playlist, context: ModelContext) async {
        do { try await repository(for: context).deletePlaylist(id: playlist.id); playlistRevision &+= 1 }
        catch { errorMessage = cmvLocalized("無法刪除歌單：%@", arguments: error.localizedDescription) }
    }
    func reorderPlaylist(id: UUID, trackIDs: [UUID], context: ModelContext) async -> Bool {
        do {
            try await repository(for: context).reorderPlaylist(id: id, trackIDs: trackIDs)
            playlistRevision &+= 1
            return true
        } catch {
            errorMessage = cmvLocalized("無法重新排序歌單：%@", arguments: AppLanguage.localizedError(error))
            return false
        }
    }
    func addTrack(_ track: Track, to playlist: Playlist, context: ModelContext) async -> Bool {
        do {
            try await repository(for: context).addTrack(trackID: track.id, toPlaylist: playlist.id)
            playlistRevision &+= 1
            return true
        } catch {
            errorMessage = cmvLocalized(
                "無法將「%@」加入「%@」：%@",
                arguments: track.title, playlist.name, error.localizedDescription
            )
            return false
        }
    }
    func addTracks(_ tracks: [Track], to playlist: Playlist, context: ModelContext) async -> Bool {
        guard !tracks.isEmpty else { return true }
        let activityID = beginBackgroundActivity(
            kind: .library,
            title: cmvLocalized("正在加入歌單"),
            detail: cmvLocalized("%lld 首 · %@", arguments: Int64(tracks.count), playlist.name)
        )
        defer { endBackgroundActivity(activityID) }
        do {
            try await repository(for: context).addTracks(trackIDs: tracks.map(\.id), toPlaylist: playlist.id)
            playlistRevision &+= 1
            return true
        } catch {
            errorMessage = cmvLocalized("無法加入歌單：%@", arguments: error.localizedDescription)
            return false
        }
    }

    func removeTracks(ids: [UUID], from playlist: Playlist, context: ModelContext) async -> Bool {
        guard !ids.isEmpty else { return true }
        guard requirePro(.advancedLibrary) else { return false }
        let activityID = beginBackgroundActivity(kind: .library,
                                                 title: cmvLocalized("正在整理歌單"),
                                                 detail: "\(ids.count)")
        defer { endBackgroundActivity(activityID) }
        do {
            try await repository(for: context).removeTracks(trackIDs: ids, fromPlaylist: playlist.id)
            playlistRevision &+= 1
            return true
        } catch {
            errorMessage = cmvLocalized("無法從歌單移除歌曲：%@", arguments: error.localizedDescription)
            return false
        }
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
            } catch { errorMessage = cmvLocalized("無法在 Finder 顯示檔案：%@", arguments: error.localizedDescription) }
        }
    }

    func moveToTrash(_ track: Track, context: ModelContext) async -> Bool {
        let activityID = beginBackgroundActivity(
            kind: .library,
            title: cmvLocalized("正在移至垃圾桶"),
            detail: track.title
        )
        defer { endBackgroundActivity(activityID) }
        let repository = repository(for: context)
        let playlistSnapshot: [UUID: [UUID]]
        do {
            let containingPlaylists = try await repository.playlists().filter { $0.trackIDs.contains(track.id) }
            playlistSnapshot = Dictionary(uniqueKeysWithValues: containingPlaylists.map { ($0.id, $0.trackIDs) })
        } catch {
            errorMessage = cmvLocalized(
                "無法讀取歌單狀態，已取消移至垃圾桶：%@",
                arguments: error.localizedDescription
            )
            return false
        }
        var trashRestoreFailed = false
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
                    trashRestoreFailed = true
                    errorMessage = cmvLocalized(
                        "移至垃圾桶失敗，且 CMV 資料回復也失敗：%@；%@",
                        arguments: trashError.localizedDescription, error.localizedDescription
                    )
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
                    errorMessage = cmvLocalized(
                        "檔案已移至垃圾桶，但離線副本清理失敗：%@",
                        arguments: error.localizedDescription
                    )
                }
            } else {
                pinnedTrackIDs.remove(track.id)
            }
            return true
        } catch {
            if !trashRestoreFailed {
                errorMessage = cmvLocalized(
                    "無法將「%@」移至垃圾桶：%@",
                    arguments: track.title, error.localizedDescription
                )
            }
            return false
        }
    }
    #endif

    func analyze(trackID: UUID, url: URL) async throws -> AnalysisProfile {
        guard requirePro(.smartDJ) else { throw ProOperationError.requiresPro }
        let activityID = beginBackgroundActivity(
            kind: .analysis,
            title: cmvLocalized("正在分析音訊"),
            detail: url.lastPathComponent
        )
        defer { endBackgroundActivity(activityID) }
        return try await analyzer.analyze(trackID: trackID, url: url)
    }
    func analyzeAndPersist(trackID: UUID, url: URL, context: ModelContext) async throws -> AnalysisProfile {
        guard requirePro(.smartDJ) else { throw ProOperationError.requiresPro }
        let activityID = beginBackgroundActivity(
            kind: .analysis,
            title: cmvLocalized("正在分析音訊"),
            detail: url.lastPathComponent
        )
        defer { endBackgroundActivity(activityID) }
        let profile = try await analyzer.analyze(trackID: trackID, url: url)
        try Task.checkCancellation()
        try await repository(for: context).setAnalysis(trackID: trackID, profile: profile)
        return profile
    }
    func analyzeTrack(_ track: Track, context: ModelContext) async throws -> AnalysisProfile {
        guard requirePro(.smartDJ) else { throw ProOperationError.requiresPro }
        guard track.mediaKind == .audio, track.availability == .available else {
            throw MediaSourceAccessError.accessDenied
        }
        let descriptor = FetchDescriptor<MediaSourceRecord>(predicate: #Predicate { source in
            source.id == track.sourceID
        })
        guard let source = try context.fetch(descriptor).first else {
            throw MediaSourceAccessError.accessDenied
        }
        let root = try await resolve(source: source, context: context)
        let lease = try await sourceAccess.lease(for: root)
        let url = try Self.safeTrackURL(root: root, relativePath: track.relativePath)
        try Task.checkCancellation()
        let profile = try await analyzeAndPersist(trackID: track.id, url: url, context: context)
        withExtendedLifetime(lease) {}
        return profile
    }
    func makeSmartQueue(tracks: [Track], profiles: [UUID: AnalysisProfile],
                        history: [UUID: ListeningSignal], limit: Int = 25) async throws -> [DJSelection] {
        guard requirePro(.smartDJ) else { throw ProOperationError.requiresPro }
        let activityID = beginBackgroundActivity(kind: .analysis, title: cmvLocalized("智慧 DJ 正在選歌"))
        defer { endBackgroundActivity(activityID) }
        return try await smartDJ.makeQueue(from: tracks, profiles: profiles, history: history, limit: limit)
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
        case .nowPlaying: cmvLocalized("現在收聽")
        case .queue: cmvLocalized("接下來播放")
        case .songs: cmvLocalized("曲庫")
        case .albums: cmvLocalized("專輯")
        case .artists: cmvLocalized("歌手")
        case .playlists: cmvLocalized("我的歌單")
        case .favorites: cmvLocalized("最愛")
        case .settings: cmvLocalized("設定")
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
    var errorDescription: String? { cmvLocalized("本機聲學分析與 Smart DJ 需要 CMV Pro。") }
}
