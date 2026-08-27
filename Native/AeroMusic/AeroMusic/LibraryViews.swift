import SwiftUI
import SwiftData
import AeroDomain
import AeroLibrary
import AeroThemes
import UniformTypeIdentifiers

struct SidebarView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.aeroTheme) private var theme
    @Query(sort: \MediaSourceRecord.displayName) private var sources: [MediaSourceRecord]
    @State private var reauthorizationSource: MediaSourceRecord?
    @State private var isReauthorizationPickerPresented = false

    var body: some View {
        @Bindable var appModel = appModel
        List(selection: $appModel.selection) {
            Section {
                ForEach(LibraryDestination.allCases.filter { $0 != .settings }) { destination in
                    Label(destination.title, systemImage: destination.symbol).tag(destination)
                }
            }
            Section("音樂來源") {
                ForEach(sources) { source in
                    HStack {
                        Circle().fill(statusColor(source.status)).frame(width: 8, height: 8)
                        VStack(alignment: .leading) {
                            Text(source.displayName).lineLimit(1)
                            Text(statusText(source.status)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if source.status != .available {
                            HStack(spacing: 4) {
                                if source.status == .permissionRequired {
                                    Button("重新授權") {
                                        reauthorizationSource = source
                                        isReauthorizationPickerPresented = true
                                    }
                                    .buttonStyle(.borderless)
                                }
                                Button("重試") { appModel.restoreAndScan(source, context: context) }
                                    .buttonStyle(.borderless)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                        }
                    }
                }
                Button { appModel.showingImporter = true } label: { Label("加入音樂來源", systemImage: "plus.circle") }
            }
            Section { Label("設定", systemImage: "gearshape").tag(LibraryDestination.settings) }
        }
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial.opacity(0.55))
        .navigationTitle("AeroMusic")
        .safeAreaInset(edge: .bottom) {
            if let progress = appModel.scanProgress {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView()
                    Text("正在索引 \(progress.processed) 首").font(.caption)
                    Text(progress.currentPath).font(.caption2).lineLimit(1).foregroundStyle(.secondary)
                }.padding().cloudSurface().padding(8)
            }
        }
        .tint(theme.primary)
        .task { await appModel.refreshSourceStatuses(sources, context: context) }
        .fileImporter(
            isPresented: $isReauthorizationPickerPresented,
            allowedContentTypes: [.folder]
        ) { result in
            guard let source = reauthorizationSource else { return }
            reauthorizationSource = nil
            guard case let .success(url) = result else { return }
            appModel.reauthorizeSource(source, with: url, context: context)
        }
    }

    private func statusColor(_ status: MediaSourceStatus) -> Color {
        switch status { case .available: .green; case .scanning: .yellow; case .offline: .orange; case .permissionRequired: .red }
    }
    private func statusText(_ status: MediaSourceStatus) -> String {
        switch status { case .available: "離線可瀏覽"; case .scanning: "正在索引"; case .offline: "來源離線"; case .permissionRequired: "需要重新授權" }
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
    @Environment(\.aeroTheme) private var theme
    @Environment(VideoWindowStore.self) private var videoWindowStore
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @State private var showingVideoImporter = false
    @State private var videoSelection: VideoSelection?
    var body: some View {
        let current = appModel.currentTrack
        ScrollView {
            VStack(spacing: 24) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 34) {
                        AlbumWorldView(size: 300, artworkData: current?.artworkData)
                        nowPlayingControls
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        AlbumWorldView(size: 220, artworkData: current?.artworkData)
                        nowPlayingControls
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)
                TrackListView()
            }.padding(24)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("夜航收藏")
        .fileImporter(isPresented: $showingVideoImporter, allowedContentTypes: [.movie]) { result in
            guard case let .success(url) = result else { return }
            videoWindowStore.present(url: url)
            #if os(macOS)
            openWindow(id: "video")
            #else
            videoSelection = VideoSelection(url: url)
            #endif
        }
        #if !os(macOS)
        .sheet(item: $videoSelection) { selection in
            NavigationStack {
                VideoExperienceView(url: selection.url) {
                    appModel.advanceAfterVideo(context: context)
                }
                    .padding()
                    .onDisappear {
                        if appModel.videoURL == selection.url {
                            appModel.stopVideoPlayback()
                        }
                        videoWindowStore.clear()
                    }
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { videoSelection = nil; videoWindowStore.clear() } } }
            }
        }
        #endif
    }

    @ViewBuilder private var nowPlayingControls: some View {
        let current = appModel.currentTrack
        VStack(alignment: .leading, spacing: 12) {
            Text("現在收聽").font(.headline).foregroundStyle(theme.metal)
            Text(current?.title ?? "夜航收藏")
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Text(current?.artist ?? "私人曲庫").font(.title3).foregroundStyle(.secondary).lineLimit(1)
            HStack {
                Button(appModel.playback.isPlaying ? "暫停" : (appModel.videoURL == nil ? "播放" : "影片播放中"), systemImage: appModel.playback.isPlaying ? "pause.fill" : (appModel.videoURL == nil ? "play.fill" : "film")) {
                    if appModel.playback.isPlaying { appModel.playback.pause() } else { appModel.playOrResume(context: context) }
                }
                .disabled(appModel.videoURL != nil)
                .accessibilityHint(appModel.videoURL == nil ? "播放目前曲目" : "請使用影片播放控制項")
                Button("隨機播放", systemImage: "shuffle") { appModel.playback.toggleShuffle() }
                    .disabled(appModel.videoURL != nil)
                SleepTimerMenu()
                Button("開啟影片", systemImage: "film") { showingVideoImporter = true }
            }.buttonStyle(.borderedProminent).controlSize(.large)
        }
    }
}

