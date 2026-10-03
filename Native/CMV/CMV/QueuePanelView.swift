import SwiftUI
import SwiftData
import Observation
import CMVDomain
import CMVThemes

private func cmvLocalizedFormat(_ key: String, arguments: CVarArg...) -> String {
    let preference = UserDefaults.standard.string(forKey: AppLanguage.preferenceKey) ?? "system"
    return String(
        format: AppLanguage.localized(key),
        locale: AppLanguage.locale(for: preference),
        arguments: arguments
    )
}

/// Isolates the queue panel from AppModel's coarse playback revision bridge.
/// AppModel still emits a revision for elapsed-time updates, but this snapshot
/// republishes only when the queue identity/order, displayed metadata, or
/// current track actually changes.
@MainActor
@Observable
private final class QueuePanelSnapshot {
    private(set) var tracks: [Track] = []
    private(set) var currentTrackID: UUID?
    private(set) var currentIndex = 0
    private(set) var revision = 0

    @ObservationIgnored private weak var appModel: AppModel?
    @ObservationIgnored private var isBound = false
    @ObservationIgnored private var observationGeneration = 0

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
            (appModel.queuePanelDisplayQueue, appModel.currentTrackID)
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
            revision &+= 1
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
    var expanded = false
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var snapshot = QueuePanelSnapshot()
    @State private var search = ""
    @State private var filteredIndices: [Int] = []
    @State private var filteredRevision = -1
    @State private var filteredQuery = ""

    private struct SearchKey: Hashable {
        let revision: Int
        let query: String
    }

