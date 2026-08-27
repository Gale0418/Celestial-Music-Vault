import SwiftUI
import SwiftData
import AeroThemes

struct PlayerBar: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.aeroTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        let current = appModel.currentTrack
        HStack(spacing: 18) {
            ZStack { Circle().fill(theme.secondary); Image(systemName: "cloud.moon.fill").foregroundStyle(theme.metal) }
                .frame(width: 56, height: 56)
            VStack(alignment: .leading) {
                Text(current?.title ?? "尚未播放").font(.headline).lineLimit(1)
                Text(current?.artist ?? "選擇歌曲開始聆聽").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button("隨機", systemImage: "shuffle") { appModel.playback.toggleShuffle() }
                .labelStyle(.iconOnly).tint(appModel.playback.isShuffleEnabled ? theme.primary : .secondary)
                .frame(width: 44, height: 44)
                .disabled(appModel.videoURL != nil)
            Button("上一首", systemImage: "backward.fill") { try? appModel.playback.skipBackward() }
                .labelStyle(.iconOnly).frame(width: 44, height: 44)
                .disabled(appModel.videoURL != nil)
            Button(appModel.playback.isPlaying ? "暫停" : (appModel.videoURL == nil ? "播放" : "影片播放中"), systemImage: appModel.playback.isPlaying ? "pause.fill" : (appModel.videoURL == nil ? "play.fill" : "film")) {
                if appModel.playback.isPlaying { appModel.playback.pause() } else { appModel.playOrResume(context: modelContext) }
            }
            .labelStyle(.iconOnly).buttonStyle(.borderedProminent).controlSize(.large).frame(width: 44, height: 44)
            .disabled(appModel.videoURL != nil)
            .accessibilityHint(appModel.videoURL == nil ? "播放目前曲目" : "請使用影片播放控制項")
            Button("下一首", systemImage: "forward.fill") { try? appModel.playback.skipForward() }
                .labelStyle(.iconOnly).frame(width: 44, height: 44)
                .disabled(appModel.videoURL != nil)
            Button("重複", systemImage: "repeat") { appModel.playback.toggleRepeat() }
                .labelStyle(.iconOnly).tint(appModel.playback.isRepeatEnabled ? theme.primary : .secondary)
                .frame(width: 44, height: 44)
                .disabled(appModel.videoURL != nil)
            SleepTimerMenu()
            Spacer()
            Image(systemName: "airplayaudio")
            Slider(value: Binding(get: { Double(appModel.playback.outputVolume) }, set: { appModel.playback.setVolume(Float($0)) }), in: 0...1)
                .frame(maxWidth: 220).accessibilityLabel("音量")
            Image(systemName: "speaker.wave.2.fill")
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(reduceTransparency ? AnyShapeStyle(theme.background.opacity(0.98)) : AnyShapeStyle(.ultraThinMaterial))
        .overlay(alignment: .top) { Rectangle().fill(theme.primary.opacity(0.5)).frame(height: 1) }
        .controlSize(.large)
        .accessibilityElement(children: .contain)
    }
}

struct SleepTimerMenu: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
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
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel(timerLabel)
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
    @Environment(\.aeroTheme) private var theme
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
            Button(appModel.playback.isPlaying ? "暫停" : (appModel.videoURL == nil ? "播放" : "影片播放中"), systemImage: appModel.playback.isPlaying ? "pause.fill" : (appModel.videoURL == nil ? "play.fill" : "film")) {
                if appModel.playback.isPlaying { appModel.playback.pause() } else { appModel.playOrResume(context: modelContext) }
            }
            .labelStyle(.iconOnly)
            .frame(width: 44, height: 44)
            .disabled(appModel.videoURL != nil)
            .accessibilityLabel(appModel.playback.isPlaying ? "暫停" : (appModel.videoURL == nil ? "播放" : "影片播放中"))
            .accessibilityHint(appModel.videoURL == nil ? "播放目前曲目" : "請使用影片播放控制項")
            Button("下一首", systemImage: "forward.fill") { try? appModel.playback.skipForward() }
                .labelStyle(.iconOnly).frame(width: 44, height: 44)
                .accessibilityLabel("下一首")
                .disabled(appModel.videoURL != nil)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(theme.primary.opacity(0.5)).frame(height: 1) }
        .contentShape(Rectangle())
    }
}
#endif