struct VideoSelection: Identifiable {
    let url: URL
    var id: URL { url }
}

struct TrackListView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.aeroTheme) private var theme
    @State private var tracks: [Track] = []
    @State private var search = ""
    @State private var playlists: [Playlist] = []
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var searchGeneration = 0
    @State private var loadingGeneration: Int?
    private let pageSize = 200

    var body: some View {
        LazyVStack(spacing: 2) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                let isCurrent = track.id == appModel.currentTrackID
                HStack(spacing: 14) {
                    Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary).frame(width: 28, alignment: .trailing)
                    Image(systemName: track.mediaKind == .video ? "film" : (isCurrent ? "waveform" : "music.note"))
                        .foregroundStyle(isCurrent ? theme.primary : .secondary)
                    VStack(alignment: .leading) {
                        Text(track.title).lineLimit(1)
                        Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(track.album).foregroundStyle(.secondary).lineLimit(1)
                    Button {
                        appModel.play(tracks: tracks, startingAt: index, context: context)
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(theme.primary)
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("播放\(track.title)")
                    Menu {
                        Section("評分") {
                            ForEach(1...5, id: \.self) { rating in
                                Button { appModel.setRating(track, rating: rating, context: context) } label: {
                                    Label("\(rating) 顆星", systemImage: rating <= track.rating ? "star.fill" : "star")
                                }
                            }
                            if track.rating > 0 {
                                Button("清除評分", systemImage: "star.slash") {
                                    appModel.setRating(track, rating: 0, context: context)
                                }
                            }
                        }
                        if !playlists.isEmpty {
                            Section("加入歌單") {
                                ForEach(playlists) { playlist in
                                    Button(playlist.name) { appModel.addTrack(track, to: playlist, context: context) }
                                }
                            }
                        }
                        Button {
                            appModel.togglePinned(track, context: context)
                        } label: {
                            Label(appModel.pinnedTrackIDs.contains(track.id) ? "取消釘選離線" : "釘選離線",
                                  systemImage: appModel.pinnedTrackIDs.contains(track.id) ? "pin.slash" : "pin")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityLabel("歌曲操作")
                    }.frame(width: 44, height: 44)
                    Button {
                        appModel.setFavorite(track, context: context)
                        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
                            tracks[index].isFavorite.toggle()
                        }
                    } label: {
                        Image(systemName: track.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(track.isFavorite ? theme.primary : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(track.isFavorite ? "移除最愛" : "加入最愛")
                }
                .frame(minHeight: 48)
                .padding(.horizontal, 12)
                .background(isCurrent ? theme.primary.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 12))
                .task {
                    if index == tracks.count - 1 { await loadNextPage(generation: searchGeneration) }
                }
            }
            if isLoading && !tracks.isEmpty {
                ProgressView("載入更多歌曲…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            if tracks.isEmpty {
                if isLoading {
                    ProgressView("讀取曲庫…").frame(maxWidth: .infinity).padding(.vertical, 80)
                } else {
                    ContentUnavailableView("尚未加入音樂", systemImage: "cloud.moon", description: Text("從側邊欄加入本機或 NAS 資料夾。"))
                        .frame(minHeight: 220)
                }
            }
        }
        .padding(12)
        .cloudSurface()
        .searchable(text: $search, prompt: "搜尋歌曲、歌手或專輯")
        .task(id: search) { await fetchPage() }
        .task { playlists = await appModel.playlists(context: context) }
    }

    @MainActor private func fetchPage() async {
        if !search.isEmpty { try? await Task.sleep(for: .milliseconds(120)) }
        guard !Task.isCancelled else { return }
        searchGeneration &+= 1
        let generation = searchGeneration
        tracks = []
        hasMore = true
        await loadNextPage(generation: generation)
    }

    @MainActor private func loadNextPage(generation: Int) async {
        guard hasMore else { return }
        guard loadingGeneration == nil || loadingGeneration == generation else { return }
        loadingGeneration = generation
        isLoading = true
        defer {
            if loadingGeneration == generation {
                loadingGeneration = nil
                isLoading = false
            }
        }
        let page = await appModel.searchTracks(query: search, context: context,
                                               limit: pageSize, offset: tracks.count)
        guard !Task.isCancelled, generation == searchGeneration else { return }
        guard !page.isEmpty else {
            hasMore = false
            return
        }
        tracks.append(contentsOf: page)
        hasMore = page.count == pageSize
        await appModel.refreshPinnedStatus(for: page)
    }
}

enum CatalogKind { case artist, album }

struct CatalogView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.aeroTheme) private var theme
    let kind: CatalogKind
    @State private var tracks: [Track] = []
    @State private var isLoading = false
    @State private var hasMore = true
    private let pageSize = 500

    var body: some View {
        ScrollView {
            Group {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                    ForEach(groups, id: \.key) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(group.key, systemImage: kind == .artist ? "person.2" : "square.stack")
                                .font(.headline)
                            Text("\(group.value.count) 首").font(.caption).foregroundStyle(.secondary)
                            Text(group.value.prefix(3).map(\.title).joined(separator: "、"))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            if let first = group.value.first {
                                Button("播放", systemImage: "play.fill") {
                                    appModel.play(track: first, context: context)
                                }
                                .buttonStyle(.bordered).frame(minHeight: 44)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .cloudSurface()
                        .tint(theme.primary)
                    }
                }
                if hasMore {
                    ProgressView("載入更多…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .task(id: tracks.count) { await loadNextPage() }
                }
            }
            .padding(24)
        }
        .navigationTitle(kind == .artist ? "歌手" : "專輯")
        .task {
            tracks = []
            hasMore = true
            await loadNextPage()
        }
    }

    @MainActor private func loadNextPage() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        let page = await appModel.searchTracks(query: "", context: context,
                                               limit: pageSize, offset: tracks.count)
        guard !Task.isCancelled else { return }
        tracks.append(contentsOf: page)
        hasMore = page.count == pageSize
    }

    private var groups: [(key: String, value: [Track])] {
        let grouped = Dictionary(grouping: tracks) { track in
            kind == .artist ? track.artist : "\(track.album) · \(track.albumArtist.isEmpty ? track.artist : track.albumArtist)"
        }
        return grouped.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
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
        ScrollView {
            TrackRows(tracks: tracks, onLast: { await loadNextPage() }).padding(24)
            if isLoading && !tracks.isEmpty {
                ProgressView("載入更多最愛…").frame(maxWidth: .infinity).padding(.vertical, 12)
            }
        }
            .navigationTitle("最愛")
            .task { await loadNextPage() }
            .overlay {
                if tracks.isEmpty {
                    if isLoading {
                        ProgressView("讀取最愛…")
                    } else {
                        ContentUnavailableView("還沒有最愛歌曲", systemImage: "heart", description: Text("在歌曲清單裡點選愛心即可收藏。"))
                    }
                }
            }
        }

    @MainActor private func loadNextPage() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        let page = await appModel.favoriteTracks(context: context, limit: pageSize, offset: tracks.count)
        guard !Task.isCancelled else { return }
        tracks.append(contentsOf: page)
        hasMore = page.count == pageSize
        await appModel.refreshPinnedStatus(for: page)
    }
}

