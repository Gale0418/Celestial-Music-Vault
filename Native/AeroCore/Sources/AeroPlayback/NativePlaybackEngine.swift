import Foundation
import AVFoundation
import MediaPlayer
import Combine
import AudioToolbox
import Darwin
import AeroDomain

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
    @Published public private(set) var isShuffleEnabled = false
    @Published public private(set) var isRepeatEnabled = false
    @Published public private(set) var sleepTimerEndDate: Date?
    /// Lets the app shell observe queue advancement without reaching through
    /// a nested ObservableObject from SwiftUI rows.
    public var onCurrentTrackChanged: ((Track?) -> Void)?
    public var onQueueFinished: (() -> Void)?

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
    private var resolvedURLs: [UUID: URL] = [:]
    private var scheduledFiles: [Int: AVAudioFile] = [:]
    private var scheduledEngineStartFrames: [Int: UInt64] = [:]
    private var activeNodeIsFirst = true
    private var scheduleGeneration = 0
    private var timelineStarted = false
    private var currentTrackStartEngineFrame: UInt64 = 0
    private var currentSourceStartSeconds: TimeInterval = 0
    private var engineSampleRate: Double = 48_000
    private var progressTimer: AnyCancellable?
    private var sleepTimerTask: Task<Void, Never>?
    private var notificationTokens: [NSObjectProtocol] = []
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
        configureRemoteCommands()
        configureAudioNotifications()
        startProgressUpdates()
    }

    public func load(_ queue: PlaybackQueue, resolvedURLs: [UUID: URL]) throws {
        self.queue = queue
        self.resolvedURLs = resolvedURLs
        shuffleUpcomingTrackIfNeeded()
        elapsed = 0
        try prepareTimeline(sourceStartFrame: 0)
        onCurrentTrackChanged?(self.queue.current)
        updateNowPlaying()
    }

    /// 影片由 AVPlayer 解碼時仍共用同一個播放佇列，不啟動音訊 graph。
    public func setQueue(_ queue: PlaybackQueue) {
        self.queue = queue
        onCurrentTrackChanged?(self.queue.current)
        updateNowPlaying()
    }

    public func play() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
        try session.setActive(true)
        #endif
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
        isPlaying = true
        updateNowPlaying()
    }

    public func pause() {
        updateElapsed()
        firstNode.pause()
        secondNode.pause()
        isPlaying = false
        updateNowPlaying()
    }

    public func setVolume(_ value: Float) {
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
        let nanoseconds = UInt64(minutes) * 60 * 1_000_000_000
        sleepTimerEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimerTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            self.pause()
            self.sleepTimerEndDate = nil
            self.sleepTimerTask = nil
        }
    }

    public func cancelSleepTimer() {
        setSleepTimer(minutes: 0)
    }

    public func toggleShuffle() { isShuffleEnabled.toggle() }

    public func toggleRepeat() { isRepeatEnabled.toggle() }

    public func clearQueue() {
        firstNode.stop()
        secondNode.stop()
        queue = PlaybackQueue()
        onCurrentTrackChanged?(nil)
        resolvedURLs.removeAll(keepingCapacity: true)
        scheduledFiles.removeAll(keepingCapacity: true)
        scheduledEngineStartFrames.removeAll(keepingCapacity: true)
        timelineStarted = false
        isPlaying = false
        elapsed = 0
        updateNowPlaying()
    }

    public func seek(to seconds: TimeInterval) {
        guard let file = scheduledFiles[queue.currentIndex] else { return }
        let frame = AVAudioFramePosition(max(0, seconds) * file.processingFormat.sampleRate)
        guard frame >= 0, frame < file.length else { return }
        let resume = isPlaying
        do {
            try prepareTimeline(sourceStartFrame: frame)
            elapsed = seconds
            if resume { try play() }
        } catch {
            isPlaying = false
        }
    }

    public func skipForward() throws {
        guard queue.currentIndex + 1 < queue.tracks.count || isRepeatEnabled else { return }
        let resume = isPlaying
        if queue.currentIndex + 1 >= queue.tracks.count {
            queue.currentIndex = 0
        } else {
            shuffleUpcomingTrackIfNeeded()
            queue.currentIndex += 1
        }
        onCurrentTrackChanged?(queue.current)
        elapsed = 0
        try prepareTimeline(sourceStartFrame: 0)
        if resume { try play() }
        updateNowPlaying()
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
        let resume = isPlaying
        queue.currentIndex -= 1
        onCurrentTrackChanged?(queue.current)
        elapsed = 0
        try prepareTimeline(sourceStartFrame: 0)
        if resume { try play() }
        updateNowPlaying()
    }

    public func setEQ(enabled: Bool, gains: [Float]) {
        equalizer.bypass = !enabled
        for (index, gain) in gains.prefix(equalizer.bands.count).enumerated() {
            equalizer.bands[index].filterType = .parametric
            equalizer.bands[index].frequency = 32 * pow(2, Float(index))
            equalizer.bands[index].bandwidth = 1
            equalizer.bands[index].gain = min(12, max(-12, gain))
            equalizer.bands[index].bypass = false
        }
    }

    private func prepareTimeline(sourceStartFrame: AVAudioFramePosition) throws {
        firstNode.stop()
        secondNode.stop()
        scheduleGeneration += 1
        timelineStarted = false
        activeNodeIsFirst = true
        currentTrackStartEngineFrame = 0
        scheduledFiles.removeAll(keepingCapacity: true)
        scheduledEngineStartFrames.removeAll(keepingCapacity: true)

        guard let currentTrack = queue.current,
              let currentURL = resolvedURLs[currentTrack.id] else {
            throw NativePlaybackError.unresolvedTrack
        }
        let currentFile = try AVAudioFile(forReading: currentURL)
        scheduledFiles[queue.currentIndex] = currentFile
        engineSampleRate = engine.mainMixerNode.outputFormat(forBus: 0).sampleRate
        if engineSampleRate <= 0 { engineSampleRate = currentFile.processingFormat.sampleRate }
        guard engineSampleRate > 0 else { throw NativePlaybackError.invalidAudioFormat }

        let currentInput = try timelineTrack(file: currentFile, sourceStartFrame: sourceStartFrame,
                                             replayGainDB: currentTrack.replayGainDB)
        currentSourceStartSeconds = Double(sourceStartFrame) / currentFile.processingFormat.sampleRate

        if let next = try nextFileAndTrack(after: queue.currentIndex) {
            let nextInput = try timelineTrack(file: next.file, sourceStartFrame: 0,
                                              replayGainDB: next.track.replayGainDB)
            let plan = try planner(UInt32(engineSampleRate.rounded()), currentInput, nextInput)
            try schedule(file: currentFile, on: firstNode,
                         sourceStartFrame: plan.currentStartFrame,
                         frameCount: plan.currentFrameCount, engineStartFrame: 0,
                         gain: plan.currentGainLinear, queueIndex: queue.currentIndex)
            scheduledFiles[queue.currentIndex + 1] = next.file
            try schedule(file: next.file, on: secondNode, sourceStartFrame: 0,
                         frameCount: UInt64(next.file.length),
                         engineStartFrame: plan.nextStartEngineFrame,
                         gain: plan.nextGainLinear, queueIndex: queue.currentIndex + 1)
        } else {
            let plan = try planner(UInt32(engineSampleRate.rounded()), currentInput, currentInput)
            try schedule(file: currentFile, on: firstNode,
                         sourceStartFrame: plan.currentStartFrame,
                         frameCount: plan.currentFrameCount, engineStartFrame: 0,
                         gain: plan.currentGainLinear, queueIndex: queue.currentIndex)
        }
    }

    private func scheduleFollowingTrack() throws {
        let currentIndex = queue.currentIndex
        guard let currentFile = scheduledFiles[currentIndex],
              let next = try nextFileAndTrack(after: currentIndex) else { return }
        let currentInput = try timelineTrack(file: currentFile, sourceStartFrame: 0,
                                             replayGainDB: queue.tracks[currentIndex].replayGainDB)
        let nextInput = try timelineTrack(file: next.file, sourceStartFrame: 0,
                                          replayGainDB: next.track.replayGainDB)
        let plan = try planner(UInt32(engineSampleRate.rounded()), currentInput, nextInput)
        let nextStart = currentTrackStartEngineFrame + plan.nextStartEngineFrame
        scheduledFiles[currentIndex + 1] = next.file
        try schedule(file: next.file, on: standbyNode, sourceStartFrame: 0,
                     frameCount: UInt64(next.file.length), engineStartFrame: nextStart,
                     gain: plan.nextGainLinear, queueIndex: currentIndex + 1)
    }

    private func schedule(file: AVAudioFile, on node: AVAudioPlayerNode,
                          sourceStartFrame: UInt64, frameCount: UInt64,
                          engineStartFrame: UInt64, gain: Double,
                          queueIndex: Int) throws {
        guard let start = AVAudioFramePosition(exactly: sourceStartFrame),
              let count = AVAudioFrameCount(exactly: frameCount),
              let engineStart = AVAudioFramePosition(exactly: engineStartFrame) else {
            throw NativePlaybackError.unsupportedFrameCount
        }
        node.volume = Float(min(4, max(0, gain)))
        scheduledEngineStartFrames[queueIndex] = engineStartFrame
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
    }

    private func handleTrackFinished(queueIndex: Int, generation: Int) {
        guard generation == scheduleGeneration, queue.currentIndex == queueIndex else { return }
        guard queueIndex + 1 < queue.tracks.count else {
            guard isRepeatEnabled else {
                isPlaying = false
                elapsed = queue.current?.duration ?? elapsed
                onQueueFinished?()
                updateNowPlaying()
                return
            }
            queue.currentIndex = 0
            onCurrentTrackChanged?(queue.current)
            elapsed = 0
            shuffleUpcomingTrackIfNeeded()
            try? prepareTimeline(sourceStartFrame: 0)
            try? play()
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
        elapsed = 0
        try? scheduleFollowingTrack()
        updateNowPlaying()
    }

    private func nextFileAndTrack(after index: Int) throws -> (file: AVAudioFile, track: Track)? {
        let nextIndex = index + 1
        guard queue.tracks.indices.contains(nextIndex) else { return nil }
        let track = queue.tracks[nextIndex]
        guard let url = resolvedURLs[track.id] else { throw NativePlaybackError.unresolvedTrack }
        return (try AVAudioFile(forReading: url), track)
    }

    private func shuffleUpcomingTrackIfNeeded() {
        guard isShuffleEnabled else { return }
        let nextIndex = queue.currentIndex + 1
        guard nextIndex < queue.tracks.count else { return }
        let selectedIndex = Int.random(in: nextIndex..<queue.tracks.count)
        if selectedIndex != nextIndex {
            queue.tracks.swapAt(nextIndex, selectedIndex)
        }
    }

    private func timelineTrack(file: AVAudioFile, sourceStartFrame: AVAudioFramePosition,
                               replayGainDB: Double?) throws -> PlaybackTimelineTrack {
        let rate = file.processingFormat.sampleRate
        guard rate > 0, rate <= Double(UInt32.max), sourceStartFrame >= 0 else {
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
              let nodeTime = activeNode.lastRenderTime,
              let playerTime = activeNode.playerTime(forNodeTime: nodeTime) else { return }
        // `playerTime.sampleTime` is relative to the active player node.  The
        // queue's engine timeline is only used for scheduling the next node;
        // subtracting it here would pin every subsequent track at 0:00.
        let rendered = max(0, playerTime.sampleTime)
        let duration = queue.current?.duration ?? .greatestFiniteMagnitude
        elapsed = min(duration, currentSourceStartSeconds + Double(rendered) / engineSampleRate)
        updateNowPlaying()
    }

    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in try? self?.play() }; return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }; return .success
        }
        commands.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in try? self?.skipForward() }; return .success
        }
        commands.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in try? self?.skipBackward() }; return .success
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }; return .success
        }
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
            if wasPlayingBeforeInterruption && shouldResume { try? play() }
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
        isPlaying = false
        seek(to: position)
        if resume { try? play() }
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
              current.startFrame <= current.totalFrames else {
            throw NativePlaybackError.invalidAudioFormat
        }
        let remaining = current.totalFrames - current.startFrame
        let nextStart = UInt64((Double(remaining) * Double(engineRate) /
                                Double(current.sampleRateHz)).rounded())
        func gain(_ decibels: Double?) -> Double { min(4, pow(10, (decibels ?? 0) / 20)) }
        return PlaybackSchedulePlan(currentStartFrame: current.startFrame,
                                    currentFrameCount: remaining,
                                    nextStartEngineFrame: nextStart,
                                    currentGainLinear: gain(current.replayGainDB),
                                    nextGainLinear: gain(next.replayGainDB))
    }
}
