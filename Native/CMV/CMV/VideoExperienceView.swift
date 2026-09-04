import SwiftUI
import SwiftData
import AVKit
import Observation

enum VideoPresentationMode: String, CaseIterable, Identifiable {
    case moonPortal
    case separatePlayer

    var id: Self { self }
    var title: String {
        switch self {
        case .moonPortal: "月環內播放"
        case .separatePlayer: "獨立播放器"
        }
    }
    var symbol: String {
        switch self {
        case .moonPortal: "moon.circle.fill"
        case .separatePlayer: "macwindow"
        }
    }
}

/// The sole owner of video playback. Presentation surfaces may move between
/// the moon portal and a native window/sheet without replacing the AVPlayerItem.
@MainActor
@Observable
final class VideoPlaybackSession {
    @ObservationIgnored let player = AVPlayer()
    @ObservationIgnored private let endObserver = VideoPlaybackEndObserver()
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var itemStatusObservation: NSKeyValueObservation?
    @ObservationIgnored nonisolated(unsafe) private var timeObserver: Any?
    @ObservationIgnored private var playbackGeneration = 0
    var onPlaybackEnded: (@MainActor @Sendable () -> Void)?
    var onStateChanged: (@MainActor @Sendable () -> Void)?
    var onOutputLevelChanged: (@MainActor @Sendable (Float) -> Void)?
    var onPlaybackError: (@MainActor @Sendable (Error) -> Void)?
    private(set) var isPlaying = false
    private(set) var outputVolume: Float = 1
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    init() {
        endObserver.onPlaybackEnded = { [weak self] item, generation in
            guard let self,
                  generation == playbackGeneration,
                  player.currentItem === item else { return }
            isPlaying = false
            onOutputLevelChanged?(0)
            onPlaybackEnded?()
        }
        statusObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                isPlaying = player.timeControlStatus == .playing
                onStateChanged?()
            }
        }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
    }

    private func observeItemStatus(_ item: AVPlayerItem, generation: Int) {
        itemStatusObservation?.invalidate()
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] observedItem, _ in
            Task { @MainActor [weak self, weak item] in
                guard let self, let item,
                      observedItem === item,
                      generation == playbackGeneration,
                      player.currentItem === item else { return }
                guard item.status == .failed else { return }
                isPlaying = false
                onOutputLevelChanged?(0)
                let error = item.error ?? NSError(
                    domain: "CMV.VideoPlayback",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "影片播放失敗。"]
                )
                onPlaybackError?(error)
                onStateChanged?()
            }
        }
    }

    private func installTimeObserver(for item: AVPlayerItem, generation: Int) {
        removeTimeObserver()
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self,
                      generation == playbackGeneration,
                      player.currentItem === item else { return }
                let seconds = time.seconds
                if seconds.isFinite { currentTime = max(0, seconds) }
                let itemDuration = item.duration.seconds
                if itemDuration.isFinite, itemDuration > 0 { duration = itemDuration }
                onStateChanged?()
            }
        }
    }

    private func removeTimeObserver() {
        guard let timeObserver else { return }
        player.removeTimeObserver(timeObserver)
        self.timeObserver = nil
    }

    func load(url: URL, autoplay: Bool) {
        playbackGeneration &+= 1
        let generation = playbackGeneration
        if let asset = player.currentItem?.asset as? AVURLAsset, asset.url == url {
            guard let item = player.currentItem else { return }
            endObserver.observe(item, generation: generation)
            observeItemStatus(item, generation: generation)
            installTimeObserver(for: item, generation: generation)
            player.seek(to: .zero)
            currentTime = 0
            if autoplay { player.play() }
            onStateChanged?()
            return
        }
        let item = AVPlayerItem(url: url)
        currentTime = 0
        duration = 0
        player.replaceCurrentItem(with: item)
        endObserver.observe(item, generation: generation)
        observeItemStatus(item, generation: generation)
        installTimeObserver(for: item, generation: generation)
        Task { @MainActor [weak self, weak item] in
            guard let self, let item,
                  let loadedDuration = try? await item.asset.load(.duration),
                  generation == playbackGeneration,
                  player.currentItem === item else { return }
            let seconds = loadedDuration.seconds
            if seconds.isFinite, seconds > 0 {
                duration = seconds
                onStateChanged?()
            }
            if let audioTrack = try? await item.asset.loadTracks(withMediaType: .audio).first,
               generation == playbackGeneration,
               player.currentItem === item {
                try? VideoAudioMeter.install(on: item, audioTrack: audioTrack) { [weak self] level in
                    guard let self,
                          generation == self.playbackGeneration,
                          self.player.currentItem === item,
                          self.isPlaying else { return }
                    self.onOutputLevelChanged?(level)
                }
            }
        }
        if autoplay { player.play() }
    }

    func stop() {
        playbackGeneration &+= 1
        endObserver.invalidate()
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        removeTimeObserver()
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        currentTime = 0
        duration = 0
        onOutputLevelChanged?(0)
        onStateChanged?()
    }

    func togglePlayback() {
        if player.timeControlStatus == .playing {
            player.pause()
            onOutputLevelChanged?(0)
        } else if player.currentItem != nil {
            player.play()
        }
    }

    func setVolume(_ value: Float) {
        guard value.isFinite else { return }
        outputVolume = min(1, max(0, value))
        player.volume = outputVolume
    }

    func seek(to seconds: TimeInterval) {
        guard seconds.isFinite, duration.isFinite, duration > 0 else { return }
        let clamped = min(duration, max(0, seconds))
        currentTime = clamped
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        onStateChanged?()
    }
}

