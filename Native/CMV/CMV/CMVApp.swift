import SwiftUI
import SwiftData
import CMVLibrary

@main
struct CMVApp: App {
    @AppStorage(AppLanguage.preferenceKey) private var appLanguage = "system"
    @Environment(\.scenePhase) private var scenePhase
    @State private var systemLanguages = Locale.preferredLanguages
    private let container: ModelContainer?
    private let storageError: String?
    @State private var appModel = AppModel()
    @State private var videoWindowStore = VideoWindowStore()

    private var displayLocale: Locale {
        AppLanguage.locale(for: appLanguage, preferredLanguages: systemLanguages)
    }

    private func refreshSystemLanguage() {
        systemLanguages = Locale.preferredLanguages
    }

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
        .windowToolbarStyle(.unifiedCompact)
        WindowGroup(AppLanguage.localized("影片"), id: "video") {
            if let container {
                VideoWindowView()
                    .environment(appModel)
                    .environment(videoWindowStore)
                    .modelContainer(container)
                    .environment(\.locale, displayLocale)
            } else {
                Text("無法開啟影片播放")
                    .environment(\.locale, displayLocale)
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
        Group {
            if let container {
                RootView()
                    .environment(appModel)
                    .modelContainer(container)
                    .environment(videoWindowStore)
                    .environment(\.locale, displayLocale)
            } else {
                StorageRecoveryView(message: storageError ?? AppLanguage.localized("未知資料庫錯誤"))
                    .environment(\.locale, displayLocale)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
            refreshSystemLanguage()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshSystemLanguage() }
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
