import SwiftUI
import SwiftData
import CMVDomain
import CMVLibrary
import CMVThemes
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

private func trackStatusText(_ track: Track, pinnedTrackIDs: Set<UUID>, isCurrent: Bool = false) -> String? {
    var states: [String] = []
    if isCurrent { states.append("目前播放") }
    if pinnedTrackIDs.contains(track.id) { states.append("已釘選離線") }
    switch track.availability {
    case .available: break
    case .sourceOffline: states.append("來源離線")
    case .missing: states.append("檔案遺失")
    case .permissionRequired: states.append("需要重新授權")
    }
    return states.isEmpty ? nil : states.joined(separator: " · ")
}

private func isLibraryImporterCancellation(_ error: Error) -> Bool {
    let cocoa = error as NSError
    return cocoa.domain == NSCocoaErrorDomain && cocoa.code == CocoaError.Code.userCancelled.rawValue
}

struct SidebarView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.cmvTheme) private var theme
    @Query(sort: \MediaSourceRecord.displayName) private var sources: [MediaSourceRecord]
    @State private var trackCount = 0

    var body: some View {
        @Bindable var appModel = appModel
        List(selection: $appModel.selection) {
            Section {
                ForEach(LibraryDestination.allCases.filter { $0 != .settings }) { destination in
                    Label(destination.title, systemImage: destination.symbol).tag(destination)
                }
            }
            Section("曲庫") {
                Label("\(trackCount.formatted()) 首曲目", systemImage: "music.note.house")
                    .foregroundStyle(.secondary)
                Button { appModel.showingImporter = true } label: {
                    Label("加入音樂", systemImage: "plus.circle")
                }
            }
            Section { Label("設定", systemImage: "gearshape").tag(LibraryDestination.settings) }
        }
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial.opacity(0.34))
        .background(theme.surface.opacity(0.10))
        .navigationTitle("星穹私藏音樂庫")
        .tint(theme.primary)
        .defaultScrollAnchor(.top)
        .task(id: sources.map(\.updatedAt)) { refreshTrackCount() }
    }

    private func refreshTrackCount() {
        let descriptor = FetchDescriptor<TrackRecord>(predicate: #Predicate { !$0.isExcluded })
        do {
            trackCount = try context.fetchCount(descriptor)
        } catch {
            appModel.errorMessage = "無法讀取曲庫數量：\(error.localizedDescription)"
        }
    }
}

struct LibraryStageView: View {
    @Environment(AppModel.self) private var appModel
    var body: some View {
        Group {
            switch appModel.selection {
            case .nowPlaying, nil: NowPlayingView()
            case .albums: CatalogView(kind: .album)
            case .songs: ScrollView { TrackListView() }
            case .artists: CatalogView(kind: .artist)
            case .playlists: PlaylistHubView()
            case .favorites: FavoriteTracksView()
            case .settings: SettingsView()
            }
        }
    }
}