private struct TrackRows: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    let tracks: [Track]
    let onLast: (() async -> Void)?

    init(tracks: [Track], onLast: (() async -> Void)? = nil) {
        self.tracks = tracks
        self.onLast = onLast
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                let isCurrent = track.id == appModel.currentTrackID
                HStack {
                    Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary).frame(width: 28, alignment: .trailing)
                    VStack(alignment: .leading) { Text(track.title); Text(track.artist).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Button { appModel.play(tracks: tracks, startingAt: index, context: context) } label: {
                        Image(systemName: "play.circle.fill")
                    }.buttonStyle(.borderless).frame(width: 44, height: 44).accessibilityLabel("播放\(track.title)")
                    Image(systemName: "heart.fill").foregroundStyle(.pink)
                }
                .frame(minHeight: 48).padding(.horizontal, 12)
                .background(isCurrent ? Color.accentColor.opacity(0.12) : .clear,
                            in: RoundedRectangle(cornerRadius: 10))
                .task {
                    if index == tracks.count - 1 { await onLast?() }
                }
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
                        Button("播放", systemImage: "play.fill") {
                            appModel.play(playlist: playlist, context: context)
                        }
                        .labelStyle(.iconOnly).frame(width: 44, height: 44)
                    }
                }
                .frame(minHeight: 52)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("刪除", role: .destructive) {
                        Task {
                            await appModel.deletePlaylist(playlist, context: context)
                            reload()
                        }
                    }
                    Button("重新命名") {
                        editedName = playlist.name
                        editingPlaylist = playlist
                    }
                    .tint(.orange)
                }
            }
        }
        .navigationTitle("歌單")
        .toolbar { Button("新增歌單", systemImage: "plus") { appModel.createPlaylist(context: context); reload() } }
        .overlay {
            if playlists.isEmpty {
                ContentUnavailableView("尚未建立歌單", systemImage: "music.note.list", description: Text("建立歌單後，可以從歌曲的更多操作加入曲目。"))
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
        } message: {
            Text("名稱不能是空白。")
        }
        .task { reload() }
    }

    private func reload() {
        Task { playlists = await appModel.playlists(context: context) }
    }
}

