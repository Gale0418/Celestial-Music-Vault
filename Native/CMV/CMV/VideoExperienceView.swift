import SwiftUI
import SwiftData
import AVKit
import Observation

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
    let url: URL
    var onPlaybackEnded: @MainActor @Sendable () -> Void = {}

    var body: some View {
        PlatformVideoPlayer(url: url, onPlaybackEnded: onPlaybackEnded)
            .frame(minWidth: 320, minHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityLabel("影片播放")
    }
}

#if os(macOS)
/// Content for the dedicated draggable/resizable Mac video utility window.
struct VideoWindowView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(VideoWindowStore.self) private var store
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Group {
            if let url = store.url {
                VideoExperienceView(url: url) {
                    appModel.advanceAfterVideo(context: modelContext)
                }
                    .padding(16)
            } else {
                ContentUnavailableView("尚未選擇影片", systemImage: "film")
            }
        }
        .frame(minWidth: 520, minHeight: 360)
        .onDisappear {
            let presentedURL = store.url
            if presentedURL != nil, presentedURL == appModel.videoURL {
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
    let url: URL
    let onPlaybackEnded: @MainActor @Sendable () -> Void

    func makeCoordinator() -> VideoPlayerCoordinator {
        VideoPlayerCoordinator(onPlaybackEnded: onPlaybackEnded)
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        let player = AVPlayer(url: url)
        view.player = player
        context.coordinator.observe(player)
        player.play()
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        guard let asset = view.player?.currentItem?.asset as? AVURLAsset,
              asset.url == url else {
            let player = AVPlayer(url: url)
            view.player = player
            context.coordinator.observe(player)
            player.play()
            return
        }
    }
}
#else
private struct PlatformVideoPlayer: UIViewControllerRepresentable {
    let url: URL
    let onPlaybackEnded: @MainActor @Sendable () -> Void

    func makeCoordinator() -> VideoPlayerCoordinator {
        VideoPlayerCoordinator(onPlaybackEnded: onPlaybackEnded)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        if let player = controller.player { context.coordinator.observe(player) }
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.player?.play()
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        guard let asset = controller.player?.currentItem?.asset as? AVURLAsset,
              asset.url == url else {
            let player = AVPlayer(url: url)
            controller.player = player
            context.coordinator.observe(player)
            player.play()
            return
        }
    }
}
#endif

/// Bridges AVPlayer's end-of-item notification back to the shared app queue.
private final class VideoPlayerCoordinator: NSObject, @unchecked Sendable {
    private let onPlaybackEnded: @MainActor @Sendable () -> Void
    private var endObserver: NSObjectProtocol?

    init(onPlaybackEnded: @escaping @MainActor @Sendable () -> Void) {
        self.onPlaybackEnded = onPlaybackEnded
    }

    func observe(_ player: AVPlayer) {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onPlaybackEnded()
            }
        }
    }

    deinit {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }
}