    var body: some View {
        let tracks = snapshot.tracks
        let isSearching = expanded && !search.isEmpty
        let searchIsCurrent = filteredRevision == snapshot.revision && filteredQuery == search
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(AppLanguage.localized("接下來播放"))
                        .font(.title2.bold())
                    if expanded {
                        Text(cmvLocalizedFormat("與接下來播放同步 · %lld 首", arguments: Int64(tracks.count)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(AppLanguage.localized("清除")) { appModel.clearPlaybackQueue() }
                    .disabled(tracks.isEmpty)
            }

            if expanded && !tracks.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(AppLanguage.localized("搜尋歌曲、歌手或專輯"), text: $search)
                        .textFieldStyle(.plain)
                        .accessibilityLabel(AppLanguage.localized("搜尋歌曲、歌手或專輯"))
                }
                .padding(8)
                .background(
                    theme.isStorybook
                        ? AnyShapeStyle(theme.surface.opacity(0.72))
                        : (reduceTransparency ? AnyShapeStyle(theme.surface) : AnyShapeStyle(theme.surface.opacity(0.35))),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }

            if tracks.isEmpty {
                ContentUnavailableView(
                    AppLanguage.localized("佇列是空的"),
                    systemImage: "music.note.list",
                    description: Text(AppLanguage.localized("從歌曲、多選工具列或歌單選擇「加入接下來播放」。"))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isSearching && searchIsCurrent && filteredIndices.isEmpty {
                ContentUnavailableView(AppLanguage.localized("找不到曲目記錄"), systemImage: "magnifyingglass",
                                       description: Text(AppLanguage.localized("試試其他歌名、歌手或專輯關鍵字。")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if isSearching {
                        if searchIsCurrent {
                            ForEach(filteredIndices, id: \.self) { index in
                                queueRow(tracks[index], index: index, tracks: tracks)
                                    .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        }
                    } else {
                        ForEach(tracks.indices, id: \.self) { index in
                            queueRow(tracks[index], index: index, tracks: tracks)
                                .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                        .onMove { offsets, destination in
                            for source in offsets.sorted(by: >) {
                                appModel.movePlaybackQueueItem(from: source, to: destination, context: context)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .task {
            snapshot.bind(to: appModel)
            await appModel.restorePlaybackQueueIfNeeded(context: context)
        }
        .task(id: SearchKey(revision: snapshot.revision, query: search)) {
            guard expanded, !search.isEmpty else { filteredIndices = []; return }
            do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
            let currentTracks = snapshot.tracks
            let query = search
            let matches = await Task.detached(priority: .userInitiated) {
                currentTracks.indices.filter { index in
                    let track = currentTracks[index]
                    return track.title.localizedCaseInsensitiveContains(query)
                        || track.artist.localizedCaseInsensitiveContains(query)
                        || track.album.localizedCaseInsensitiveContains(query)
                }
            }.value
            guard !Task.isCancelled else { return }
            filteredIndices = matches
            filteredRevision = snapshot.revision
            filteredQuery = query
        }
        .onDisappear { snapshot.unbind() }
    }

    private func queueRow(_ track: Track, index: Int, tracks: [Track]) -> some View {
        let isCurrent = index == snapshot.currentIndex && track.id == snapshot.currentTrackID
        let durationSeconds = max(0, Int(track.duration))
        let durationLabel = "\(durationSeconds / 60):\(String(format: "%02d", durationSeconds % 60))"
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
                        Text("\(AppLanguage.localizedArtist(track.artist)) · \(AppLanguage.localizedAlbum(track.album))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let status = statusText(for: track, isCurrent: isCurrent) {
                            Text(status)
                                .font(.caption2)
                                .foregroundStyle(theme.metal)
                                .lineLimit(1)
                        }
                        if expanded {
                            let mediaKind = AppLanguage.localized(track.mediaKind == .video ? "影片" : "音樂")
                            Text(cmvLocalizedFormat("第 %lld 首 · %@ · %@",
                                                   arguments: Int64(index + 1), mediaKind, durationLabel))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 4)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(cmvLocalizedFormat("播放 %@，%@",
                                                   arguments: track.title, AppLanguage.localizedArtist(track.artist)))

            QueueStarRatingControl(rating: appModel.rating(for: track), width: 100) { rating in
                appModel.setRating(track, rating: rating, context: context)
            }

            if expanded && index > snapshot.currentIndex {
                Menu {
                    Button(AppLanguage.localized("移到最前"), systemImage: "arrow.up.to.line") {
                        appModel.movePlaybackQueueItem(from: index, to: snapshot.currentIndex + 1, context: context)
                    }
                    Button(AppLanguage.localized("移除"), systemImage: "minus.circle", role: .destructive) {
                        appModel.removePlaybackQueueItem(at: index, context: context)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .menuOrder(.fixed)
                .accessibilityLabel(AppLanguage.localized("佇列曲目操作"))
            }
        }
        .frame(minHeight: 60)
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(isCurrent
                    ? (theme.isStorybook
                        ? theme.secondary.opacity(0.26)
                        : (reduceTransparency ? theme.surface : theme.primary.opacity(0.16)))
                    : .clear,
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            if reduceTransparency && isCurrent {
                RoundedRectangle(cornerRadius: 14).strokeBorder(theme.primary, lineWidth: 2)
            }
        }
    }

    private func statusText(for track: Track, isCurrent: Bool) -> String? {
        var states: [String] = []
        if isCurrent { states.append(AppLanguage.localized("目前播放")) }
        if appModel.pinnedTrackIDs.contains(track.id) { states.append(AppLanguage.localized("已釘選離線")) }
        switch track.availability {
        case .available: break
        case .sourceOffline: states.append(AppLanguage.localized("來源離線"))
        case .missing: states.append(AppLanguage.localized("檔案遺失"))
        case .permissionRequired: states.append(AppLanguage.localized("需要重新授權"))
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
            SpatialTapGesture()
                .onEnded { gesture in
                    let safeWidth = max(1, width)
                    let selected = min(5, max(1, Int(gesture.location.x / safeWidth * 5) + 1))
                    onChange(selected == rating ? 0 : selected)
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLanguage.localized("評分"))
        .accessibilityValue(rating == 0
            ? AppLanguage.localized("未評分")
            : cmvLocalizedFormat("%lld 顆星", arguments: Int64(rating)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(5, rating + 1))
            case .decrement: onChange(max(0, rating - 1))
            @unknown default: break
            }
        }
    }
}
