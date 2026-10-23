import SwiftUI
#if os(macOS)
import AppKit
#endif
#if !DEBUG || !CMV_STOREKIT_TEST_HOST
import SwiftData
import CMVLibrary
#endif

#if DEBUG && CMV_STOREKIT_TEST_HOST
@main
struct CMVApp: App {
    var body: some Scene {
        WindowGroup {
            Color.clear
        }
    }
}
#else
@main
struct CMVApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(CMVApplicationDelegate.self) private var applicationDelegate
    #endif
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
            #if os(iOS)
            if phase == .background {
                let application = UIApplication.shared
                let backgroundTask = application.beginBackgroundTask(withName: "Save playback queue")
                Task { @MainActor in
                    await appModel.flushPlaybackQueueSnapshot()
                    if backgroundTask != .invalid { application.endBackgroundTask(backgroundTask) }
                }
            }
            #endif
        }
        #if os(macOS)
        .onAppear { applicationDelegate.appModel = appModel }
        #endif
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

#if os(macOS)
/// A normal Quit waits for the final queue write. Failed writes give the owner
/// a chance to recover disk access before accepting an older restored queue.
@MainActor
final class CMVApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var appModel: AppModel?
    private var terminationTask: Task<Void, Never>?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let appModel else { return .terminateNow }
        guard terminationTask == nil else { return .terminateLater }
        terminationTask = Task { @MainActor [weak self] in
            let saved = await appModel.flushPlaybackQueueSnapshot()
            var shouldTerminate = saved
            if !saved {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = AppLanguage.localized("尚未保存播放佇列")
                alert.informativeText = AppLanguage.localized("最近的佇列變更尚未寫入磁碟。請確認可用空間與寫入權限後再試；仍然結束可能還原舊佇列。")
                alert.addButton(withTitle: AppLanguage.localized("留在 App"))
                alert.addButton(withTitle: AppLanguage.localized("仍然結束"))
                shouldTerminate = alert.runModal() == .alertSecondButtonReturn
            }
            self?.terminationTask = nil
            sender.reply(toApplicationShouldTerminate: shouldTerminate)
        }
        return .terminateLater
    }
}
#endif
#endif
