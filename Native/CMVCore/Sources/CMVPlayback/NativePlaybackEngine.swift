import Foundation
import AVFoundation
import MediaPlayer
import Combine
import AudioToolbox
import Darwin
import CMVDomain

private actor AudioFileOpener {
    func open(_ urlsByIndex: [Int: URL]) throws -> [Int: AVAudioFile] {
        var files: [Int: AVAudioFile] = [:]
        files.reserveCapacity(urlsByIndex.count)
        for (index, url) in urlsByIndex {
            files[index] = try AVAudioFile(forReading: url)
        }
        return files
    }

    func open(_ url: URL) throws -> AVAudioFile {
        try AVAudioFile(forReading: url)
    }
}

public struct PlaybackTimelineTrack: Equatable, Sendable {
    public var sampleRateHz: UInt32
    public var totalFrames: UInt64
    public var startFrame: UInt64
    public var replayGainDB: Double?
    public var peak: Double?

    public init(sampleRateHz: UInt32, totalFrames: UInt64, startFrame: UInt64,
                replayGainDB: Double?, peak: Double? = nil) {
        self.sampleRateHz = sampleRateHz
        self.totalFrames = totalFrames
        self.startFrame = startFrame
        self.replayGainDB = replayGainDB
        self.peak = peak
    }
}

public struct PlaybackSchedulePlan: Equatable, Sendable {
    public var currentStartFrame: UInt64
    public var currentFrameCount: UInt64
    public var nextStartEngineFrame: UInt64
    public var currentGainLinear: Double
    public var nextGainLinear: Double

    public init(currentStartFrame: UInt64, currentFrameCount: UInt64,
                nextStartEngineFrame: UInt64, currentGainLinear: Double,
                nextGainLinear: Double) {
        self.currentStartFrame = currentStartFrame
        self.currentFrameCount = currentFrameCount
        self.nextStartEngineFrame = nextStartEngineFrame
        self.currentGainLinear = currentGainLinear
        self.nextGainLinear = nextGainLinear
    }
}

public typealias PlaybackPairPlanner = @Sendable (
    _ engineSampleRateHz: UInt32,
    _ current: PlaybackTimelineTrack,
    _ next: PlaybackTimelineTrack
) throws -> PlaybackSchedulePlan

public enum NativePlaybackError: LocalizedError {
    case unresolvedTrack
    case invalidAudioFormat
    case unsupportedFrameCount

    public var errorDescription: String? {
        switch self {
        case .unresolvedTrack: "找不到歌曲檔案，請重新連接音樂來源。"
        case .invalidAudioFormat: "歌曲的取樣格式無法播放。"
        case .unsupportedFrameCount: "歌曲長度超出目前播放管線可處理的範圍。"
        }
    }
}

@MainActor
public final class NativePlaybackEngine: NSObject, ObservableObject, PlaybackEngine {
    @Published public private(set) var queue = PlaybackQueue()
    @Published public private(set) var isPlaying = false
    @Published public private(set) var elapsed: TimeInterval = 0
    @Published public private(set) var outputVolume: Float = 1
    public private(set) var outputLevel: Float = 0
    @Published public private(set) var isShuffleEnabled = false
    @Published public private(set) var isRepeatEnabled = false
    @Published public private(set) var sleepTimerEndDate: Date?
    public var requiresTimelineReschedule: Bool { timelineNeedsReschedule }
    public var onCurrentTrackChanged: ((Track?) -> Void)?
    public var onQueueChanged: (() -> Void)?
    public var onQueueFinished: (() -> Void)?
    public var onOutputLevelChanged: ((Float) -> Void)?
    public var onPlaybackStateChanged: ((Bool) -> Void)?
    public var onElapsedChanged: ((TimeInterval) -> Void)?
    public var onPlaybackError: ((Error) -> Void)?
    public var onRemotePlayRequested: (() -> Void)?
    public var onRemotePauseRequested: (() -> Void)?
    public var onRemoteNextRequested: (() -> Void)?
    public var onRemotePreviousRequested: (() -> Void)?
    public var onRemoteSeekRequested: ((TimeInterval) -> Void)?
    public var onSleepTimerElapsed: (() -> Void)?

