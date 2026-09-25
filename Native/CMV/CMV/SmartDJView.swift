import SwiftUI
import SwiftData
import CMVDomain
import CMVThemes

/// Smart DJ 的使用者入口與結果清單。
///
/// Smart DJ 不會為了評分而把整個曲庫搬到主執行緒；每次只送一個有限的、
/// 不含 artwork 的候選批次給 AppModel，再把結果交給既有播放佇列。
struct SmartDJView: View {
    private static let sampleWindowSize = 300
    // 用不同穩定排序各抓一小頁，增加曲庫涵蓋面；不使用大 offset，避免
    // repository 為了建立全量排序 ID 索引而觸碰整個曲庫。
    private static let samplePlans: [(sort: LibraryTrackSort, offset: Int)] = [
        (.modifiedAt, 0), (.title, 0), (.artist, 0), (.album, 0)
    ]
    private static var candidateLimit: Int { sampleWindowSize * samplePlans.count }
    private static let queueLimit = 25

    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.cmvTheme) private var theme
    @State private var selections: [DJSelection] = []
    @State private var isGenerating = false
    @State private var hasLoaded = false
    @State private var generation = 0
    @State private var statusMessage: String?
    @State private var generationTask: Task<Void, Never>?

    var body: some View {
        Group {
            if appModel.proStore.hasPro {
                smartDJContent
            } else {
                proPrompt
            }
        }
        .navigationTitle(AppLanguage.localized("Smart DJ"))
        .celestialPageBackground()
        .task(id: appModel.proStore.hasPro) {
            guard appModel.proStore.hasPro, !hasLoaded else { return }
            startGeneration()
        }
        .onDisappear { cancelGeneration(showMessage: false) }
    }

    private var smartDJContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                introCard

                if isGenerating {
                    generatingCard
                } else if selections.isEmpty {
                    emptyCard
                } else {
                    resultCard
                }
            }
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .refreshable { await refreshGeneration() }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(AppLanguage.localized("為你排一段夜航"), systemImage: "wand.and.stars")
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.primary)
            Text(AppLanguage.localized("Smart DJ 會依照最愛、評分與已儲存的聲學分析，挑出一段可以直接播放的曲序。分析全部在裝置上完成。"))
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label(AppLanguage.localized("最多 25 首"), systemImage: "music.note.list")
                Label(AppLanguage.localized("本機處理"), systemImage: "lock.shield")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Button {
                startGeneration()
            } label: {
                Label(
                    AppLanguage.localized(selections.isEmpty ? "開始推薦" : "重新推薦"),
                    systemImage: "arrow.clockwise"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGenerating)
            .frame(minHeight: 44)
            .accessibilityHint(AppLanguage.localized("從分段候選曲目產生新的 Smart DJ 播放清單"))
        }
        .padding(20)
        .background(theme.surface.opacity(0.34), in: RoundedRectangle(cornerRadius: 18))
    }

    private var generatingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            VStack(alignment: .leading, spacing: 3) {
                Text(AppLanguage.localized("正在準備 Smart DJ"))
                Text(AppLanguage.localized("先讀取分段候選曲目，再交給本機評分核心。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(AppLanguage.localized("取消"), systemImage: "xmark.circle") {
                cancelGeneration()
            }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(theme.surface.opacity(0.24), in: RoundedRectangle(cornerRadius: 16))
    }

    private var emptyCard: some View {
        ContentUnavailableView(
            AppLanguage.localized("目前沒有可推薦的曲目"),
            systemImage: "music.note.slash",
            description: Text(statusMessage ?? AppLanguage.localized("請先加入音樂來源，或稍後再試。"))
        )
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLanguage.localized("推薦結果"))
                        .font(.title3.weight(.semibold))
                    Text(String(
                        format: AppLanguage.localized("已從分段抽樣的最多 %lld 首候選曲目中選出 %lld 首"),
                        Int64(Self.candidateLimit), Int64(selections.count)
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button(AppLanguage.localized("立即播放"), systemImage: "play.fill") { playAll() }
                    Button(AppLanguage.localized("加入接下來播放"), systemImage: "text.badge.plus") { enqueueAll() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .accessibilityLabel(AppLanguage.localized("Smart DJ 播放選項"))
            }

            HStack(spacing: 10) {
                Button(AppLanguage.localized("立即播放"), systemImage: "play.fill") { playAll() }
                    .buttonStyle(.borderedProminent)
                Button(AppLanguage.localized("加入佇列"), systemImage: "text.badge.plus") { enqueueAll() }
                    .buttonStyle(.bordered)
            }
            .frame(minHeight: 44)

            ForEach(Array(selections.enumerated()), id: \.element.id) { index, selection in
                smartDJRow(selection, rank: index + 1)
            }
        }
        .padding(20)
        .background(theme.surface.opacity(0.28), in: RoundedRectangle(cornerRadius: 18))
    }

    private func smartDJRow(_ selection: DJSelection, rank: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(rank)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: 4) {
                Text(selection.track.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text("\(AppLanguage.localizedArtist(selection.track.artist)) · \(AppLanguage.localizedAlbum(selection.track.album))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(selection.reasons.prefix(2).map(localizedReason).joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(theme.primary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button(AppLanguage.localized("播放"), systemImage: "play.fill") {
                appModel.play(track: selection.track, context: context)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .frame(width: 44, height: 44)
            .accessibilityLabel(String(format: AppLanguage.localized("播放%@"), selection.track.title))
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider().opacity(0.45) }
    }

    private var proPrompt: some View {
        ContentUnavailableView {
            Label(AppLanguage.localized("Smart DJ 是 Pro 功能"), systemImage: "wand.and.stars")
        } description: {
            Text(AppLanguage.localized("解鎖 CMV Pro 後，讓本機分析與 Smart DJ 根據你的曲庫排出下一段音樂。"))
        } actions: {
            Button(AppLanguage.localized("查看 CMV Pro"), systemImage: "sparkles") {
                appModel.showingProUpgrade = true
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
        }
        .padding(24)
        .background(theme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 22))
        .frame(maxWidth: 560)
        .padding(24)
    }

    private func startGeneration() {
        guard appModel.proStore.hasPro, !isGenerating else { return }
        generation &+= 1
        let requestGeneration = generation
        isGenerating = true
        statusMessage = nil
        generationTask?.cancel()
        generationTask = Task { @MainActor in
            await generateQueue(requestGeneration: requestGeneration)
        }
    }

    private func cancelGeneration(showMessage: Bool = true) {
        generation &+= 1
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        if showMessage { statusMessage = AppLanguage.localized("已取消 Smart DJ 推薦。") }
    }

    private func refreshGeneration() async {
        startGeneration()
        if let task = generationTask { await task.value }
    }

    private func generateQueue(requestGeneration: Int) async {
        defer {
            if requestGeneration == generation {
                isGenerating = false
                hasLoaded = !Task.isCancelled
            }
        }

        let candidates = await loadCandidateSample()
        guard requestGeneration == generation, !Task.isCancelled else { return }

        let playable = candidates.filter { $0.mediaKind == .audio && $0.availability == .available }
        guard !playable.isEmpty else {
            selections = []
            statusMessage = appModel.libraryReadError == nil
                ? (candidates.isEmpty
                   ? AppLanguage.localized("曲庫目前沒有可讀取的曲目。")
                   : AppLanguage.localized("目前候選曲目都暫時無法播放，請檢查音樂來源。"))
                : AppLanguage.localized("無法讀取曲庫，請稍後再試。")
            return
        }

        let profiles = Dictionary(uniqueKeysWithValues: playable.compactMap { track in
            track.analysis.map { (track.id, $0) }
        })
        let result = await appModel.makeSmartQueue(
            tracks: playable,
            profiles: profiles,
            history: [:],
            limit: Self.queueLimit
        )
        guard requestGeneration == generation, !Task.isCancelled else { return }
        selections = result
        if result.isEmpty {
            statusMessage = AppLanguage.localized("Smart DJ 暫時沒有推薦結果，請稍後再試。")
        }
    }

    private func loadCandidateSample() async -> [Track] {
        var candidates: [Track] = []
        var seenIDs = Set<UUID>()
        for plan in Self.samplePlans {
            guard !Task.isCancelled else { return [] }
            let page = await appModel.searchTracks(
                query: "",
                context: context,
                sort: plan.sort,
                ascending: false,
                limit: Self.sampleWindowSize,
                offset: plan.offset,
                includeArtwork: false
            )
            for track in page where seenIDs.insert(track.id).inserted {
                candidates.append(track)
            }
        }
        return candidates
    }

    private func localizedReason(_ reason: String) -> String {
        let bpmPrefix = "節奏約 "
        if reason.hasPrefix(bpmPrefix) {
            return String(format: AppLanguage.localized("節奏約 %@"), String(reason.dropFirst(bpmPrefix.count)))
        }
        return AppLanguage.localized(reason)
    }

    private func playAll() {
        let tracks = selections.map(\.track)
        guard !tracks.isEmpty else { return }
        appModel.play(tracks: tracks, context: context)
    }

    private func enqueueAll() {
        let tracks = selections.map(\.track)
        guard !tracks.isEmpty else { return }
        appModel.addToPlaybackQueue(tracks, context: context)
    }
}