struct NowPlayingView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isSeeking = false
    @State private var seekPosition: TimeInterval = 0
    @State private var showingVideoImporter = false

    var body: some View {
        let current = appModel.currentTrack
        GeometryReader { proxy in
            let usesHorizontalLayout = proxy.size.width >= 720
            let contentWidth = max(0, proxy.size.width - 48)
            let mediaSize = usesHorizontalLayout
                ? min(360, max(240, contentWidth - 360))
                : min(360, contentWidth)

            ScrollView {
                VStack(alignment: .leading, spacing: usesHorizontalLayout ? 56 : 30) {
                    if usesHorizontalLayout {
                        HStack(alignment: .center, spacing: 40) {
                            mediaWorld(size: mediaSize, artworkData: current?.artworkData)
                            nowPlayingControls
                                .frame(maxWidth: 520, alignment: .leading)
                        }
                        .frame(maxWidth: 880, alignment: .leading)
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: 24) {
                            mediaWorld(size: mediaSize, artworkData: current?.artworkData)
                                .frame(maxWidth: .infinity)
                            nowPlayingControls
                        }
                    }
                    listeningDetailsCard(track: current)
                }
                .frame(maxWidth: 1_100, alignment: .topLeading)
                .frame(maxWidth: .infinity, minHeight: max(0, proxy.size.height - 48), alignment: .top)
                .padding(.horizontal, 24)
                .padding(.top, usesHorizontalLayout ? 72 : 24)
                .padding(.bottom, 36)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("現在收聽")
        .fileImporter(isPresented: $showingVideoImporter, allowedContentTypes: [.movie]) { result in
            switch result {
            case .success(let url):
                appModel.playStandaloneVideo(url: url)
            case .failure(let error):
                if !isLibraryImporterCancellation(error) {
                    appModel.errorMessage = "無法選擇影片：\(error.localizedDescription)"
                }
            }
        }
    }

    @ViewBuilder private var nowPlayingControls: some View {
        let current = appModel.currentTrack
        VStack(alignment: .leading, spacing: 12) {
            Text("現在收聽").font(.headline).foregroundStyle(theme.metal)
            Text(current?.title ?? "夜航收藏")
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(current?.artist ?? "私人曲庫")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let current {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { currentMediaDetails(current) }
                    VStack(alignment: .leading, spacing: 6) { currentMediaDetails(current) }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                if appModel.currentMediaDuration.isFinite, appModel.currentMediaDuration > 0 {
                    playbackProgress
                }
            }
            ViewThatFits(in: .horizontal) {
                playbackActions
                ScrollView(.horizontal, showsIndicators: false) { playbackActions }
            }
        }
    }

    @ViewBuilder
    private func currentMediaDetails(_ track: Track) -> some View {
        Label(track.album, systemImage: "square.stack").lineLimit(1)
        Label(track.mediaKind == .video ? "影片" : "音訊", systemImage: track.mediaKind == .video ? "film" : "waveform")
        if track.duration.isFinite, track.duration > 0 {
            Label(durationText(track.duration), systemImage: "clock")
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        guard duration.isFinite, duration > 0 else { return "0:00" }
        let capped = min(duration.rounded(), Double(Int.max / 2))
        let totalSeconds = Int(capped)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var playbackProgress: some View {
        let rawDuration = appModel.currentMediaDuration
        let duration = rawDuration.isFinite ? max(0, rawDuration) : 0
        let rawElapsed = isSeeking ? seekPosition : appModel.currentMediaElapsed
        let elapsed = rawElapsed.isFinite ? max(0, rawElapsed) : 0
        let displayedPosition = min(duration, elapsed)
        return HStack(spacing: 10) {
            Text(durationText(displayedPosition))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { displayedPosition },
                    set: { seekPosition = $0 }
                ),
                in: 0...max(1, duration),
                onEditingChanged: { editing in
                    if editing {
                        let current = appModel.currentMediaElapsed
                        seekPosition = current.isFinite ? max(0, current) : 0
                    } else {
                        appModel.seekCurrentMedia(to: seekPosition)
                    }
                    isSeeking = editing
                }
            )
            .accessibilityLabel("播放進度")
            .accessibilityValue("\(durationText(displayedPosition))，共 \(durationText(duration))")
            Text(durationText(duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func listeningDetailsCard(track: Track?) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("此刻聆聽").font(.title3.weight(.semibold))
                    Text(track == nil ? "播放一首收藏，星光會在這裡留下它的細節。" : "為這段夜航留下評分與收藏。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if let track {
                    StarRatingControl(rating: appModel.rating(for: track)) { rating in
                        appModel.setRating(track, rating: rating, context: context)
                    }
                }
            }

            if track == nil {
                Button("加入音樂來源", systemImage: "folder.badge.plus") { appModel.showingImporter = true }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                    .accessibilityHint("選擇本機或已在檔案 App、Finder 連接的 NAS 資料夾")
            }

            if let track {
                Divider().overlay(theme.metal.opacity(0.32))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 22) { listeningMetadata(track) }
                    VStack(alignment: .leading, spacing: 12) { listeningMetadata(track) }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            reduceTransparency
                ? AnyShapeStyle(theme.surface.opacity(0.98))
                : AnyShapeStyle(.ultraThinMaterial.opacity(0.52)),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [theme.metal.opacity(0.56), theme.primary.opacity(0.28), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: theme.primary.opacity(0.12), radius: 24, y: 12)
    }

    @ViewBuilder
    private func listeningMetadata(_ track: Track) -> some View {
        Label(track.album, systemImage: "square.stack").lineLimit(1)
        Label(track.artist, systemImage: "person.fill").lineLimit(1)
        Label(track.mediaKind == .video ? "影片" : "音訊", systemImage: track.mediaKind == .video ? "film" : "waveform")
        Button { appModel.setFavorite(track, context: context) } label: {
            Label(appModel.isFavorite(for: track) ? "已收藏" : "加入最愛",
                  systemImage: appModel.isFavorite(for: track) ? "heart.fill" : "heart")
        }
        .buttonStyle(.borderless)
        .tint(theme.primary)
    }

    private var playbackActions: some View {
        ViewThatFits(in: .horizontal) {
            primaryPlaybackActions
            ScrollView(.horizontal, showsIndicators: false) { primaryPlaybackActions }
        }
        .controlSize(.large)
        .padding(10)
        .background(
            reduceTransparency ? AnyShapeStyle(theme.surface.opacity(0.96)) : AnyShapeStyle(.thinMaterial),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(theme.metal.opacity(0.24)) }
    }

    private var primaryPlaybackActions: some View {
        HStack(spacing: 10) {
            Button(appModel.isCurrentMediaPlaying ? "暫停" : "播放", systemImage: appModel.isCurrentMediaPlaying ? "pause.fill" : "play.fill") {
                appModel.toggleCurrentMediaPlayback(context: context)
            }
            .accessibilityHint(appModel.videoURL == nil ? "播放目前曲目" : "播放或暫停目前影片")
            .buttonStyle(.borderedProminent)
            Button("隨機播放", systemImage: "shuffle") { appModel.toggleShuffle() }
                .disabled(!appModel.canShuffleQueue)
                .buttonStyle(.bordered)
                .tint(appModel.isShuffleEnabled ? theme.primary : nil)
                .accessibilityValue(appModel.isShuffleEnabled ? "已開啟" : "已關閉")
            SleepTimerMenu().buttonStyle(.bordered)
            Button("開啟影片", systemImage: "film") { showingVideoImporter = true }
                .buttonStyle(.bordered)
                .accessibilityHint("從檔案選擇尚未加入曲庫的影片")
        }
    }

    @ViewBuilder
    private func mediaWorld(size: CGFloat, artworkData: Data?) -> some View {
        if appModel.videoURL != nil, appModel.videoPresentationMode == .moonPortal {
            VideoMoonPortalView(size: size)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
        } else {
            AlbumWorldView(
                size: size,
                artworkID: appModel.currentTrack?.id,
                artworkData: artworkData,
                albumTitle: appModel.currentTrack?.album ?? "專輯",
                energyState: appModel.audioEnergy,
                isPlaying: appModel.playback.isPlaying
            )
        }
    }
}

struct VideoSelection: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct StarRatingControl: View {
    @Environment(\.cmvTheme) private var theme
    let rating: Int
    var width: CGFloat = 128
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...5, id: \.self) { value in
                Image(systemName: value <= rating ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(value <= rating ? theme.metal : .secondary)
                    .symbolEffect(.bounce, value: rating)
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
        .accessibilityElement()
        .accessibilityLabel("評分")
        .accessibilityValue(rating == 0 ? "未評分" : "\(rating) 顆星")
        .accessibilityHint("點選星星評分；上下滑動可調整")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(5, rating + 1))
            case .decrement: onChange(max(0, rating - 1))
            @unknown default: break
            }
        }
    }
}