private final class VideoPlaybackEndObserver: @unchecked Sendable {
    var onPlaybackEnded: (@MainActor @Sendable (AVPlayerItem, Int) -> Void)?
    private var token: NSObjectProtocol?

    func observe(_ item: AVPlayerItem, generation: Int) {
        invalidate()
        token = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] notification in
            guard let finishedItem = notification.object as? AVPlayerItem else { return }
            Task { @MainActor [weak self] in
                self?.onPlaybackEnded?(finishedItem, generation)
            }
        }
    }

    func invalidate() {
        if let token { NotificationCenter.default.removeObserver(token) }
        token = nil
    }

    deinit { invalidate() }
}

@MainActor
@Observable
final class VideoWindowStore {
    private(set) var url: URL?
    private var scopedURL: URL?
    private var ownsScopedAccess = false

    func present(url: URL) {
        clear()
        ownsScopedAccess = url.startAccessingSecurityScopedResource()
        scopedURL = url
        self.url = url
    }

    func clear() {
        if ownsScopedAccess, let scopedURL { scopedURL.stopAccessingSecurityScopedResource() }
        ownsScopedAccess = false
        scopedURL = nil
        url = nil
    }
}

struct VideoExperienceView: View {
    let player: AVPlayer
    var showsPlaybackControls = true

    var body: some View {
        PlatformVideoPlayer(player: player, showsPlaybackControls: showsPlaybackControls)
            .accessibilityLabel("影片播放")
    }
}

#if os(macOS)
struct VideoWindowView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(VideoWindowStore.self) private var store
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Group {
            if store.url != nil {
                VideoExperienceView(player: appModel.videoSession.player)
                    .frame(minWidth: 320, minHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(16)
            } else {
                ContentUnavailableView("尚未選擇影片", systemImage: "film")
            }
        }
        .frame(minWidth: 520, minHeight: 360)
        .onDisappear {
            let presentedURL = store.url
            if presentedURL != nil,
               presentedURL == appModel.videoURL,
               appModel.videoPresentationMode == .separatePlayer {
                appModel.stopVideoPlayback()
            }
            store.clear()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("關閉") {
                    appModel.stopVideoPlayback()
                    store.clear()
                    dismissWindow(id: "video")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("放回月環", systemImage: "moon.circle.fill") {
                    appModel.videoPresentationMode = .moonPortal
                    dismissWindow(id: "video")
                }
                .accessibilityHint("保持目前進度並回到主視窗的月環播放器")
            }
        }
    }
}
#endif

#if os(macOS)
private struct PlatformVideoPlayer: NSViewRepresentable {
    let player: AVPlayer
    let showsPlaybackControls: Bool

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = showsPlaybackControls ? .floating : .none
        view.videoGravity = showsPlaybackControls ? .resizeAspect : .resizeAspectFill
        view.player = player
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        view.player = player
        view.controlsStyle = showsPlaybackControls ? .floating : .none
        view.videoGravity = showsPlaybackControls ? .resizeAspect : .resizeAspectFill
    }
}
#else
private struct PlatformVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    let showsPlaybackControls: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = showsPlaybackControls
        controller.videoGravity = showsPlaybackControls ? .resizeAspect : .resizeAspectFill
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.entersFullScreenWhenPlaybackBegins = false
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
        controller.showsPlaybackControls = showsPlaybackControls
        controller.videoGravity = showsPlaybackControls ? .resizeAspect : .resizeAspectFill
    }
}
#endif
