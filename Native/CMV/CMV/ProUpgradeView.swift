import SwiftUI
import CMVThemes

/// The same purchase surface is reachable from Settings and a paid operation.
/// Closing it never interrupts playback or changes the user's collection.
struct ProUpgradeView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cmvTheme) private var theme

    private var store: ProStore { appModel.proStore }
    private var isBusy: Bool { store.operation != .idle }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: store.hasPro ? "checkmark.seal.fill" : "moon.stars")
                            .font(.largeTitle)
                            .foregroundStyle(theme.primary)
                            .accessibilityHidden(true)
                        Text(store.hasPro ? "你的 Pro，已經準備好了" : "讓收藏，多一點自由")
                            .font(.title.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text(store.hasPro
                             ? "謝謝你支持 CMV。繼續挑一首喜歡的歌吧。"
                             : "把想聽的歌先留在裝置上，再替今晚的音樂換一片天空。")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        benefit("離線也有準備", symbol: "arrow.down.circle",
                                detail: "釘選想帶走的歌曲，讓智慧快取預先準備接下來的音樂。")
                        benefit("換一片喜歡的天空", symbol: "paintpalette",
                                detail: "解鎖鈦銀月蝕、翠綠極光與琥珀晨曦。")
                    }

                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("一次性購買，不自動續訂。")
                            .font(.headline)
                        if store.isChecking {
                            ProgressView("正在確認購買狀態…")
                        }
                        if let message = store.message {
                            Text(message)
                                .font(.callout)
                                .accessibilityLabel("購買狀態：\(message)")
                        }
                        if !store.hasPro {
                            Button {
                                Task { await store.purchase() }
                            } label: {
                                HStack {
                                    Spacer()
                                    if store.operation == .purchasing { ProgressView() }
                                    Text(purchaseTitle)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isBusy || store.isChecking || store.displayPrice == nil)
                            if store.displayPrice == nil && !store.isChecking {
                                Text("目前無法取得購買項目。你可以稍後重試，免費播放仍可正常使用。")
                                    .font(.callout).foregroundStyle(.secondary)
                                Button("重新載入購買項目") { Task { await store.refresh() } }
                                    .frame(minHeight: 44)
                                    .disabled(isBusy)
                            }
                        }
                        Button(store.operation == .restoring ? "正在恢復購買…" : "恢復購買") {
                            Task { await store.restore() }
                        }
                        .frame(minHeight: 44)
                        .disabled(isBusy || store.isChecking)
                        Text("本機與 NAS 基本播放、搜尋、歌單、收藏評分和日常佇列操作都能免費使用。")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("CMV Pro")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .tint(theme.primary)
            .task { await store.refresh() }
        }
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 560, minHeight: 520, idealHeight: 700)
        #endif
    }

    private var purchaseTitle: String {
        if store.operation == .purchasing { return "正在處理購買…" }
        guard let price = store.displayPrice else { return "購買項目暫時無法使用" }
        return "一次性解鎖 Pro · \(price)"
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
