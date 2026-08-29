import SwiftUI
import SwiftData
import CMVLibrary

@main
struct CMVApp: App {
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

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            appContent
        }
        .defaultSize(width: 1_360, height: 860)
        .windowStyle(.hiddenTitleBar)
        WindowGroup("影片", id: "video") {
            if let container {
                VideoWindowView()
                    .environment(appModel)
                    .environment(videoWindowStore)
                    .modelContainer(container)
            } else {
                Text("無法開啟影片播放")
            }
        }
        .defaultSize(width: 760, height: 520)
        #else
        WindowGroup {
            appContent
        }
        #endif
    }

    @ViewBuilder
    private var appContent: some View {
        if let container {
            RootView()
                .environment(appModel)
                .modelContainer(container)
                .environment(videoWindowStore)
        } else {
            StorageRecoveryView(message: storageError ?? "未知資料庫錯誤")
        }
    }

    private struct StorageRecoveryView: View {
        let message: String

        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "externaldrive.badge.exclamationmark").font(.system(size: 44))
                Text("無法開啟星穹私藏音樂庫").font(.title2.bold())
                Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Text("請確認磁碟可寫入後重新啟動 App。既有資料不會被覆寫。")
                    .font(.callout).multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(minWidth: 360, minHeight: 240)
        }
    }

}
