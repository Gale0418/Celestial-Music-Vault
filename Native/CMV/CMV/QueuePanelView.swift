import SwiftUI
import SwiftData
import Observation
import CMVDomain
import CMVThemes

/// Isolates the queue panel from AppModel's coarse playback revision bridge.
/// AppModel still emits a revision for elapsed-time updates, but this snapshot
/// republishes only when the queue identity/order, displayed metadata, or
/// current track actually changes.
@MainActor
@Observable
private final class QueuePanelSnapshot {
    private(set) var tracks: [Track] = []
    private(set) var currentTrackID: UUID?

    @ObservationIgnored private weak var appModel: AppModel?
    @ObservationIgnored private var isBound = false
    @ObservationIgnored private var observationGeneration = 0
    @ObservationIgnored private var currentIndex = 0

    func bind(to appModel: AppModel) {
        if self.appModel !== appModel {
            unbind()
            self.appModel = appModel
        }
        guard !isBound else { return }
        isBound = true
        observeQueueInputs()
    }

    func unbind() {
        isBound = false
        observationGeneration &+= 1
        appModel = nil
    }

    private func observeQueueInputs() {
        guard isBound, let appModel else { return }
        observationGeneration &+= 1
        let generation = observationGeneration

        let observed = withObservationTracking {
            (appModel.displayQueue, appModel.currentTrackID)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self,
                      self.isBound,
                      self.observationGeneration == generation else { return }
                self.observeQueueInputs()
            }
        }

        publishIfChanged(queue: observed.0, currentTrackID: observed.1)
    }

    private func publishIfChanged(queue: PlaybackQueue, currentTrackID: UUID?) {
        if queueNeedsRefresh(queue) {
            currentIndex = queue.currentIndex
            tracks = queue.tracks
        }
        if self.currentTrackID != currentTrackID {
            self.currentTrackID = currentTrackID
        }
    }

    /// Hot-path comparison is allocation-free. Artwork bytes, ratings and pin
    /// state are intentionally excluded: artwork is not rendered in this panel,
    /// while rating/pin overrides are observed directly from AppModel by rows.
    private func queueNeedsRefresh(_ queue: PlaybackQueue) -> Bool {
        guard queue.currentIndex == currentIndex,
              queue.tracks.count == tracks.count else { return true }

        for index in queue.tracks.indices {
            let incoming = queue.tracks[index]
            let displayed = tracks[index]
            if incoming.id != displayed.id
                || incoming.title != displayed.title
                || incoming.artist != displayed.artist
                || incoming.album != displayed.album
                || incoming.availability != displayed.availability
                || incoming.mediaKind != displayed.mediaKind {
                return true
            }
        }
        return false
    }
}

struct PerformantQueueView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.cmvTheme) private var theme
    @State private var snapshot = QueuePanelSnapshot()

    var body: some View {
        let tracks = snapshot.tracks
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("接下來播放").font(.title2.bold())
                Spacer()
                Button("清除") { appModel.clearPlaybackQueue() }
                    .disabled(tracks.isEmpty)
            }

            if tracks.isEmpty {
                ContentUnavailableView(
                    "佇列是空的",
                    systemImage: "music.note.list",
                    description: Text("從歌曲、多選工具列或歌單選擇「加入接下來播放」。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(tracks.indices, id: \.self) { index in
                            queueRow(tracks[index], index: index, tracks: tracks)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(.clear)
        .task { snapshot.bind(to: appModel) }
        .onDisappear { snapshot.unbind() }
    }

    private func queueRow(_ track: Track, index: Int, tracks: [Track]) -> some View {
        let isCurrent = track.id == snapshot.currentTrackID
        return HStack(spacing: 12) {
            Button { appModel.play(tracks: tracks, startingAt: index, context: context) } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(theme.secondary)
                        Image(systemName: track.mediaKind == .video ? "film.fill" : "cloud.moon.fill")
                            .foregroundStyle(theme.metal)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title).lineLimit(1)
                        Text("\(track.artist) · \(track.album)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let status = statusText(for: track, isCurrent: isCurrent) {
                            Text(status)
                                .font(.caption2)
                                .foregroundStyle(theme.metal)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("播放 \(track.title)，\(track.artist)")

            QueueStarRatingControl(rating: appModel.rating(for: track), width: 100) { rating in
                appModel.setRating(track, rating: rating, context: context)
            }
        }
        .frame(minHeight: 60)
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(isCurrent ? theme.primary.opacity(0.16) : .clear,
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private func statusText(for track: Track, isCurrent: Bool) -> String? {
        var states: [String] = []
        if isCurrent { states.append("目前播放") }
        if appModel.pinnedTrackIDs.contains(track.id) { states.append("已釘選離線") }
        switch track.availability {
        case .available: break
        case .sourceOffline: states.append("來源離線")
        case .missing: states.append("檔案遺失")
        case .permissionRequired: states.append("需要重新授權")
        }
        return states.isEmpty ? nil : states.joined(separator: " · ")
    }
}

private struct QueueStarRatingControl: View {
    @Environment(\.cmvTheme) private var theme
    let rating: Int
    var width: CGFloat
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...5, id: \.self) { value in
                Image(systemName: value <= rating ? "star.fill" : "star")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(value <= rating ? theme.metal : .secondary)
            }
        }
        .frame(width: width, height: 44)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { gesture in
                    let safeWidth = max(1, width)
                    let selected = min(5, max(1, Int(gesture.location.x / safeWidth * 5) + 1))
                    onChange(selected == rating ? 0 : selected)
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("評分")
        .accessibilityValue(rating == 0 ? "未評分" : "\(rating) 顆星")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(5, rating + 1))
            case .decrement: onChange(max(0, rating - 1))
            @unknown default: break
            }
        }
    }
}
