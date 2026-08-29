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
    var onPlaybackEnded: (@MainActor @Sendable () -> Void)?

    init() {
        endObserver.onPlaybackEnded = { [weak self] in
            self?.onPlaybackEnded?()
        }
    }

    func load(url: URL, autoplay: Bool) {
        if let asset = player.currentItem?.asset as? AVURLAsset, asset.url == url {
            player.seek(to: .zero)
            if autoplay { player.play() }
            return
        }
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        endObserver.observe(item)
        if autoplay { player.play() }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    func togglePlayback() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

}

private final class VideoPlaybackEndObserver: @unchecked Sendable {
    var onPlaybackEnded: (@MainActor @Sendable () -> Void)?
    private var token: NSObjectProtocol?

    func observe(_ item: AVPlayerItem) {
        if let token { NotificationCenter.default.removeObserver(token) }
        token = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.onPlaybackEnded?() }
        }
    }

    deinit {
        if let token { NotificationCenter.default.removeObserver(token) }
    }
}

/// Owns the Mac utility-window selection and keeps the document-picker scope
/// alive for as long as the floating player is visible.
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

/// Platform-native video surface: AppKit's AVPlayerView on Mac, and
/// AVPlayerViewController (including system PiP) on iPad.
struct VideoExperienceView: View {
    let player: AVPlayer
    var showsPlaybackControls = true

    var body: some View {
        PlatformVideoPlayer(player: player, showsPlaybackControls: showsPlaybackControls)
            .accessibilityLabel("影片播放")
    }
}

#if os(macOS)
/// Content for the dedicated draggable/resizable Mac video utility window.
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
        view.videoGravity = .resizeAspectFill
        view.player = player
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        view.player = player
        view.controlsStyle = showsPlaybackControls ? .floating : .none
        view.videoGravity = .resizeAspectFill
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
        controller.videoGravity = .resizeAspectFill
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.entersFullScreenWhenPlaybackBegins = false
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
        controller.showsPlaybackControls = showsPlaybackControls
        controller.videoGravity = .resizeAspectFill
    }
}
#endif
