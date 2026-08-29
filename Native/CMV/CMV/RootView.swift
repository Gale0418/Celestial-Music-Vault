import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CMVDomain
import CMVLibrary
import CMVThemes

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(VideoWindowStore.self) private var videoWindowStore
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    #else
    @State private var videoSelection: VideoSelection?
    #endif

    var body: some View {
        @Bindable var appModel = appModel
        GeometryReader { proxy in
            Group {
                #if os(iOS)
                if proxy.size.width < 760 { CompactRootView() } else { WideRootView() }
                #else
                WideRootView()
                #endif
            }
            .environment(\.cmvTheme, .palette(appModel.selectedTheme))
            .preferredColorScheme(.dark)
            .safeAreaInset(edge: .top, spacing: 0) { ErrorStatusBanner() }
            .fileImporter(
                isPresented: $appModel.showingImporter,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: true
            ) { result in
                if case let .success(urls) = result { appModel.addSources(urls, context: modelContext) }
                if case let .failure(error) = result { appModel.errorMessage = error.localizedDescription }
            }
            .onChange(of: appModel.videoURL) { _, url in
                guard let url else {
                    videoWindowStore.clear()
                    #if os(iOS)
                    videoSelection = nil
                    #else
                    dismissWindow(id: "video")
                    #endif
                    return
                }
                videoWindowStore.present(url: url)
                #if os(macOS)
                openWindow(id: "video")
                #else
                videoSelection = VideoSelection(url: url)
                #endif
            }
            #if os(iOS)
            .sheet(item: $videoSelection) { selection in
                NavigationStack {
                    VideoExperienceView(url: selection.url) {
                        appModel.advanceAfterVideo(context: modelContext)
                    }
                        .padding()
                        .onDisappear {
                            if appModel.videoURL == selection.url {
                                appModel.stopVideoPlayback()
                                videoWindowStore.clear()
                            }
                        }
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("完成") {
                                    videoSelection = nil
                                    appModel.stopVideoPlayback()
                                    videoWindowStore.clear()
                                }
                            }
                        }
                }
            }
            #endif
        }
    }
}

private struct WideRootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.cmvTheme) private var theme

    var body: some View {
        @Bindable var appModel = appModel
        ZStack {
            theme.background
            NavigationSplitView {
                SidebarView()
                    .background(CelestialBackground(starCount: 18))
                    .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 275)
            } content: {
                LibraryStageView()
                    .background(CelestialBackground(starCount: 24, starSeedOffset: 18))
                    .navigationSplitViewColumnWidth(min: 560, ideal: 800)
            } detail: {
                QueueView()
                    .background(CelestialBackground(starCount: 16, starSeedOffset: 42))
                    .navigationSplitViewColumnWidth(min: 250, ideal: 310, max: 380)
            }
            .navigationSplitViewStyle(.balanced)
            .modifier(TransparentNavigationSplitBackground())
            .background(.clear)
        }
        #if os(macOS)
        .dropDestination(for: URL.self) { urls, _ in
            let directories = urls.filter(\.hasDirectoryPath)
            appModel.addSources(directories, context: modelContext)
            return !directories.isEmpty
        }
        #endif
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                BackgroundActivityRail()
                PlayerBar()
            }
        }
        .tint(theme.primary)
    }
}

private struct TransparentNavigationSplitBackground: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.containerBackground(.clear, for: .navigationSplitView)
        #else
        content
        #endif
    }
}

#if os(iOS)
private struct CompactRootView: View {
    @Environment(\.cmvTheme) private var theme
    @State private var showingNowPlaying = false
    var body: some View {
        TabView {
            NavigationStack { NowPlayingView() }
                .tabItem { Label("聆聽", systemImage: "sparkles") }
            NavigationStack { CompactLibraryView() }
                .tabItem { Label("曲庫", systemImage: "music.note") }
            NavigationStack { PlaylistHubView() }
                .tabItem { Label("歌單", systemImage: "music.note.list") }
            NavigationStack { SettingsView() }
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .background(CelestialBackground())
        .tint(theme.primary)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                BackgroundActivityRail()
                MiniPlayerBar { showingNowPlaying = true }
            }
        }
        .sheet(isPresented: $showingNowPlaying) {
            NavigationStack { NowPlayingView() }
        }
    }
}

private struct CompactLibraryView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.cmvTheme) private var theme
    @Query(sort: \MediaSourceRecord.displayName) private var sources: [MediaSourceRecord]
    @State private var reauthorizationSource: MediaSourceRecord?
    @State private var isReauthorizationPickerPresented = false

    var body: some View {
        List {
            Section("瀏覽") {
                NavigationLink { TrackListView() } label: { Label("歌曲", systemImage: "music.note") }
                NavigationLink { CatalogView(kind: .album) } label: { Label("專輯", systemImage: "square.stack") }
                NavigationLink { CatalogView(kind: .artist) } label: { Label("歌手", systemImage: "person.2") }
                NavigationLink { FavoriteTracksView() } label: { Label("最愛", systemImage: "heart.fill") }
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
                        if source.status == .permissionRequired {
                            Button("重新授權") {
                                reauthorizationSource = source
                                isReauthorizationPickerPresented = true
                            }
                            .buttonStyle(.borderless)
                        }
                        Button(source.status == .available ? "重新索引" : "重試") {
                            appModel.restoreAndScan(source, context: context)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button { appModel.showingImporter = true } label: {
                    Label("加入音樂來源", systemImage: "plus.circle")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("曲庫")
        .tint(theme.primary)
        .fileImporter(isPresented: $isReauthorizationPickerPresented, allowedContentTypes: [.folder]) { result in
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
        switch status { case .available: "可使用"; case .scanning: "正在索引"; case .offline: "來源離線"; case .permissionRequired: "需要重新授權" }
    }
}
#endif
