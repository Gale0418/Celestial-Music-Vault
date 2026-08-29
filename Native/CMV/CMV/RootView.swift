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
    @Query(sort: \MediaSourceRecord.displayName) private var sources: [MediaSourceRecord]
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
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    ErrorStatusBanner()
                    SourceStatusBanner()
                }
            }
            .fileImporter(
                isPresented: $appModel.showingImporter,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: true
            ) { result in
                if case let .success(urls) = result { appModel.addSources(urls, context: modelContext) }
                if case let .failure(error) = result { appModel.errorMessage = error.localizedDescription }
            }
            .onChange(of: appModel.videoURL) { _, _ in
                updateVideoPresentation()
            }
            .onChange(of: appModel.videoPresentationMode) { _, _ in
                updateVideoPresentation()
            }
            .task { await appModel.refreshSourceStatuses(sources, context: modelContext) }
            #if os(iOS)
            .sheet(item: $videoSelection) { selection in
                NavigationStack {
                    VideoExperienceView(player: appModel.videoSession.player)
                        .padding()
                        .onDisappear {
                            if appModel.videoURL == selection.url,
                               appModel.videoPresentationMode == .separatePlayer {
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

    private func updateVideoPresentation() {
        guard let url = appModel.videoURL else {
            videoWindowStore.clear()
            #if os(iOS)
            videoSelection = nil
            #else
            dismissWindow(id: "video")
            #endif
            return
        }

        guard appModel.videoPresentationMode == .separatePlayer else {
            videoWindowStore.clear()
            appModel.selection = .nowPlaying
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
    @Environment(AppModel.self) private var appModel
    @Environment(\.cmvTheme) private var theme
    @State private var showingNowPlaying = false
    @State private var selectedTab: LibraryDestination = .nowPlaying
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { NowPlayingView() }
                .tabItem { Label("聆聽", systemImage: "sparkles") }
                .tag(LibraryDestination.nowPlaying)
            NavigationStack { CompactLibraryView() }
                .tabItem { Label("曲庫", systemImage: "music.note") }
                .tag(LibraryDestination.songs)
            NavigationStack { PlaylistHubView() }
                .tabItem { Label("歌單", systemImage: "music.note.list") }
                .tag(LibraryDestination.playlists)
            NavigationStack { SettingsView() }
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(LibraryDestination.settings)
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
        .onChange(of: appModel.videoURL) { _, _ in showMoonPortalIfNeeded() }
        .onChange(of: appModel.videoPresentationMode) { _, _ in showMoonPortalIfNeeded() }
        .onChange(of: appModel.selection) { _, destination in
            guard let destination else { return }
            switch destination {
            case .nowPlaying: selectedTab = .nowPlaying
            case .playlists: selectedTab = .playlists
            case .settings: selectedTab = .settings
            default: selectedTab = .songs
            }
        }
    }

    private func showMoonPortalIfNeeded() {
        guard appModel.videoURL != nil, appModel.videoPresentationMode == .moonPortal else { return }
        showingNowPlaying = false
        selectedTab = .nowPlaying
    }
}

private struct CompactLibraryView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.cmvTheme) private var theme

    var body: some View {
        List {
            Section("瀏覽") {
                NavigationLink { TrackListView() } label: { Label("歌曲", systemImage: "music.note") }
                NavigationLink { CatalogView(kind: .album) } label: { Label("專輯", systemImage: "square.stack") }
                NavigationLink { CatalogView(kind: .artist) } label: { Label("歌手", systemImage: "person.2") }
                NavigationLink { FavoriteTracksView() } label: { Label("最愛", systemImage: "heart.fill") }
            }
            Section("曲庫") {
                Button { appModel.showingImporter = true } label: {
                    Label("加入音樂", systemImage: "plus.circle")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("曲庫")
        .tint(theme.primary)
    }
}
#endif

private struct SourceStatusBanner: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.cmvTheme) private var theme
    @Query private var sources: [MediaSourceRecord]

    var body: some View {
        if issueCount > 0 {
            HStack(spacing: 12) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text(summary)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 12)
                Button("前往設定") { appModel.selection = .settings }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(.regularMaterial)
            .overlay(alignment: .bottom) {
                Rectangle().fill(theme.primary.opacity(0.35)).frame(height: 1)
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var issueCount: Int { permissionCount + offlineCount }
    private var permissionCount: Int { sources.count { $0.status == .permissionRequired } }
    private var offlineCount: Int { sources.count { $0.status == .offline } }
    private var summary: String {
        var parts: [String] = []
        if permissionCount > 0 { parts.append("\(permissionCount) 個來源需要重新授權") }
        if offlineCount > 0 { parts.append("\(offlineCount) 個來源目前離線") }
        return parts.joined(separator: "，")
    }
}
