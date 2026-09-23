import SwiftUI
import SwiftData
import CMVThemes

struct PlayerBar: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        let _ = appModel.playbackControlsRevision
        ViewThatFits(in: .horizontal) {
            fullLayout.frame(minWidth: 920)
            compactLayout
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(reduceTransparency ? AnyShapeStyle(theme.background.opacity(0.98)) : AnyShapeStyle(.ultraThinMaterial))
        .overlay(alignment: .top) { Rectangle().fill(theme.primary.opacity(0.5)).frame(height: 1) }
        .controlSize(.large)
        .accessibilityElement(children: .contain)
    }

    private var fullLayout: some View {
        HStack(spacing: 16) {
            currentTrackSummary
            Spacer(minLength: 12)
            Button("隨機", systemImage: "shuffle") { appModel.toggleShuffle() }
                .labelStyle(.iconOnly).tint(appModel.isShuffleEnabled ? theme.primary : .secondary)
                .frame(width: 44, height: 44)
                .disabled(!appModel.canShuffleQueue)
                .accessibilityValue(appModel.isShuffleEnabled ? "已開啟" : "已關閉")
            transportControls
            Button("重複", systemImage: "repeat") { appModel.playback.toggleRepeat() }
                .labelStyle(.iconOnly).tint(appModel.playback.isRepeatEnabled ? theme.primary : .secondary)
                .frame(width: 44, height: 44)
                .disabled(!appModel.canAdjustQueueOrder)
                .accessibilityValue(appModel.playback.isRepeatEnabled ? "已開啟" : "已關閉")
            SleepTimerMenu()
            Spacer()
            Slider(value: Binding(get: { Double(appModel.currentOutputVolume) }, set: { appModel.setCurrentMediaVolume(Float($0)) }), in: 0...1)
                .frame(minWidth: 120, maxWidth: 220).accessibilityLabel("音量")
            Image(systemName: "speaker.wave.2.fill")
        }
    }

    private var compactLayout: some View {
        HStack(spacing: 10) {
            currentTrackSummary
            Spacer(minLength: 8)
            transportControls
            Menu {
                Button(appModel.isShuffleEnabled ? "關閉隨機播放" : "開啟隨機播放",
                       systemImage: "shuffle") { appModel.toggleShuffle() }
                    .disabled(!appModel.canShuffleQueue)
                Button(appModel.playback.isRepeatEnabled ? "關閉重複播放" : "開啟重複播放",
                       systemImage: "repeat") { appModel.playback.toggleRepeat() }
                    .disabled(!appModel.canAdjustQueueOrder)
            } label: {
                Label("更多播放控制", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .frame(width: 44, height: 44)
            .disabled(!appModel.canShuffleQueue && !appModel.canAdjustQueueOrder)
            .accessibilityHint("調整隨機與重複播放")
            SleepTimerMenu()
        }
    }

    private var currentTrackSummary: some View {
        let current = appModel.currentTrack
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(theme.secondary)
                Image(systemName: "cloud.moon.fill").foregroundStyle(theme.metal)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(current?.title ?? "尚未播放").font(.headline).lineLimit(1)
                Text(current?.artist ?? "選擇歌曲開始聆聽").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(minWidth: 180, maxWidth: 300, alignment: .leading)
    }

    private var transportControls: some View {
        HStack(spacing: 4) {
            Button("上一首", systemImage: "backward.fill") { appModel.skipCurrentMediaBackward(context: modelContext) }
                .labelStyle(.iconOnly).frame(width: 44, height: 44)
                .disabled(appModel.videoURL != nil && !appModel.canSkipVideoBackward)
            Button(appModel.isCurrentMediaPlaying ? "暫停" : "播放", systemImage: appModel.isCurrentMediaPlaying ? "pause.fill" : "play.fill") {
                appModel.toggleCurrentMediaPlayback(context: modelContext)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderedProminent)
            .frame(width: 44, height: 44)
            .accessibilityHint(appModel.videoURL == nil ? "播放目前曲目" : "播放或暫停目前影片")
            Button("下一首", systemImage: "forward.fill") { appModel.skipCurrentMediaForward(context: modelContext) }
                .labelStyle(.iconOnly).frame(width: 44, height: 44)
                .disabled(appModel.videoURL != nil && !appModel.canSkipVideoForward)
        }
    }
}

struct SleepTimerMenu: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let _ = appModel.playbackControlsRevision
        Menu {
            Section("睡眠計時器") {
                Button("15 分鐘") { appModel.playback.setSleepTimer(minutes: 15) }
                Button("30 分鐘") { appModel.playback.setSleepTimer(minutes: 30) }
                Button("60 分鐘") { appModel.playback.setSleepTimer(minutes: 60) }
                Button("90 分鐘") { appModel.playback.setSleepTimer(minutes: 90) }
                if appModel.playback.sleepTimerEndDate != nil {
                    Button("取消計時器", role: .destructive) { appModel.playback.cancelSleepTimer() }
                }
            }
        } label: {
            Label(timerLabel, systemImage: appModel.playback.sleepTimerEndDate == nil ? "moon.zzz" : "moon.zzz.fill")
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(timerLabel)
        .accessibilityHint("選擇停止播放前的剩餘時間")
    }

    private var timerLabel: String {
        guard let endDate = appModel.playback.sleepTimerEndDate else { return "睡眠計時器" }
        let minutes = max(1, Int(ceil(max(0, endDate.timeIntervalSinceNow) / 60)))
        return "睡眠計時器，剩餘 \(minutes) 分鐘"
    }
}

#if os(iOS)
struct MiniPlayerBar: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.cmvTheme) private var theme
    var onExpand: () -> Void = {}

    var body: some View {
        let current = appModel.currentTrack
        HStack(spacing: 12) {
            ZStack { Circle().fill(theme.secondary); Image(systemName: "cloud.moon.fill").foregroundStyle(theme.metal) }
                .frame(width: 42, height: 42)
            Button(action: onExpand) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(current?.title ?? "尚未播放").font(.headline).lineLimit(1)
                    Text(current?.artist ?? "選擇歌曲開始聆聽").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }.buttonStyle(.plain)
            Spacer(minLength: 8)
            Button(appModel.isCurrentMediaPlaying ? "暫停" : "播放", systemImage: appModel.isCurrentMediaPlaying ? "pause.fill" : "play.fill") {
                appModel.toggleCurrentMediaPlayback(context: modelContext)
            }
            .labelStyle(.iconOnly)
            .frame(width: 44, height: 44)
            .accessibilityLabel(appModel.isCurrentMediaPlaying ? "暫停" : "播放")
            .accessibilityHint(appModel.videoURL == nil ? "播放目前曲目" : "播放或暫停目前影片")
            Button("下一首", systemImage: "forward.fill") { appModel.skipCurrentMediaForward(context: modelContext) }
                .labelStyle(.iconOnly).frame(width: 44, height: 44)
                .accessibilityLabel("下一首")
                .disabled(appModel.videoURL != nil && !appModel.canSkipVideoForward)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(theme.primary.opacity(0.5)).frame(height: 1) }
        .contentShape(Rectangle())
    }
}
#endif