private enum TrackListSortMode: String, CaseIterable, Identifiable {
    case relevance, title, artist, album, modifiedAt, random
    var id: Self { self }
    var title: String {
        switch self {
        case .relevance: "預設／相關度"
        case .title: "歌名"
        case .artist: "藝術家"
        case .album: "專輯"
        case .modifiedAt: "修改時間"
        case .random: "隨機排列"
        }
    }
    var symbol: String {
        switch self {
        case .relevance: "line.3.horizontal.decrease"
        case .title: "textformat"
        case .artist: "person"
        case .album: "square.stack"
        case .modifiedAt: "clock"
        case .random: "shuffle"
        }
    }
    var repositorySort: LibraryTrackSort? {
        switch self {
        case .relevance, .random: nil
        case .title: .title
        case .artist: .artist
        case .album: .album
        case .modifiedAt: .modifiedAt
        }
    }
}

private struct TrackListQueryID: Hashable {
    let search: String
    let sort: TrackListSortMode
    let ascending: Bool
}

struct TrackListView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.cmvTheme) private var theme
    @Query(sort: \MediaSourceRecord.displayName) private var sources: [MediaSourceRecord]
    @State private var tracks: [Track] = []
    @State private var search = ""
    @State private var playlists: [Playlist] = []
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var searchGeneration = 0
    @State private var displayedGeneration = -1
    @State private var loadingGeneration: Int?
    @State private var selectedTrackIDs = Set<UUID>()
    @State private var isSelectingAll = false
    @State private var showingRemoveConfirmation = false
    @State private var sortMode: TrackListSortMode = .relevance
    @State private var sortAscending = true
    @State private var randomTrackIDs: [UUID]?
    #if os(macOS)
    @State private var trackPendingTrash: Track?
    #endif
    private let pageSize = 200

    var body: some View {
        let rowTracks = tracks
        LazyVStack(spacing: 2) {
            if !tracks.isEmpty {
                HStack(spacing: 10) {
                    Button { selectAllMatchingTracks() } label: {
                        Label(selectedTrackIDs.isEmpty ? "全選" : "重新全選",
                              systemImage: selectedTrackIDs.isEmpty ? "checklist.unchecked" : "checklist.checked")
                    }
                    .disabled(isSelectingAll)
                    if !selectedTrackIDs.isEmpty {
                        Text("已選 \(selectedTrackIDs.count) 首").font(.callout.weight(.semibold)).foregroundStyle(theme.primary)
                        Button("取消全選") { selectedTrackIDs.removeAll() }
                    }
                    Spacer()
                    Menu {
                        ForEach(TrackListSortMode.allCases) { mode in
                            Button { sortMode = mode } label: { Label(mode.title, systemImage: mode.symbol) }
                        }
                    } label: { Label("排序：\(sortMode.title)", systemImage: sortMode.symbol) }
                    .accessibilityLabel("排序方式，目前為\(sortMode.title)")
                    Button { sortAscending.toggle() } label: {
                        Label(sortAscending ? "升冪" : "降冪", systemImage: sortAscending ? "arrow.up" : "arrow.down")
                    }
                    .disabled(sortMode == .random || sortMode == .relevance)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
            }
            if !selectedTrackIDs.isEmpty { batchActionBar }
            ForEach(rowTracks.indices, id: \.self) { index in
                let track = rowTracks[index]
                let isCurrent = track.id == appModel.currentTrackID
                let isSelected = selectedTrackIDs.contains(track.id)
                HStack(spacing: 14) {
                    Button {
                        if isSelected { selectedTrackIDs.remove(track.id) } else { selectedTrackIDs.insert(track.id) }
                    } label: {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                            .foregroundStyle(isSelected ? theme.primary : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(isSelected ? "取消選取\(track.title)" : "選取\(track.title)")
                    Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary).frame(width: 28, alignment: .trailing)
                    Image(systemName: track.mediaKind == .video ? "film" : (isCurrent ? "waveform" : "music.note"))
                        .foregroundStyle(isCurrent ? theme.primary : .secondary)
                    VStack(alignment: .leading) {
                        Text(track.title).lineLimit(1)
                        HStack(spacing: 4) {
                            Text(track.artist).lineLimit(1)
                            if let status = trackStatusText(track, pinnedTrackIDs: appModel.pinnedTrackIDs, isCurrent: isCurrent) {
                                Text("· \(status)").lineLimit(1)
                            }
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(track.album).foregroundStyle(.secondary).lineLimit(1)
                    StarRatingControl(rating: appModel.rating(for: track), width: 112) { rating in
                        appModel.setRating(track, rating: rating, context: context)
                        if let localIndex = tracks.firstIndex(where: { $0.id == track.id }) { tracks[localIndex].rating = rating }
                    }
                    Button { appModel.play(tracks: rowTracks, startingAt: index, context: context) } label: {
                        Image(systemName: "play.circle.fill").foregroundStyle(theme.primary)
                    }
                    .buttonStyle(.borderless).frame(width: 44, height: 44).accessibilityLabel("播放\(track.title)")
                    Menu { trackActions(for: track, at: index, in: rowTracks) } label: {
                        Image(systemName: "ellipsis.circle").accessibilityLabel("歌曲操作")
                    }.frame(width: 44, height: 44)
                    Button { appModel.setFavorite(track, context: context) } label: {
                        Image(systemName: appModel.isFavorite(for: track) ? "heart.fill" : "heart")
                            .foregroundStyle(appModel.isFavorite(for: track) ? theme.primary : .secondary)
                    }
                    .buttonStyle(.borderless).frame(width: 44, height: 44)
                    .accessibilityLabel(appModel.isFavorite(for: track) ? "移除最愛" : "加入最愛")
                }
                .frame(minHeight: 48)
                .padding(.horizontal, 12)
                .background(isSelected ? theme.primary.opacity(0.22) : (isCurrent ? theme.primary.opacity(0.15) : .clear),
                            in: RoundedRectangle(cornerRadius: 12))
                .contextMenu { trackActions(for: track, at: index, in: rowTracks) }
                .task { if index == rowTracks.count - 1 { await loadNextPage(generation: searchGeneration) } }
            }
            if tracks.isEmpty {
                if isLoading {
                    Color.clear.frame(minHeight: 220).accessibilityHidden(true)
                } else if let error = appModel.libraryReadError {
                    ContentUnavailableView("無法載入曲庫", systemImage: "exclamationmark.triangle", description: Text(error)).frame(minHeight: 220)
                } else {
                    ContentUnavailableView("尚未加入音樂", systemImage: "cloud.moon", description: Text("前往設定加入本機或 NAS 資料夾。")).frame(minHeight: 220)
                }
            }
        }
        .padding(12)
        .cloudSurface()
        .searchable(text: $search, prompt: "搜尋歌曲、歌手或專輯")
        .task(id: TrackListQueryID(search: search, sort: sortMode, ascending: sortAscending)) { await fetchPage() }
        .onChange(of: sources.map(\.updatedAt)) { _, _ in Task { @MainActor in await fetchPage() } }
        .task(id: appModel.playlistRevision) { playlists = await appModel.playlists(context: context) }
        .alert("從 CMV 移出 \(selectedTrackIDs.count) 首曲目？", isPresented: $showingRemoveConfirmation) {
            Button("取消", role: .cancel) {}
            Button("移出但保留原始檔案", role: .destructive) { removeSelectedTracks() }
        } message: {
            Text("曲目會從 CMV 曲庫與歌單隱藏，NAS／磁碟上的原始音樂與影片不會刪除；重新索引也不會自動加回。")
        }
        #if os(macOS)
        .alert(item: $trackPendingTrash) { track in
            Alert(
                title: Text("將「\(track.title)」移至垃圾桶？"),
                message: Text("這會移動實體檔案，並將曲目從 CMV 與歌單移出。若來源不支援系統垃圾桶，操作會取消且保留曲目。"),
                primaryButton: .destructive(Text("移至垃圾桶")) { moveTrackToTrash(track) },
                secondaryButton: .cancel()
            )
        }
        .onCommand(#selector(NSStandardKeyBindingResponding.selectAll(_:))) { selectAllMatchingTracks() }
        #endif
    }

    private var batchActionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button("播放所選", systemImage: "play.fill") { playSelectedTracks() }.buttonStyle(.borderedProminent)
                Button("加入接下來播放", systemImage: "text.badge.plus") { enqueueSelectedTracks() }
                Menu("加入歌單", systemImage: "text.badge.plus") {
                    if playlists.isEmpty { Text("尚未建立歌單") }
                    else { ForEach(playlists) { playlist in Button(playlist.name) { addSelectedTracks(to: playlist) } } }
                }
                .disabled(playlists.isEmpty)
                Button("取消選取", systemImage: "xmark") { selectedTrackIDs.removeAll() }
                Button("移出 CMV", systemImage: "rectangle.portrait.and.arrow.right") { showingRemoveConfirmation = true }
                    .buttonStyle(.bordered).tint(.red)
            }
            .padding(.horizontal, 12).frame(minHeight: 52)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(theme.primary.opacity(0.28)) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("已選取 \(selectedTrackIDs.count) 首的批次操作")
    }

    @MainActor private func fetchPage() async {
        selectedTrackIDs.removeAll()
        searchGeneration &+= 1
        let generation = searchGeneration
        displayedGeneration = -1
        randomTrackIDs = nil
        hasMore = true
        if !search.isEmpty {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled, generation == searchGeneration else { return }
        }
        if sortMode == .random {
            let query = search
            let ids = await appModel.trackIDs(matching: query, context: context)
            let shuffled = await Task.detached(priority: .userInitiated) { ids.shuffled() }.value
            guard !Task.isCancelled, generation == searchGeneration, query == search else { return }
            randomTrackIDs = shuffled
        }
        await loadNextPage(generation: generation)
    }

    @MainActor private func selectAllMatchingTracks() {
        guard !isSelectingAll else { return }
        isSelectingAll = true
        let query = search
        let generation = searchGeneration
        Task { @MainActor in
            let ids: [UUID]
            if sortMode == .random, let randomTrackIDs { ids = randomTrackIDs }
            else {
                ids = await appModel.trackIDs(matching: query, context: context,
                                              sort: sortMode.repositorySort ?? .title, ascending: sortAscending)
            }
            guard search == query, searchGeneration == generation else { isSelectingAll = false; return }
            selectedTrackIDs = Set(ids)
            isSelectingAll = false
        }
    }

    @MainActor private func removeSelectedTracks() {
        let ids = selectedTrackIDs
        Task { @MainActor in
            guard await appModel.excludeTracks(ids: ids, context: context) else { return }
            selectedTrackIDs.removeAll()
            await fetchPage()
        }
    }

    @MainActor private func orderedSelectedTracks() async -> [Track] {
        let allIDs: [UUID]
        if sortMode == .random, let randomTrackIDs { allIDs = randomTrackIDs }
        else {
            allIDs = await appModel.trackIDs(matching: search, context: context,
                                             sort: sortMode.repositorySort ?? .title, ascending: sortAscending)
        }
        return await appModel.tracks(ids: allIDs.filter { selectedTrackIDs.contains($0) }, context: context)
    }

    @MainActor private func playSelectedTracks() {
        Task { @MainActor in
            let selected = await orderedSelectedTracks()
            guard !selected.isEmpty else { return }
            appModel.play(tracks: selected, context: context)
            selectedTrackIDs.removeAll()
        }
    }

    @MainActor private func enqueueSelectedTracks() {
        Task { @MainActor in
            let selected = await orderedSelectedTracks()
            guard !selected.isEmpty else { return }
            appModel.addToPlaybackQueue(selected, context: context)
            selectedTrackIDs.removeAll()
        }
    }

    @MainActor private func addSelectedTracks(to playlist: Playlist) {
        Task { @MainActor in
            let selected = await orderedSelectedTracks()
            guard await appModel.addTracks(selected, to: playlist, context: context) else { return }
            selectedTrackIDs.removeAll()
        }
    }

    @ViewBuilder private func trackActions(for track: Track, at index: Int, in queue: [Track]) -> some View {
        Button("立即播放", systemImage: "play.fill") { appModel.play(tracks: queue, startingAt: index, context: context) }
        Button("加入接下來播放", systemImage: "text.badge.plus") { appModel.addToPlaybackQueue([track], context: context) }
        Button(appModel.isFavorite(for: track) ? "移除最愛" : "加入最愛",
               systemImage: appModel.isFavorite(for: track) ? "heart.slash" : "heart") {
            appModel.setFavorite(track, context: context)
        }
        Section("評分") {
            let currentRating = appModel.rating(for: track)
            ForEach(1...5, id: \.self) { rating in
                Button { appModel.setRating(track, rating: rating, context: context) } label: {
                    Label("\(rating) 顆星", systemImage: rating <= currentRating ? "star.fill" : "star")
                }
            }
            if currentRating > 0 {
                Button("清除評分", systemImage: "star.slash") { appModel.setRating(track, rating: 0, context: context) }
            }
        }
        if !playlists.isEmpty {
            Section("加入歌單") {
                ForEach(playlists) { playlist in
                    Button(playlist.name) { Task { _ = await appModel.addTrack(track, to: playlist, context: context) } }
                }
            }
        }
        Button { appModel.togglePinned(track, context: context) } label: {
            Label(appModel.pinnedTrackIDs.contains(track.id) ? "取消釘選離線" : "釘選離線",
                  systemImage: appModel.pinnedTrackIDs.contains(track.id) ? "pin.slash" : "pin")
        }
        #if os(macOS)
        Button("在 Finder 中顯示", systemImage: "folder") { appModel.revealInFinder(track, context: context) }
        Button("複製相對路徑", systemImage: "doc.on.doc") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(track.relativePath, forType: .string)
        }
        Button("將實體檔案移至垃圾桶", systemImage: "trash", role: .destructive) { trackPendingTrash = track }
        #endif
        Divider()
        Button("移出 CMV（保留原檔）", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
            selectedTrackIDs = [track.id]
            showingRemoveConfirmation = true
        }
    }

    #if os(macOS)
    @MainActor private func moveTrackToTrash(_ track: Track) {
        Task { @MainActor in
            guard await appModel.moveToTrash(track, context: context) else { return }
            selectedTrackIDs.remove(track.id)
            await fetchPage()
        }
    }
    #endif

    @MainActor private func loadNextPage(generation: Int) async {
        guard hasMore, generation == searchGeneration else { return }
        // Same-generation row tasks can fire more than once before the first
        // request returns. A newer generation may supersede an older request,
        // but a duplicate owner for the same generation must never start.
        if loadingGeneration == generation { return }
        loadingGeneration = generation
        isLoading = true
        let activityID = appModel.beginBackgroundActivity(
            kind: .library,
            title: search.isEmpty ? "正在讀取曲庫" : "正在搜尋曲庫",
            detail: search.isEmpty ? nil : search
        )
        defer {
            appModel.endBackgroundActivity(activityID)
            if loadingGeneration == generation {
                loadingGeneration = nil
                isLoading = false
            }
        }
        let replacesVisiblePage = displayedGeneration != generation
        let pageOffset = replacesVisiblePage ? 0 : tracks.count
        let page: [Track]
        if sortMode == .random, let randomTrackIDs {
            let end = min(pageOffset + pageSize, randomTrackIDs.count)
            let pageIDs = pageOffset < end ? Array(randomTrackIDs[pageOffset..<end]) : []
            page = await appModel.tracks(ids: pageIDs, context: context)
        } else {
            page = await appModel.searchTracks(query: search, context: context,
                                               sort: sortMode.repositorySort, ascending: sortAscending,
                                               limit: pageSize, offset: pageOffset)
        }
        guard !Task.isCancelled, generation == searchGeneration else { return }
        guard !page.isEmpty else {
            if replacesVisiblePage { tracks = []; displayedGeneration = generation }
            hasMore = false
            return
        }
        if replacesVisiblePage {
            tracks = page
            displayedGeneration = generation
        } else {
            let existingIDs = Set(tracks.map(\.id))
            let uniquePage = page.filter { !existingIDs.contains($0.id) }
            guard !uniquePage.isEmpty else { hasMore = false; return }
            tracks.append(contentsOf: uniquePage)
        }
        hasMore = sortMode == .random ? tracks.count < (randomTrackIDs?.count ?? 0) : page.count == pageSize
        await appModel.refreshPinnedStatus(for: page)
    }
}

enum CatalogKind { case artist, album }

struct CatalogView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.cmvTheme) private var theme
    @Query(sort: \MediaSourceRecord.displayName) private var sources: [MediaSourceRecord]
    let kind: CatalogKind
    @State private var tracks: [Track] = []
    @State private var groups: [(key: String, value: [Track])] = []
    @State private var groupsByKey: [String: [Track]] = [:]
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var loadGeneration = 0
    @State private var loadingGeneration: Int?
    private let pageSize = 500

    var body: some View {
        ScrollView {
            Group {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                    ForEach(groups, id: \.key) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(group.key, systemImage: kind == .artist ? "person.2" : "square.stack").font(.headline)
                            Text("\(group.value.count) 首").font(.caption).foregroundStyle(.secondary)
                            Text(group.value.prefix(3).map(\.title).joined(separator: "、"))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            if !group.value.isEmpty {
                                Button("播放", systemImage: "play.fill") { playCompleteGroup(group) }
                                    .buttonStyle(.bordered).frame(minHeight: 44).accessibilityLabel("播放\(group.key)")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16).cloudSurface().tint(theme.primary)
                    }
                }
                if hasMore {
                    LazyVStack {
                        Color.clear.frame(height: 1).accessibilityHidden(true)
                            .task(id: tracks.count) { await loadNextPage(generation: loadGeneration) }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(kind == .artist ? "歌手" : "專輯")
        .overlay {
            if tracks.isEmpty && !isLoading {
                if let error = appModel.libraryReadError {
                    ContentUnavailableView("無法載入曲庫", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ContentUnavailableView(kind == .artist ? "尚無歌手" : "尚無專輯",
                                           systemImage: kind == .artist ? "person.2" : "square.stack",
                                           description: Text("加入音樂並完成索引後，內容會出現在這裡。"))
                }
            }
        }
        .task { await resetAndLoad() }
        .onChange(of: sources.map(\.updatedAt)) { _, _ in Task { @MainActor in await resetAndLoad() } }
    }

    @MainActor private func resetAndLoad() async {
        loadGeneration &+= 1
        let generation = loadGeneration
        loadingGeneration = nil
        isLoading = false
        tracks = []
        groups = []
        groupsByKey = [:]
        hasMore = true
        await loadNextPage(generation: generation)
    }

    @MainActor private func loadNextPage(generation: Int) async {
        guard hasMore, generation == loadGeneration else { return }
        if loadingGeneration == generation { return }
        loadingGeneration = generation
        isLoading = true
        let activityID = appModel.beginBackgroundActivity(kind: .library,
                                                           title: kind == .artist ? "正在整理歌手" : "正在整理專輯")
        defer {
            appModel.endBackgroundActivity(activityID)
            if loadingGeneration == generation {
                loadingGeneration = nil
                isLoading = false
            }
        }
        let page = await appModel.searchTracks(query: "", context: context,
                                               limit: pageSize, offset: tracks.count)
        guard !Task.isCancelled, generation == loadGeneration else { return }
        let existingIDs = Set(tracks.map(\.id))
        let uniquePage = page.filter { !existingIDs.contains($0.id) }
        if !page.isEmpty, uniquePage.isEmpty { hasMore = false; return }
        let catalogKind = kind
        let additions = await Task.detached(priority: .utility) {
            Dictionary(grouping: uniquePage) { track in
                catalogKind == .artist
                    ? (track.artist.isEmpty ? "未知歌手" : track.artist)
                    : "\(track.album.isEmpty ? "未知專輯" : track.album) · \(track.albumArtist.isEmpty ? (track.artist.isEmpty ? "未知歌手" : track.artist) : track.albumArtist)"
            }
        }.value
        guard !Task.isCancelled, generation == loadGeneration else { return }
        for (key, newTracks) in additions { groupsByKey[key, default: []].append(contentsOf: newTracks) }
        groups = groupsByKey.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
        tracks.append(contentsOf: uniquePage)
        hasMore = page.count == pageSize
    }

    @MainActor private func playCompleteGroup(_ group: (key: String, value: [Track])) {
        guard let sample = group.value.first else { return }
        Task { @MainActor in
            let activityID = appModel.beginBackgroundActivity(kind: .playback, title: "正在準備播放", detail: group.key)
            defer { appModel.endBackgroundActivity(activityID) }

            let query = kind == .artist ? sample.artist : sample.album
            var offset = 0
            var matchingTracks: [Track] = []
            var seenIDs = Set<UUID>()
            while !Task.isCancelled {
                let page = await appModel.searchTracks(query: query, context: context, limit: pageSize, offset: offset)
                for track in page where catalogKey(for: track) == group.key && seenIDs.insert(track.id).inserted {
                    matchingTracks.append(track)
                }
                guard page.count == pageSize else { break }
                offset += page.count
            }
            guard !matchingTracks.isEmpty else { return }
            appModel.play(tracks: matchingTracks, context: context)
        }
    }

    private func catalogKey(for track: Track) -> String {
        if kind == .artist { return track.artist.isEmpty ? "未知歌手" : track.artist }
        let album = track.album.isEmpty ? "未知專輯" : track.album
        let artist = track.albumArtist.isEmpty ? (track.artist.isEmpty ? "未知歌手" : track.artist) : track.albumArtist
        return "\(album) · \(artist)"
    }
}

struct FavoriteTracksView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @State private var tracks: [Track] = []
    @State private var isLoading = false
    @State private var hasMore = true
    private let pageSize = 200

    var body: some View {
        ScrollView { TrackRows(tracks: tracks, onLast: { await loadNextPage() }).padding(24) }
            .navigationTitle("最愛")
            .task { await loadNextPage() }
            .overlay {
                if tracks.isEmpty && isLoading { ProgressView("正在讀取最愛") }
                else if tracks.isEmpty, let error = appModel.libraryReadError {
                    ContentUnavailableView("無法載入最愛", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if tracks.isEmpty {
                    ContentUnavailableView("還沒有最愛歌曲", systemImage: "heart", description: Text("在歌曲清單裡點選愛心即可收藏。"))
                }
            }
    }

    @MainActor private func loadNextPage() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        let activityID = appModel.beginBackgroundActivity(kind: .library, title: "正在讀取最愛")
        defer { appModel.endBackgroundActivity(activityID); isLoading = false }
        let page = await appModel.favoriteTracks(context: context, limit: pageSize, offset: tracks.count)
        guard !Task.isCancelled else { return }
        let existingIDs = Set(tracks.map(\.id))
        let uniquePage = page.filter { !existingIDs.contains($0.id) }
        if !page.isEmpty, uniquePage.isEmpty { hasMore = false; return }
        tracks.append(contentsOf: uniquePage)
        hasMore = page.count == pageSize
        await appModel.refreshPinnedStatus(for: page)
    }
}

private struct TrackRows: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.cmvTheme) private var theme
    let tracks: [Track]
    let onLast: (() async -> Void)?

    init(tracks: [Track], onLast: (() async -> Void)? = nil) {
        self.tracks = tracks
        self.onLast = onLast
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(tracks.indices, id: \.self) { index in
                let track = tracks[index]
                let isCurrent = track.id == appModel.currentTrackID
                HStack {
                    Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary).frame(width: 28, alignment: .trailing)
                    VStack(alignment: .leading) {
                        Text(track.title)
                        HStack(spacing: 4) {
                            Text(track.artist).lineLimit(1)
                            if let status = trackStatusText(track, pinnedTrackIDs: appModel.pinnedTrackIDs, isCurrent: isCurrent) {
                                Text("· \(status)").lineLimit(1)
                            }
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    StarRatingControl(rating: appModel.rating(for: track), width: 112) { rating in
                        appModel.setRating(track, rating: rating, context: context)
                    }
                    Button { appModel.addToPlaybackQueue([track], context: context) } label: { Image(systemName: "text.badge.plus") }
                        .buttonStyle(.borderless).frame(width: 44, height: 44)
                        .accessibilityLabel("將\(track.title)加入接下來播放")
                    Button { appModel.play(tracks: tracks, startingAt: index, context: context) } label: { Image(systemName: "play.circle.fill") }
                        .buttonStyle(.borderless).frame(width: 44, height: 44).accessibilityLabel("播放\(track.title)")
                    Image(systemName: "heart.fill").foregroundStyle(theme.primary)
                }
                .frame(minHeight: 48).padding(.horizontal, 12)
                .background(isCurrent ? theme.primary.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
                .task { if index == tracks.count - 1 { await onLast?() } }
            }
        }
    }
}

struct PlaylistHubView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @State private var playlists: [Playlist] = []
    @State private var editingPlaylist: Playlist?
    @State private var editedName = ""

    var body: some View {
        List {
            ForEach(playlists) { playlist in
                HStack {
                    Image(systemName: "music.note.list")
                    VStack(alignment: .leading) {
                        Text(playlist.name)
                        Text("\(playlist.trackIDs.count) 首歌曲").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !playlist.trackIDs.isEmpty {
                        Button("加入接下來播放", systemImage: "text.badge.plus") {
                            appModel.addPlaylistToPlaybackQueue(playlist, context: context)
                        }
                        .labelStyle(.iconOnly).frame(width: 44, height: 44)
                        Button("播放", systemImage: "play.fill") { appModel.play(playlist: playlist, context: context) }
                            .labelStyle(.iconOnly).frame(width: 44, height: 44)
                    }
                }
                .frame(minHeight: 52)
                .contextMenu {
                    if !playlist.trackIDs.isEmpty {
                        Button("立即播放", systemImage: "play.fill") { appModel.play(playlist: playlist, context: context) }
                        Button("加入接下來播放", systemImage: "text.badge.plus") {
                            appModel.addPlaylistToPlaybackQueue(playlist, context: context)
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("刪除", role: .destructive) {
                        Task { await appModel.deletePlaylist(playlist, context: context); reload() }
                    }
                    Button("重新命名") { editedName = playlist.name; editingPlaylist = playlist }.tint(.orange)
                }
            }
        }
        .navigationTitle("歌單")
        .toolbar {
            Button("新增歌單", systemImage: "plus") {
                Task { @MainActor in guard await appModel.createPlaylist(context: context) != nil else { return }; reload() }
            }
        }
        .overlay {
            if playlists.isEmpty {
                if let error = appModel.libraryReadError {
                    ContentUnavailableView("無法載入歌單", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ContentUnavailableView("尚未建立歌單", systemImage: "music.note.list", description: Text("建立歌單後，可以從歌曲的更多操作加入曲目。"))
                }
            }
        }
        .alert("重新命名歌單", isPresented: Binding(
            get: { editingPlaylist != nil },
            set: { if !$0 { editingPlaylist = nil } }
        )) {
            TextField("歌單名稱", text: $editedName)
            Button("取消", role: .cancel) { editingPlaylist = nil }
            Button("儲存") {
                guard let editingPlaylist else { return }
                let name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                Task {
                    await appModel.renamePlaylist(editingPlaylist, name: name, context: context)
                    self.editingPlaylist = nil
                    reload()
                }
            }
            .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: { Text("名稱不能是空白。") }
        .task(id: appModel.playlistRevision) { playlists = await appModel.playlists(context: context) }
    }

    private func reload() { Task { playlists = await appModel.playlists(context: context) } }
}

struct QueueView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.cmvTheme) private var theme
    var body: some View {
        let queue = appModel.displayQueue.tracks
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("接下來播放").font(.title2.bold())
                Spacer()
                Button("清除") { appModel.clearPlaybackQueue() }.disabled(queue.isEmpty)
            }
            if queue.isEmpty {
                ContentUnavailableView("佇列是空的", systemImage: "music.note.list",
                                       description: Text("從歌曲、多選工具列或歌單選擇「加入接下來播放」。"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(queue.indices, id: \.self) { index in
                            let track = queue[index]
                            HStack(spacing: 12) {
                                Button { appModel.play(tracks: queue, startingAt: index, context: context) } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle().fill(theme.secondary)
                                            Image(systemName: track.mediaKind == .video ? "film.fill" : "cloud.moon.fill")
                                                .foregroundStyle(theme.metal)
                                        }
                                        .frame(width: 44, height: 44)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(track.title).lineLimit(1)
                                            Text("\(track.artist) · \(track.album)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                            if let status = trackStatusText(track, pinnedTrackIDs: appModel.pinnedTrackIDs,
                                                                            isCurrent: track.id == appModel.currentTrackID) {
                                                Text(status).font(.caption2).foregroundStyle(theme.metal)
                                            }
                                        }
                                        Spacer(minLength: 4)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("播放 \(track.title)，\(track.artist)")
                                StarRatingControl(rating: appModel.rating(for: track), width: 100) { rating in
                                    appModel.setRating(track, rating: rating, context: context)
                                }
                            }
                            .frame(minHeight: 60).padding(.vertical, 9).padding(.horizontal, 10)
                            .background(track.id == appModel.currentTrackID ? theme.primary.opacity(0.16) : .clear,
                                        in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 18).padding(.horizontal, 12).background(.clear)
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    var body: some View {
        #if os(macOS)
        NavigationStack { settingsForm }
        #else
        settingsForm
        #endif
    }

    private var settingsForm: some View {
        @Bindable var appModel = appModel
        return Form {
            Picker("天空主題", selection: $appModel.selectedTheme) {
                ForEach(CMVThemeID.allCases) { Text($0.name).tag($0) }
            }
            Section("曲庫") {
                NavigationLink { MusicSourcesSettingsView() } label: {
                    Label("音樂來源", systemImage: "externaldrive.connected.to.line.below")
                }
                Text("加入、重新授權與重新索引都集中在這裡，不占用日常導覽。").font(.caption).foregroundStyle(.secondary)
            }
            Section("智慧快取") {
                LabeledContent("預設上限", value: "10 GB")
                Text("釘選內容不會被智慧快取淘汰。")
            }
            Section("隱私") { Text("聲學分析與 Smart DJ 全部在裝置上完成。") }
        }
        .formStyle(.grouped)
        .navigationTitle("設定")
    }
}

struct MusicSourcesSettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.cmvTheme) private var theme
    @Query(sort: \MediaSourceRecord.displayName) private var sources: [MediaSourceRecord]
    @State private var reauthorizationSource: MediaSourceRecord?
    @State private var isReauthorizationPickerPresented = false

    var body: some View {
        Form {
            Section {
                LabeledContent("來源", value: "\(sources.count)")
                LabeledContent("可使用", value: "\(sources.count { $0.status == .available })")
                if issueCount > 0 { LabeledContent("需要處理", value: "\(issueCount)").foregroundStyle(.orange) }
            } header: { Text("曲庫連線") } footer: {
                Text("NAS 暫時離線不會清除曲庫；重新授權也會保留既有歌曲與歌單。")
            }

            Section {
                Button { appModel.showingImporter = true } label: { Label("加入音樂來源", systemImage: "plus.circle.fill") }
                if !sources.isEmpty {
                    Button("重試所有來源", systemImage: "arrow.clockwise") {
                        for source in sources where source.status != .scanning { appModel.restoreAndScan(source, context: context) }
                    }
                    .disabled(sources.allSatisfy { $0.status == .scanning })
                }
            }

            Section("來源明細") {
                if sources.isEmpty {
                    ContentUnavailableView("尚未加入來源", systemImage: "externaldrive.badge.plus",
                                           description: Text("加入本機資料夾，或先在 Finder／檔案 App 連接 NAS。"))
                } else {
                    ForEach(sources) { source in sourceRow(source) }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("音樂來源")
        .tint(theme.primary)
        .fileImporter(isPresented: $isReauthorizationPickerPresented, allowedContentTypes: [.folder]) { result in
            guard let source = reauthorizationSource else { return }
            reauthorizationSource = nil
            switch result {
            case .success(let url):
                appModel.reauthorizeSource(source, with: url, context: context)
            case .failure(let error):
                if !isLibraryImporterCancellation(error) {
                    appModel.errorMessage = "無法重新授權來源：\(error.localizedDescription)"
                }
            }
        }
    }

    @ViewBuilder
    private func sourceRow(_ source: MediaSourceRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: statusSymbol(source.status)).foregroundStyle(statusColor(source.status)).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(source.displayName).lineLimit(1)
                Text(statusText(source.status)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            if source.status == .permissionRequired {
                Button("重新授權") { reauthorizationSource = source; isReauthorizationPickerPresented = true }
            } else if source.status == .scanning {
                Label("索引中", systemImage: "arrow.trianglehead.2.clockwise.rotate.90").foregroundStyle(.secondary)
            } else {
                Button(source.status == .available ? "重新索引" : "重試") { appModel.restoreAndScan(source, context: context) }
            }
        }
        .frame(minHeight: 44)
    }

    private var issueCount: Int { sources.count { $0.status == .permissionRequired || $0.status == .offline } }
    private func statusColor(_ status: MediaSourceStatus) -> Color {
        switch status { case .available: .green; case .scanning: .yellow; case .offline: .orange; case .permissionRequired: .red }
    }
    private func statusSymbol(_ status: MediaSourceStatus) -> String {
        switch status {
        case .available: "checkmark.circle.fill"
        case .scanning: "arrow.trianglehead.2.clockwise.rotate.90"
        case .offline: "externaldrive.badge.exclamationmark"
        case .permissionRequired: "lock.trianglebadge.exclamationmark"
        }
    }
    private func statusText(_ status: MediaSourceStatus) -> String {
        switch status { case .available: "可使用"; case .scanning: "正在索引"; case .offline: "來源離線"; case .permissionRequired: "需要重新授權" }
    }
}

struct PlaceholderView: View {
    let title: String
    let symbol: String
    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text("這個模組已接上原生資料層，將在後續里程碑完成操作。"))
    }
}
