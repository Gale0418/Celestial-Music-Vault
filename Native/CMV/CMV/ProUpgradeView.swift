import SwiftUI
import CMVThemes

/// The same purchase surface is reachable from Settings and a paid operation.
/// Closing it never interrupts playback or changes the user's collection.
struct ProUpgradeView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AccessibilityFocusState private var statusFocused: Bool

    private var store: ProStore { appModel.proStore }
    private var isBusy: Bool { store.operation != .idle }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: store.hasPro ? "checkmark.seal.fill" : "moon.stars")
                                .font(.largeTitle)
                                .foregroundStyle(theme.primary)
                                .accessibilityHidden(true)
                            Text(store.hasPro
                                 ? AppLanguage.localized("你的 Pro，已經準備好了")
                                 : AppLanguage.localized("讓收藏，多一點自由"))
                                .font(.title.bold())
                                .accessibilityAddTraits(.isHeader)
                            Text(store.hasPro
                                 ? AppLanguage.localized("謝謝你支持 CMV。繼續挑一首喜歡的歌吧。")
                                 : AppLanguage.localized("把想聽的歌先留在裝置上，再替今晚的音樂換一片天空。"))
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            benefit(AppLanguage.localized("離線也有準備"), symbol: "arrow.down.circle",
                                    detail: AppLanguage.localized("已保存到裝置的歌曲，來源離線時仍可播放。"))
                            benefit(AppLanguage.localized("進階批次整理"), symbol: "square.and.pencil",
                                    detail: AppLanguage.localized("批次編輯歌曲資訊與歌單多選移除。"))
                            benefit(AppLanguage.localized("換一片喜歡的天空"), symbol: "paintpalette",
                                    detail: proThemeBenefitDetail)
                            benefit(AppLanguage.localized("讓 Smart DJ 幫你選歌"), symbol: "wand.and.stars",
                                    detail: AppLanguage.localized("依收藏、評分與本機分析產生推薦，並告訴你選歌原因。"))
                        }

                        Divider()
                        VStack(alignment: .leading, spacing: 12) {
                            Text(AppLanguage.localized("一次性購買，不自動續訂。"))
                                .font(.headline)
                            if store.isChecking {
                                ProgressView(AppLanguage.localized("正在確認購買狀態…"))
                            }
                            if let message = store.message {
                                Text(message)
                                    .font(.callout)
                                    .accessibilityLabel(
                                        String(format: AppLanguage.localized("購買狀態：%@"), message))
                                    .accessibilityFocused($statusFocused)
                            }
                            Text(AppLanguage.localized("本機與 NAS 基本播放、搜尋、歌單、收藏評分和日常佇列操作都能免費使用。"))
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 560, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                purchaseActions
            }
            .navigationTitle("CMV Pro")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLanguage.localized("完成")) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .tint(theme.primary)
            .task { await store.refresh() }
            .onChange(of: store.message) { _, message in
                guard message != nil else {
                    statusFocused = false
                    return
                }
                // Move VoiceOver to the outcome after the status view exists.
                Task { @MainActor in
                    await Task.yield()
                    statusFocused = true
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 560, minHeight: 520, idealHeight: 700)
        #endif
    }

    private var purchaseTitle: String {
        if store.operation == .purchasing { return AppLanguage.localized("正在處理購買…") }
        if !store.isConfigured { return AppLanguage.localized("Pro 購買尚未開放") }
        guard let price = store.displayPrice else { return AppLanguage.localized("購買項目暫時無法使用") }
        return String(format: AppLanguage.localized("一次性解鎖 Pro · %@"), price)
    }

    private var proThemeBenefitDetail: String {
        String(
            format: AppLanguage.localized("解鎖 %@ 與 %@。"),
            AppLanguage.localized(CMVThemeID.titaniumEclipse.name),
            AppLanguage.localized(CMVThemeID.emeraldAurora.name)
        )
    }

    private var purchaseActions: some View {
        VStack(spacing: 8) {
            if !store.hasPro {
                Button {
                    Task { await store.purchase() }
                } label: {
                    HStack {
                        Spacer()
                        if store.operation == .purchasing { ProgressView() }
                        Text(purchaseTitle).fontWeight(.semibold)
                        Spacer()
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy || store.isChecking || store.displayPrice == nil)
                if store.displayPrice == nil && !store.isChecking {
                    Text(store.isConfigured
                         ? AppLanguage.localized("目前無法取得購買項目。你可以稍後重試，免費播放仍可正常使用。")
                         : AppLanguage.localized("Pro 購買尚未開放，免費播放仍可正常使用。"))
                        .font(.callout).foregroundStyle(.secondary)
                    if store.isConfigured {
                        Button(AppLanguage.localized("重新載入購買項目")) { Task { await store.refresh() } }
                            .frame(minHeight: 44)
                            .disabled(isBusy)
                    }
                }
            }
            Button(store.operation == .restoring
                   ? AppLanguage.localized("正在恢復購買…")
                   : AppLanguage.localized("恢復購買")) {
                Task { await store.restore() }
            }
            .frame(minHeight: 44)
            .disabled(isBusy || store.isChecking)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background {
            if theme.isStorybook {
                theme.surface
            } else {
                Rectangle()
                    .fill(reduceTransparency ? AnyShapeStyle(theme.surface) : AnyShapeStyle(.regularMaterial))
            }
        }
    }

    private func benefit(_ title: String, symbol: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(theme.primary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
