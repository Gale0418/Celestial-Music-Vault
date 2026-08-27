import SwiftUI
import SwiftData
import AeroLibrary

@main
struct AeroMusicApp: App {
    private let container: ModelContainer?
    private let storageError: String?
    @State private var appModel = AppModel()
    @State private var videoWindowStore = VideoWindowStore()

    init() {
        do {
            container = try ModelContainer(for: MediaSourceRecord.self, TrackRecord.self, PlaylistRecord.self)
            storageError = nil
        } catch {
            container = nil
            storageError = error.localizedDescription
        }
    }

    @SceneBuilder
    var body: some Scene {
        scenes
    }

    @SceneBuilder
    private var scenes: some Scene {
        if let container {
            configuredScenes(container: container)
        } else {
            recoveryScene
        }
    }

    @SceneBuilder
    private func configuredScenes(container: ModelContainer) -> some Scene {
        mainWindow(container: container)
        #if os(macOS)
        videoWindow
        #endif
    }

    private var recoveryScene: some Scene {
        WindowGroup {
            StorageRecoveryView(message: storageError ?? "未知資料庫錯誤")
        }
    }

    @SceneBuilder
    private func mainWindow(container: ModelContainer) -> some Scene {
        #if os(macOS)
        WindowGroup {
            RootView()
                .environment(appModel)
                .modelContainer(container)
                .environment(videoWindowStore)
        }
        .defaultSize(width: 1_360, height: 860)
        .windowStyle(.hiddenTitleBar)
        #else
        WindowGroup {
            RootView()
                .environment(appModel)
                .modelContainer(container)
                .environment(videoWindowStore)
        }
        #endif
    }

    private struct StorageRecoveryView: View {
        let message: String

        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "externaldrive.badge.exclamationmark").font(.system(size: 44))
                Text("無法開啟 AeroMusic 曲庫").font(.title2.bold())
                Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Text("請確認磁碟可寫入後重新啟動 App。既有資料不會被覆寫。")
                    .font(.callout).multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(minWidth: 360, minHeight: 240)
        }
    }

    #if os(macOS)
    @SceneBuilder
    private var videoWindow: some Scene {
        WindowGroup("影片", id: "video") {
            VideoWindowView()
                .environment(videoWindowStore)
        }
        .defaultSize(width: 760, height: 520)
    }
    #endif
}