struct QueueView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.aeroTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("接下來播放").font(.title2.bold())
                Spacer()
                Button("清除") { appModel.playback.clearQueue() }
                    .disabled(appModel.playback.queue.tracks.isEmpty)
            }
            if appModel.playback.queue.tracks.isEmpty {
                ContentUnavailableView("佇列是空的", systemImage: "music.note.list", description: Text("從曲庫選擇歌曲開始播放。"))
            }
            ForEach(Array(appModel.playback.queue.tracks.enumerated()), id: \.element.id) { index, track in
                HStack(spacing: 12) {
                    ZStack { Circle().fill(theme.secondary); Image(systemName: "cloud.moon.fill").foregroundStyle(theme.metal) }
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading) { Text(track.title); Text(track.artist).font(.caption).foregroundStyle(.secondary) }
                    Spacer(); Image(systemName: "line.3.horizontal")
                }.frame(minHeight: 52).padding(8)
                .background(track.id == appModel.currentTrackID ? theme.primary.opacity(0.16) : .clear,
                            in: RoundedRectangle(cornerRadius: 14))
            }
            Spacer()
        }.padding(18).background(.ultraThinMaterial.opacity(0.55))
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    var body: some View {
        @Bindable var appModel = appModel
        Form {
            Picker("天空主題", selection: $appModel.selectedTheme) {
                ForEach(AeroThemeID.allCases) { Text($0.name).tag($0) }
            }
            Section("智慧快取") {
                LabeledContent("預設上限", value: "10 GB")
                Text("釘選內容不會被智慧快取淘汰。")
            }
            Section("隱私") { Text("聲學分析與 Smart DJ 全部在裝置上完成。") }
        }.formStyle(.grouped).navigationTitle("設定")
    }
}

struct PlaceholderView: View {
    let title: String; let symbol: String
    var body: some View { ContentUnavailableView(title, systemImage: symbol, description: Text("這個模組已接上原生資料層，將在後續里程碑完成操作。")) }
}