    private let engine = AVAudioEngine()
    private let firstNode = AVAudioPlayerNode()
    private let secondNode = AVAudioPlayerNode()
    private let transitionMixer = AVAudioMixerNode()
    private let equalizer = AVAudioUnitEQ(numberOfBands: 10)
    private let limiter = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_PeakLimiter,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    ))
    private let planner: PlaybackPairPlanner
    private let fileOpener = AudioFileOpener()
    private var resolvedURLs: [UUID: URL] = [:]
    private var scheduledFiles: [Int: AVAudioFile] = [:]
    private var scheduledEngineStartFrames: [Int: UInt64] = [:]
    private var activeNodeIsFirst = true
    private var scheduleGeneration = 0
    private var loadGeneration = 0
    private var timelineStarted = false
    private var timelineNeedsReschedule = false
    private var queueReachedEnd = false
    private var currentTrackStartEngineFrame: UInt64 = 0
    private var currentSourceStartSeconds: TimeInterval = 0
    private var engineSampleRate: Double = 48_000
    nonisolated(unsafe) private var progressTimer: AnyCancellable?
    nonisolated(unsafe) private var sleepTimerTask: Task<Void, Never>?
    nonisolated(unsafe) private var notificationTokens: [NSObjectProtocol] = []
    nonisolated(unsafe) private var remoteCommandTokens: [(MPRemoteCommand, Any)] = []
    #if os(iOS)
    private var wasPlayingBeforeInterruption = false
    #endif

    private var activeNode: AVAudioPlayerNode { activeNodeIsFirst ? firstNode : secondNode }
    private var standbyNode: AVAudioPlayerNode { activeNodeIsFirst ? secondNode : firstNode }

    public override convenience init() {
        self.init(planner: NativePlaybackEngine.fallbackPlanner)
    }

    public init(planner: @escaping PlaybackPairPlanner) {
        self.planner = planner
        super.init()
        engine.attach(firstNode)
        engine.attach(secondNode)
        engine.attach(transitionMixer)
        engine.attach(equalizer)
        engine.attach(limiter)
        engine.connect(firstNode, to: transitionMixer, format: nil)
        engine.connect(secondNode, to: transitionMixer, format: nil)
        engine.connect(transitionMixer, to: equalizer, format: nil)
        engine.connect(equalizer, to: limiter, format: nil)
        engine.connect(limiter, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = outputVolume
        installOutputMeter()
        configureRemoteCommands()
        configureAudioNotifications()
        startProgressUpdates()
    }

    deinit {
        sleepTimerTask?.cancel()
        progressTimer?.cancel()
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
        for (command, token) in remoteCommandTokens {
            command.removeTarget(token)
        }
    }

    public func load(_ queue: PlaybackQueue, resolvedURLs: [UUID: URL]) async throws {
        loadGeneration &+= 1
        let requestedLoadGeneration = loadGeneration
        let candidateQueue = shuffledQueue(queue)
        let preparedFiles = try await openInitialFiles(for: candidateQueue, resolvedURLs: resolvedURLs)
        try Task.checkCancellation()
        guard requestedLoadGeneration == loadGeneration else { throw CancellationError() }

        let oldQueue = self.queue
        let oldResolvedURLs = self.resolvedURLs
        let oldPreparedFiles = scheduledFiles
        let oldElapsed = elapsed
        let oldWasPlaying = isPlaying
        let oldSourceFrame = oldPreparedFiles[oldQueue.currentIndex]
            .flatMap { boundedSourceFrame(for: oldElapsed, file: $0) } ?? 0

        do {
            try prepareTimeline(sourceStartFrame: 0,
                                for: candidateQueue,
                                resolvedURLs: resolvedURLs,
                                preparedFiles: preparedFiles)
        } catch {
            let primaryError = error
            self.resolvedURLs = oldResolvedURLs
            restoreTimeline(
                queue: oldQueue,
                sourceStartFrame: oldSourceFrame,
                elapsed: oldElapsed,
                preparedFiles: oldPreparedFiles,
                resume: oldWasPlaying
            )
            throw primaryError
        }

        self.queue = candidateQueue
        self.resolvedURLs = resolvedURLs
        publishElapsed(0)
        publishPlaybackState(false)
        publishOutputLevel(0)
        onCurrentTrackChanged?(self.queue.current)
        updateNowPlaying()
    }

    public func setQueue(_ queue: PlaybackQueue) {
        self.queue = queue
        onCurrentTrackChanged?(self.queue.current)
        updateNowPlaying()
    }

    /// Extend the active audio timeline without restarting the current song.
    public func appendToQueue(_ tracks: [Track], resolvedURLs additions: [UUID: URL]) {
        guard !tracks.isEmpty else { return }
        let oldCount = queue.tracks.count
        queue.tracks.append(contentsOf: tracks)
        resolvedURLs.merge(additions) { _, latest in latest }
        if queueReachedEnd {
            // The old last song has already completed. The newly appended song
            // is the next current item; play() prepares it without replaying
            // the completed track.
            queue.currentIndex = oldCount
            queueReachedEnd = false
            publishElapsed(0)
            onCurrentTrackChanged?(queue.current)
        } else if !timelineNeedsReschedule && queue.currentIndex == oldCount - 1 && scheduledFiles[oldCount] == nil {
            scheduleFollowingTrack()
        }
        onQueueChanged?()
        updateNowPlaying()
    }

    public func updateExternalNowPlaying(isPlaying: Bool, elapsed: TimeInterval, duration: TimeInterval) {
        guard let track = queue.current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: max(duration, track.duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(0, elapsed),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }

    public func play() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
        try session.setActive(true)
        #endif
        if timelineNeedsReschedule {
            do {
                try prepareTimeline(sourceStartFrame: 0)
                timelineNeedsReschedule = false
            } catch {
                timelineNeedsReschedule = true
                throw error
            }
        }
        if !engine.isRunning { try engine.start() }
        if timelineStarted {
            firstNode.play()
            secondNode.play()
        } else {
            let start = AVAudioTime(hostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.05))
            firstNode.play(at: start)
            secondNode.play(at: start)
            timelineStarted = true
        }
        publishPlaybackState(true)
        updateNowPlaying()
    }

    public func pause() {
        updateElapsed()
        firstNode.pause()
        secondNode.pause()
        publishPlaybackState(false)
        publishOutputLevel(0)
        updateNowPlaying()
    }

    public func setVolume(_ value: Float) {
        guard value.isFinite else { return }
        outputVolume = min(1, max(0, value))
        engine.mainMixerNode.outputVolume = outputVolume
    }

    public func setSleepTimer(minutes: Int) {
        sleepTimerTask?.cancel()
        guard minutes > 0 else {
            sleepTimerEndDate = nil
            sleepTimerTask = nil
            return
        }
        let seconds = Double(minutes) * 60
        let nanosecondsValue = seconds * 1_000_000_000
        guard seconds.isFinite, seconds > 0,
              nanosecondsValue.isFinite,
              nanosecondsValue <= Double(UInt64.max) else {
            sleepTimerEndDate = nil
            sleepTimerTask = nil
            return
        }
        let nanoseconds = UInt64(nanosecondsValue.rounded(.down))
        sleepTimerEndDate = Date().addingTimeInterval(seconds)
        sleepTimerTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            if let callback = self.onSleepTimerElapsed { callback() } else { self.pause() }
            self.sleepTimerEndDate = nil
            self.sleepTimerTask = nil
        }
    }

    public func cancelSleepTimer() { setSleepTimer(minutes: 0) }
    public func toggleShuffle() { isShuffleEnabled.toggle() }
    public func toggleRepeat() { isRepeatEnabled.toggle() }

    public func clearQueue() {
        firstNode.stop()
        secondNode.stop()
        scheduleGeneration &+= 1
        loadGeneration &+= 1
        queue = PlaybackQueue()
        onCurrentTrackChanged?(nil)
        resolvedURLs.removeAll(keepingCapacity: true)
        scheduledFiles.removeAll(keepingCapacity: true)
        scheduledEngineStartFrames.removeAll(keepingCapacity: true)
        timelineStarted = false
        timelineNeedsReschedule = false
        queueReachedEnd = false
        publishPlaybackState(false)
        publishElapsed(0)
        publishOutputLevel(0)
        updateNowPlaying()
    }

    public func seek(to seconds: TimeInterval) {
        guard let file = scheduledFiles[queue.currentIndex],
              let targetFrame = boundedSourceFrame(for: seconds, file: file) else { return }
        let resume = isPlaying
        let oldElapsed = elapsed
        let oldQueue = queue
        let oldFiles = scheduledFiles
        let oldFrame = boundedSourceFrame(for: oldElapsed, file: file) ?? 0
        do {
            try prepareTimeline(sourceStartFrame: targetFrame)
            let actualSeconds = Double(targetFrame) / file.processingFormat.sampleRate
            publishElapsed(actualSeconds)
            if resume { try play() }
        } catch {
            let primaryError = error
            restoreTimeline(
                queue: oldQueue,
                sourceStartFrame: oldFrame,
                elapsed: oldElapsed,
                preparedFiles: oldFiles,
                resume: resume
            )
            onPlaybackError?(primaryError)
        }
    }

    public func skipForward() throws {
        guard queue.currentIndex + 1 < queue.tracks.count || isRepeatEnabled else { return }
        var candidate = queue
        if candidate.currentIndex + 1 >= candidate.tracks.count {
            candidate.currentIndex = 0
        } else {
            candidate = shuffledQueue(candidate)
            candidate.currentIndex += 1
        }
        try transition(to: candidate)
    }

    public func skipBackward() throws {
        if elapsed > 3 {
            seek(to: 0)
            return
        }
        guard queue.currentIndex > 0 else {
            seek(to: 0)
            return
        }
        var candidate = queue
        candidate.currentIndex -= 1
        try transition(to: candidate)
    }

    private func transition(to candidateQueue: PlaybackQueue) throws {
        let resume = isPlaying
        let oldQueue = queue
        let oldElapsed = elapsed
        let oldFiles = scheduledFiles
        let reusableFiles = Self.reusablePreparedFiles(oldFiles, from: oldQueue, for: candidateQueue)
        let oldFrame = scheduledFiles[oldQueue.currentIndex]
            .flatMap { boundedSourceFrame(for: oldElapsed, file: $0) } ?? 0

        do {
            try prepareTimeline(
                sourceStartFrame: 0,
                for: candidateQueue,
                resolvedURLs: resolvedURLs,
                preparedFiles: reusableFiles
            )
            queue = candidateQueue
            publishElapsed(0)
            onCurrentTrackChanged?(queue.current)
            if resume { try play() } else { publishPlaybackState(false) }
            updateNowPlaying()
        } catch {
            let primaryError = error
            restoreTimeline(
                queue: oldQueue,
                sourceStartFrame: oldFrame,
                elapsed: oldElapsed,
                preparedFiles: oldFiles,
                resume: resume
            )
            throw primaryError
        }
    }

    // Scheduled files are keyed by queue position. Shuffle can put a different
    // track at the same position, so only reuse files whose track ID still fits.
    static func reusablePreparedFiles(
        _ files: [Int: AVAudioFile], from oldQueue: PlaybackQueue, for candidateQueue: PlaybackQueue
    ) -> [Int: AVAudioFile] {
        files.filter { index, _ in
            oldQueue.tracks.indices.contains(index) &&
            candidateQueue.tracks.indices.contains(index) &&
            oldQueue.tracks[index].id == candidateQueue.tracks[index].id
        }
    }

    private func restoreTimeline(
        queue oldQueue: PlaybackQueue,
        sourceStartFrame: AVAudioFramePosition,
        elapsed oldElapsed: TimeInterval,
        preparedFiles: [Int: AVAudioFile],
        resume: Bool
    ) {
        self.queue = oldQueue
        publishPlaybackState(false)
        do {
            try prepareTimeline(
                sourceStartFrame: sourceStartFrame,
                for: oldQueue,
                resolvedURLs: resolvedURLs,
                preparedFiles: preparedFiles
            )
            self.queue = oldQueue
            publishElapsed(oldElapsed)
            onCurrentTrackChanged?(oldQueue.current)
            if resume { try play() }
            updateNowPlaying()
        } catch {
            let restoreError = error
            firstNode.stop()
            secondNode.stop()
            scheduleGeneration &+= 1
            self.queue = PlaybackQueue()
            scheduledFiles.removeAll(keepingCapacity: true)
            scheduledEngineStartFrames.removeAll(keepingCapacity: true)
            timelineStarted = false
            timelineNeedsReschedule = false
            queueReachedEnd = false
            publishPlaybackState(false)
            publishElapsed(0)
            publishOutputLevel(0)
            onCurrentTrackChanged?(nil)
            updateNowPlaying()
            onPlaybackError?(restoreError)
        }
    }

    private func boundedSourceFrame(for seconds: TimeInterval, file: AVAudioFile) -> AVAudioFramePosition? {
        let rate = file.processingFormat.sampleRate
        guard seconds.isFinite, rate.isFinite, rate > 0, file.length > 0 else { return nil }
        let raw = max(0, seconds) * rate
        guard raw.isFinite else { return nil }
        let maximum = file.length - 1
        if raw >= Double(maximum) { return maximum }
        return AVAudioFramePosition(raw.rounded(.down))
    }

    public func setEQ(enabled: Bool, gains: [Float]) {
        equalizer.bypass = !enabled
        for (index, gain) in gains.prefix(equalizer.bands.count).enumerated() where gain.isFinite {
            equalizer.bands[index].filterType = .parametric
            equalizer.bands[index].frequency = 32 * pow(2, Float(index))
            equalizer.bands[index].bandwidth = 1
            equalizer.bands[index].gain = min(12, max(-12, gain))
            equalizer.bands[index].bypass = false
        }
    }

    private func installOutputMeter() {
        transitionMixer.installTap(
            onBus: 0,
            bufferSize: 1_024,
            format: nil,
            block: Self.makeOutputMeterHandler(for: self)
        )
    }

    nonisolated private static func makeOutputMeterHandler(
        for engine: NativePlaybackEngine
    ) -> AVAudioNodeTapBlock {
        { [weak engine] buffer, _ in
            guard let normalized = normalizedOutputLevel(from: buffer) else { return }
            Task { @MainActor [weak engine] in
                guard let engine, engine.isPlaying else { return }
                engine.publishOutputLevel(normalized)
            }
        }
    }

    nonisolated private static func normalizedOutputLevel(from buffer: AVAudioPCMBuffer) -> Float? {
        guard let channels = buffer.floatChannelData else { return nil }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else { return nil }

        var sumOfSquares: Float = 0
        for channel in 0..<channelCount {
            let samples = channels[channel]
            for frame in 0..<frameCount {
                let sample = samples[frame]
                guard sample.isFinite else { continue }
                sumOfSquares += sample * sample
            }
        }
        guard sumOfSquares.isFinite else { return 1 }
        let rms = sqrt(sumOfSquares / Float(frameCount * channelCount))
        let decibels = 20 * log10(max(rms, 0.000_001))
        return min(1, max(0, (decibels + 60) / 60))
    }

    private func publishOutputLevel(_ value: Float) {
        guard value.isFinite else { return }
        let clamped = min(1, max(0, value))
        outputLevel = clamped
        onOutputLevelChanged?(clamped)
    }

    private func publishPlaybackState(_ value: Bool) {
        guard isPlaying != value else { return }
        isPlaying = value
        onPlaybackStateChanged?(value)
    }

    private func publishElapsed(_ value: TimeInterval) {
        guard value.isFinite else { return }
        let clamped = max(0, value)
        guard elapsed != clamped else { return }
        elapsed = clamped
        onElapsedChanged?(clamped)
    }

    private func prepareTimeline(sourceStartFrame: AVAudioFramePosition) throws {
        let preparedFiles = scheduledFiles
        try prepareTimeline(sourceStartFrame: sourceStartFrame,
                            for: queue,
                            resolvedURLs: resolvedURLs,
                            preparedFiles: preparedFiles)
    }

    private func prepareTimeline(sourceStartFrame: AVAudioFramePosition,
                                 for candidateQueue: PlaybackQueue,
                                 resolvedURLs candidateURLs: [UUID: URL],
                                 preparedFiles: [Int: AVAudioFile] = [:]) throws {
        firstNode.stop()
        secondNode.stop()
        scheduleGeneration &+= 1
        timelineStarted = false
        timelineNeedsReschedule = false
        queueReachedEnd = false
        activeNodeIsFirst = true
        currentTrackStartEngineFrame = 0
        scheduledFiles.removeAll(keepingCapacity: true)
        scheduledEngineStartFrames.removeAll(keepingCapacity: true)

        guard let currentTrack = candidateQueue.current,
              let currentURL = candidateURLs[currentTrack.id] else {
            throw NativePlaybackError.unresolvedTrack
        }
        let currentFile = try preparedFiles[candidateQueue.currentIndex] ?? AVAudioFile(forReading: currentURL)
        engineSampleRate = engine.mainMixerNode.outputFormat(forBus: 0).sampleRate
        if engineSampleRate <= 0 { engineSampleRate = currentFile.processingFormat.sampleRate }
        guard engineSampleRate > 0,
              engineSampleRate.isFinite,
              engineSampleRate <= Double(UInt32.max) else {
            throw NativePlaybackError.invalidAudioFormat
        }

        let currentInput = try timelineTrack(file: currentFile, sourceStartFrame: sourceStartFrame,
                                             replayGainDB: currentTrack.replayGainDB)
        currentSourceStartSeconds = Double(sourceStartFrame) / currentFile.processingFormat.sampleRate
        let engineRate = UInt32(engineSampleRate.rounded())

        if let next = try nextFileAndTrack(after: candidateQueue.currentIndex,
                                           in: candidateQueue,
                                           resolvedURLs: candidateURLs,
                                           preparedFiles: preparedFiles) {
            let nextInput = try timelineTrack(file: next.file, sourceStartFrame: 0,
                                              replayGainDB: next.track.replayGainDB)
            let plan = try planner(engineRate, currentInput, nextInput)
            try schedule(file: currentFile, on: firstNode,
                         sourceStartFrame: plan.currentStartFrame,
                         frameCount: plan.currentFrameCount, engineStartFrame: 0,
                         gain: plan.currentGainLinear, queueIndex: candidateQueue.currentIndex)
            scheduledFiles[candidateQueue.currentIndex] = currentFile
            try schedule(file: next.file, on: secondNode, sourceStartFrame: 0,
                         frameCount: nextInput.totalFrames,
                         engineStartFrame: plan.nextStartEngineFrame,
                         gain: plan.nextGainLinear, queueIndex: candidateQueue.currentIndex + 1)
            scheduledFiles[candidateQueue.currentIndex + 1] = next.file
        } else {
            let plan = try planner(engineRate, currentInput, currentInput)
            try schedule(file: currentFile, on: firstNode,
                         sourceStartFrame: plan.currentStartFrame,
                         frameCount: plan.currentFrameCount, engineStartFrame: 0,
                         gain: plan.currentGainLinear, queueIndex: candidateQueue.currentIndex)
            scheduledFiles[candidateQueue.currentIndex] = currentFile
        }
    }

    private func scheduleFollowingTrack() {
        let currentIndex = queue.currentIndex
        guard let currentFile = scheduledFiles[currentIndex] else { return }
        let nextIndex = currentIndex + 1
        guard queue.tracks.indices.contains(nextIndex),
              let nextURL = resolvedURLs[queue.tracks[nextIndex].id] else { return }
        let nextTrack = queue.tracks[nextIndex]
        let generation = scheduleGeneration
        Task { [weak self] in
            guard let self else { return }
            let nextFile: AVAudioFile
            do {
                nextFile = try await fileOpener.open(nextURL)
            } catch {
                guard generation == scheduleGeneration,
                      queue.currentIndex == currentIndex,
                      queue.tracks.indices.contains(nextIndex),
                      queue.tracks[nextIndex].id == nextTrack.id else { return }
                // A file can disappear after its path was resolved. Remove the
                // unplayable queue entry and try the following song instead of
                // leaving a permanent ghost at the next position.
                queue.tracks.remove(at: nextIndex)
                onQueueChanged?()
                onPlaybackError?(error)
                scheduleFollowingTrack()
                return
            }
            guard generation == scheduleGeneration,
                  queue.currentIndex == currentIndex else { return }
            do {
                try scheduleFollowingTrack(
                    currentFile: currentFile,
                    nextFile: nextFile,
                    nextTrack: nextTrack,
                    currentIndex: currentIndex
                )
            } catch {
                guard generation == scheduleGeneration,
                      queue.currentIndex == currentIndex else { return }
                onPlaybackError?(error)
            }
        }
    }

    private func scheduleFollowingTrack(
        currentFile: AVAudioFile,
        nextFile: AVAudioFile,
        nextTrack: Track,
        currentIndex: Int
    ) throws {
        let currentInput = try timelineTrack(file: currentFile, sourceStartFrame: 0,
                                             replayGainDB: queue.tracks[currentIndex].replayGainDB)
        let nextInput = try timelineTrack(file: nextFile, sourceStartFrame: 0,
                                          replayGainDB: nextTrack.replayGainDB)
        guard engineSampleRate > 0,
              engineSampleRate.isFinite,
              engineSampleRate <= Double(UInt32.max) else {
            throw NativePlaybackError.invalidAudioFormat
        }
        let plan = try planner(UInt32(engineSampleRate.rounded()), currentInput, nextInput)
        let (nextStart, overflow) = currentTrackStartEngineFrame.addingReportingOverflow(plan.nextStartEngineFrame)
        guard !overflow else { throw NativePlaybackError.unsupportedFrameCount }
        try schedule(file: nextFile, on: standbyNode, sourceStartFrame: 0,
                     frameCount: nextInput.totalFrames, engineStartFrame: nextStart,
                     gain: plan.nextGainLinear, queueIndex: currentIndex + 1)
        scheduledFiles[currentIndex + 1] = nextFile
    }

    private func schedule(file: AVAudioFile, on node: AVAudioPlayerNode,
                          sourceStartFrame: UInt64, frameCount: UInt64,
                          engineStartFrame: UInt64, gain: Double,
                          queueIndex: Int) throws {
        guard gain.isFinite,
              let start = AVAudioFramePosition(exactly: sourceStartFrame),
              let count = AVAudioFrameCount(exactly: frameCount),
              let engineStart = AVAudioFramePosition(exactly: engineStartFrame) else {
            throw NativePlaybackError.unsupportedFrameCount
        }
        node.volume = Float(min(4, max(0, gain)))
        let generation = scheduleGeneration
        node.scheduleSegment(
            file,
            startingFrame: start,
            frameCount: count,
            at: AVAudioTime(sampleTime: engineStart, atRate: engineSampleRate),
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleTrackFinished(queueIndex: queueIndex, generation: generation)
            }
        }
        scheduledEngineStartFrames[queueIndex] = engineStartFrame
    }

    private func handleTrackFinished(queueIndex: Int, generation: Int) {
        guard generation == scheduleGeneration, queue.currentIndex == queueIndex else { return }
        guard queueIndex + 1 < queue.tracks.count else {
            guard isRepeatEnabled else {
                publishPlaybackState(false)
                timelineStarted = false
                timelineNeedsReschedule = true
                queueReachedEnd = true
                publishElapsed(queue.current?.duration ?? elapsed)
                onQueueFinished?()
                updateNowPlaying()
                return
            }
            queue.currentIndex = 0
            onCurrentTrackChanged?(queue.current)
            publishElapsed(0)
            shuffleUpcomingTrackIfNeeded()
            let repeatGeneration = scheduleGeneration
            Task { [weak self] in
                guard let self else { return }
                do {
                    let preparedFiles = try await openInitialFiles(for: queue, resolvedURLs: resolvedURLs)
                    guard repeatGeneration == scheduleGeneration,
                          queue.currentIndex == 0 else { return }
                    try prepareTimeline(
                        sourceStartFrame: 0,
                        for: queue,
                        resolvedURLs: resolvedURLs,
                        preparedFiles: preparedFiles
                    )
                    try play()
                } catch {
                    guard repeatGeneration == scheduleGeneration else { return }
                    publishPlaybackState(false)
                    timelineNeedsReschedule = true
                    onPlaybackError?(error)
                }
            }
            updateNowPlaying()
            return
        }
        guard scheduledFiles[queueIndex + 1] != nil,
              scheduledEngineStartFrames[queueIndex + 1] != nil else {
            publishPlaybackState(false)
            timelineStarted = false
            timelineNeedsReschedule = true
            queueReachedEnd = true
            publishElapsed(queue.current?.duration ?? elapsed)
            onQueueFinished?()
            updateNowPlaying()
            return
        }
        queue.currentIndex += 1
        onCurrentTrackChanged?(queue.current)
        shuffleUpcomingTrackIfNeeded()
        activeNodeIsFirst.toggle()
        currentSourceStartSeconds = 0
        currentTrackStartEngineFrame = scheduledEngineStartFrames[queue.currentIndex] ?? 0
        scheduledFiles.removeValue(forKey: queueIndex)
        scheduledEngineStartFrames.removeValue(forKey: queueIndex)
        publishElapsed(0)
        scheduleFollowingTrack()
        updateNowPlaying()
    }

    private func nextFileAndTrack(after index: Int,
                                  in queue: PlaybackQueue,
                                  resolvedURLs: [UUID: URL],
                                  preparedFiles: [Int: AVAudioFile] = [:]) throws -> (file: AVAudioFile, track: Track)? {
        let nextIndex = index + 1
        guard queue.tracks.indices.contains(nextIndex) else { return nil }
        let track = queue.tracks[nextIndex]
        guard let url = resolvedURLs[track.id] else { throw NativePlaybackError.unresolvedTrack }
        return (try preparedFiles[nextIndex] ?? AVAudioFile(forReading: url), track)
    }

    private func openInitialFiles(
        for queue: PlaybackQueue,
        resolvedURLs: [UUID: URL]
    ) async throws -> [Int: AVAudioFile] {
        guard let current = queue.current,
              let currentURL = resolvedURLs[current.id] else {
            throw NativePlaybackError.unresolvedTrack
        }
        var urlsByIndex = [queue.currentIndex: currentURL]
        let nextIndex = queue.currentIndex + 1
        if queue.tracks.indices.contains(nextIndex) {
            guard let nextURL = resolvedURLs[queue.tracks[nextIndex].id] else {
                throw NativePlaybackError.unresolvedTrack
            }
            urlsByIndex[nextIndex] = nextURL
        }
        return try await fileOpener.open(urlsByIndex)
    }

    private func shuffleUpcomingTrackIfNeeded() { queue = shuffledQueue(queue) }

    private func shuffledQueue(_ input: PlaybackQueue) -> PlaybackQueue {
        var result = input
        guard isShuffleEnabled else { return result }
        let nextIndex = result.currentIndex + 1
        guard nextIndex < result.tracks.count else { return result }
        let selectedIndex = Int.random(in: nextIndex..<result.tracks.count)
        if selectedIndex != nextIndex { result.tracks.swapAt(nextIndex, selectedIndex) }
        return result
    }

    private func timelineTrack(file: AVAudioFile, sourceStartFrame: AVAudioFramePosition,
                               replayGainDB: Double?) throws -> PlaybackTimelineTrack {
        let rate = file.processingFormat.sampleRate
        guard rate > 0, rate.isFinite, rate <= Double(UInt32.max),
              file.length >= 0,
              sourceStartFrame >= 0,
              replayGainDB?.isFinite ?? true else {
            throw NativePlaybackError.invalidAudioFormat
        }
        return PlaybackTimelineTrack(sampleRateHz: UInt32(rate.rounded()),
                                     totalFrames: UInt64(file.length),
                                     startFrame: UInt64(sourceStartFrame),
                                     replayGainDB: replayGainDB)
    }

    private func startProgressUpdates() {
        progressTimer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateElapsed() }
    }

    private func updateElapsed() {
        guard isPlaying,
              engineSampleRate.isFinite, engineSampleRate > 0,
              let nodeTime = activeNode.lastRenderTime,
              let playerTime = activeNode.playerTime(forNodeTime: nodeTime) else { return }
        let rendered = max(0, playerTime.sampleTime)
        let duration = queue.current?.duration ?? .greatestFiniteMagnitude
        publishElapsed(min(duration, currentSourceStartSeconds + Double(rendered) / engineSampleRate))
        updateNowPlaying()
    }

    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        remoteCommandTokens.append((commands.playCommand, commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let callback = self.onRemotePlayRequested { callback() }
                else { do { try self.play() } catch { self.onPlaybackError?(error) } }
            }
            return .success
        }))
        remoteCommandTokens.append((commands.pauseCommand, commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let callback = self.onRemotePauseRequested { callback() } else { self.pause() }
            }
            return .success
        }))
        remoteCommandTokens.append((commands.nextTrackCommand, commands.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let callback = self.onRemoteNextRequested { callback() }
                else { do { try self.skipForward() } catch { self.onPlaybackError?(error) } }
            }
            return .success
        }))
        remoteCommandTokens.append((commands.previousTrackCommand, commands.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let callback = self.onRemotePreviousRequested { callback() }
                else { do { try self.skipBackward() } catch { self.onPlaybackError?(error) } }
            }
            return .success
        }))
        remoteCommandTokens.append((commands.changePlaybackPositionCommand, commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in
                guard let self else { return }
                if let callback = self.onRemoteSeekRequested { callback(event.positionTime) }
                else { self.seek(to: event.positionTime) }
            }
            return .success
        }))
    }

    private func configureAudioNotifications() {
        let center = NotificationCenter.default
        #if os(iOS)
        notificationTokens.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(), queue: .main
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in self?.handleInterruption(type: rawType, options: rawOptions) }
        })
        notificationTokens.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(), queue: .main
        ) { [weak self] notification in
            let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in self?.handleRouteChange(reason: rawReason) }
        })
        #endif
        notificationTokens.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.recoverAfterEngineChange() }
        })
    }

    #if os(iOS)
    private func handleInterruption(type rawType: UInt?, options rawOptions: UInt?) {
        guard let rawType,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            pause()
        case .ended:
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions ?? 0)
                .contains(.shouldResume)
            if wasPlayingBeforeInterruption && shouldResume {
                do { try play() } catch { onPlaybackError?(error) }
            }
            wasPlayingBeforeInterruption = false
        @unknown default: pause()
        }
    }

    private func handleRouteChange(reason rawReason: UInt?) {
        if rawReason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { pause() }
    }
    #endif

    private func recoverAfterEngineChange() {
        let resume = isPlaying
        let position = elapsed
        publishPlaybackState(false)
        seek(to: position)
        if resume && !isPlaying {
            do { try play() } catch { onPlaybackError?(error) }
        }
    }

    private func updateNowPlaying() {
        guard let track = queue.current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }

    private static let fallbackPlanner: PlaybackPairPlanner = { engineRate, current, next in
        guard engineRate > 0, current.sampleRateHz > 0, next.sampleRateHz > 0,
              current.startFrame <= current.totalFrames,
              current.replayGainDB?.isFinite ?? true,
              next.replayGainDB?.isFinite ?? true else {
            throw NativePlaybackError.invalidAudioFormat
        }
        let remaining = current.totalFrames - current.startFrame
        let scaled = Double(remaining) * Double(engineRate) / Double(current.sampleRateHz)
        let rounded = scaled.rounded()
        let twoTo64 = 18_446_744_073_709_551_616.0
        guard rounded.isFinite, rounded >= 0, rounded < twoTo64 else {
            throw NativePlaybackError.unsupportedFrameCount
        }
        let nextStart = UInt64(rounded)
        func gain(_ decibels: Double?) throws -> Double {
            let value = pow(10, (decibels ?? 0) / 20)
            guard value.isFinite, value >= 0 else { throw NativePlaybackError.invalidAudioFormat }
            return min(4, value)
        }
        return PlaybackSchedulePlan(currentStartFrame: current.startFrame,
                                    currentFrameCount: remaining,
                                    nextStartEngineFrame: nextStart,
                                    currentGainLinear: try gain(current.replayGainDB),
                                    nextGainLinear: try gain(next.replayGainDB))
    }
}
