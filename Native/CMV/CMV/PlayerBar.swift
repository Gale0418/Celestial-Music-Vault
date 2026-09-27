import SwiftUI
import SwiftData
import CMVThemes

/// Bound only accessibility-sized toolbar glyphs; preserve the normal layout.
struct PlaybackIconSize: ViewModifier {
    var points: CGFloat = 22
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            content.font(.system(size: points))
        } else {
            content
        }
    }
}

struct PlayerBar: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(AppLanguage.preferenceKey) private var appLanguage = "system"
    var body: some View {
        let _ = appLanguage
        let _ = appModel.playbackControlsRevision
        VStack(spacing: 6) {
            ViewThatFits(in: .horizontal) {
                fullLayout.frame(minWidth: 920)
                compactLayout
            }
            if appModel.currentMediaDuration.isFinite, appModel.currentMediaDuration > 0 {
                PlaybackProgressView()
                    .frame(maxWidth: 960)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(reduceTransparency ? AnyShapeStyle(theme.background) : AnyShapeStyle(.ultraThinMaterial))
                .celestialParallax(.interface, enabled: theme.id == .titaniumEclipse)
                .clipped()
        }
        .overlay(alignment: .top) { Rectangle().fill(theme.primary.opacity(0.5)).frame(height: 1) }
        .controlSize(.large)
        .accessibilityElement(children: .contain)
    }

    private var fullLayout: some View {
        HStack(spacing: 16) {
            currentTrackSummary
            Spacer(minLength: 12)
            Button { appModel.toggleShuffle() } label: {
                controlSymbol("shuffle", isOn: appModel.isShuffleEnabled)
            }
                .frame(width: 44, height: 44)
                .disabled(!appModel.canShuffleQueue)
                .accessibilityLabel(AppLanguage.localized("隨機"))
                .accessibilityValue(appModel.isShuffleEnabled
                                    ? AppLanguage.localized("已開啟")
                                    : AppLanguage.localized("已關閉"))
            transportControls
            Button { appModel.playback.toggleRepeat() } label: {
                controlSymbol("repeat", isOn: appModel.playback.isRepeatEnabled)
            }
                .frame(width: 44, height: 44)
                .disabled(!appModel.canAdjustQueueOrder)
                .accessibilityLabel(AppLanguage.localized("重複"))
                .accessibilityValue(appModel.playback.isRepeatEnabled
                                    ? AppLanguage.localized("已開啟")
                                    : AppLanguage.localized("已關閉"))
            SleepTimerMenu()
            Spacer()
            Slider(value: Binding(get: { Double(appModel.currentOutputVolume) }, set: { appModel.setCurrentMediaVolume(Float($0)) }), in: 0...1)
                .frame(minWidth: 120, maxWidth: 220)
                .accessibilityLabel(AppLanguage.localized("音量"))
            Image(systemName: "speaker.wave.2.fill")
        }
    }

    private var compactLayout: some View {
        HStack(spacing: 10) {
            currentTrackSummary
            Spacer(minLength: 8)
            transportControls
            Menu {
                Button(appModel.isShuffleEnabled
                       ? AppLanguage.localized("關閉隨機播放")
                       : AppLanguage.localized("開啟隨機播放"),
                       systemImage: "shuffle") { appModel.toggleShuffle() }
                    .disabled(!appModel.canShuffleQueue)
                Button(appModel.playback.isRepeatEnabled
                       ? AppLanguage.localized("關閉重複播放")
                       : AppLanguage.localized("開啟重複播放"),
                       systemImage: "repeat") { appModel.playback.toggleRepeat() }
                    .disabled(!appModel.canAdjustQueueOrder)
            } label: {
                Label(AppLanguage.localized("更多播放控制"), systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly).modifier(PlaybackIconSize())
            }
            .frame(width: 44, height: 44)
            .disabled(!appModel.canShuffleQueue && !appModel.canAdjustQueueOrder)
            .accessibilityHint(AppLanguage.localized("調整隨機與重複播放"))
            SleepTimerMenu()
        }
    }

    private func controlSymbol(_ name: String, isOn: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: name)
                .modifier(PlaybackIconSize())
                .foregroundStyle(isOn ? theme.primary : Color.secondary)
            if isOn {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.metal)
                    .offset(x: 10, y: -7)
            }
        }
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
    }

    private var currentTrackSummary: some View {
        let current = appModel.currentTrack
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(theme.secondary)
                Image(systemName: "cloud.moon.fill").modifier(PlaybackIconSize(points: 20)).foregroundStyle(theme.metal)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(current?.title ?? AppLanguage.localized("尚未播放")).font(.headline).lineLimit(1)
                Text(current.map { AppLanguage.localizedArtist($0.artist) } ?? AppLanguage.localized("選擇歌曲開始聆聽"))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(minWidth: 180, maxWidth: 300, alignment: .leading)
    }

    private var transportControls: some View {
        HStack(spacing: 4) {
            Button(AppLanguage.localized("上一首"), systemImage: "backward.fill") { appModel.skipCurrentMediaBackward(context: modelContext) }
                .labelStyle(.iconOnly).modifier(PlaybackIconSize()).frame(width: 44, height: 44)
                .disabled(appModel.videoURL != nil && !appModel.canSkipVideoBackward)
            Button(appModel.isCurrentMediaPlaying
                   ? AppLanguage.localized("暫停")
                   : AppLanguage.localized("播放"),
                   systemImage: appModel.isCurrentMediaPlaying ? "pause.fill" : "play.fill") {
                appModel.toggleCurrentMediaPlayback(context: modelContext)
            }
            .labelStyle(.iconOnly).modifier(PlaybackIconSize())
            .buttonStyle(.borderedProminent)
            .frame(width: 44, height: 44)
            .accessibilityHint(appModel.videoURL == nil
                               ? AppLanguage.localized("播放目前曲目")
                               : AppLanguage.localized("播放或暫停目前影片"))
            Button(AppLanguage.localized("下一首"), systemImage: "forward.fill") { appModel.skipCurrentMediaForward(context: modelContext) }
                .labelStyle(.iconOnly).modifier(PlaybackIconSize()).frame(width: 44, height: 44)
                .disabled(appModel.videoURL != nil &&
                          !(appModel.canSkipVideoForward || appModel.canContinueLibraryPlayback))
        }
    }
}

struct SleepTimerMenu: View {
    @Environment(AppModel.self) private var appModel
    @AppStorage(AppLanguage.preferenceKey) private var appLanguage = "system"

    var body: some View {
        let _ = appLanguage
        let _ = appModel.playbackControlsRevision
        Menu {
            Section(AppLanguage.localized("睡眠計時器")) {
                Button(String(format: AppLanguage.localized("%lld 分鐘"), Int64(15))) { appModel.playback.setSleepTimer(minutes: 15) }
                Button(String(format: AppLanguage.localized("%lld 分鐘"), Int64(30))) { appModel.playback.setSleepTimer(minutes: 30) }
                Button(String(format: AppLanguage.localized("%lld 分鐘"), Int64(60))) { appModel.playback.setSleepTimer(minutes: 60) }
                Button(String(format: AppLanguage.localized("%lld 分鐘"), Int64(90))) { appModel.playback.setSleepTimer(minutes: 90) }
                if appModel.playback.sleepTimerEndDate != nil {
                    Button(AppLanguage.localized("取消計時器"), role: .destructive) { appModel.playback.cancelSleepTimer() }
                }
            }
        } label: {
            Label(timerLabel, systemImage: appModel.playback.sleepTimerEndDate == nil ? "moon.zzz" : "moon.zzz.fill")
                .labelStyle(.iconOnly).modifier(PlaybackIconSize())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(timerLabel)
        .accessibilityHint(AppLanguage.localized("選擇停止播放前的剩餘時間"))
    }

    private var timerLabel: String {
        guard let endDate = appModel.playback.sleepTimerEndDate else {
            return AppLanguage.localized("睡眠計時器")
        }
        let minutes = max(1, Int(ceil(max(0, endDate.timeIntervalSinceNow) / 60)))
        return String(format: AppLanguage.localized("睡眠計時器，剩餘 %lld 分鐘"), Int64(minutes))
    }
}

#if os(iOS)
struct MiniPlayerBar: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(AppLanguage.preferenceKey) private var appLanguage = "system"
    var onExpand: () -> Void = {}

    var body: some View {
        let _ = appLanguage
        let current = appModel.currentTrack
        HStack(spacing: 12) {
            Button(action: onExpand) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 12) {
                        ZStack { Circle().fill(theme.secondary); Image(systemName: "cloud.moon.fill").modifier(PlaybackIconSize(points: 20)).foregroundStyle(theme.metal) }
                            .frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(current?.title ?? AppLanguage.localized("尚未播放")).font(.headline).lineLimit(1)
                            Text(current.map { AppLanguage.localizedArtist($0.artist) } ?? AppLanguage.localized("選擇歌曲開始聆聽"))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .accessibilityHint(AppLanguage.localized("展開完整播放控制"))
            Button(AppLanguage.localized("上一首"), systemImage: "backward.fill") {
                appModel.skipCurrentMediaBackward(context: modelContext)
            }
            .labelStyle(.iconOnly).modifier(PlaybackIconSize())
            .frame(width: 44, height: 44)
            .disabled(appModel.videoURL != nil && !appModel.canSkipVideoBackward)
            Button(appModel.isCurrentMediaPlaying
                   ? AppLanguage.localized("暫停")
                   : AppLanguage.localized("播放"),
                   systemImage: appModel.isCurrentMediaPlaying ? "pause.fill" : "play.fill") {
                appModel.toggleCurrentMediaPlayback(context: modelContext)
            }
            .labelStyle(.iconOnly).modifier(PlaybackIconSize())
            .frame(width: 44, height: 44)
            .accessibilityLabel(appModel.isCurrentMediaPlaying
                                ? AppLanguage.localized("暫停")
                                : AppLanguage.localized("播放"))
            .accessibilityHint(appModel.videoURL == nil
                               ? AppLanguage.localized("播放目前曲目")
                               : AppLanguage.localized("播放或暫停目前影片"))
            Button(AppLanguage.localized("下一首"), systemImage: "forward.fill") { appModel.skipCurrentMediaForward(context: modelContext) }
                .labelStyle(.iconOnly).modifier(PlaybackIconSize()).frame(width: 44, height: 44)
                .accessibilityLabel(AppLanguage.localized("下一首"))
                .disabled(appModel.videoURL != nil &&
                          !(appModel.canSkipVideoForward || appModel.canContinueLibraryPlayback))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background {
            Rectangle()
                .fill(reduceTransparency ? AnyShapeStyle(theme.background) : AnyShapeStyle(.ultraThinMaterial))
                .celestialParallax(.interface, enabled: theme.id == .titaniumEclipse)
                .clipped()
        }
        .overlay(alignment: .top) { Rectangle().fill(theme.primary.opacity(0.5)).frame(height: 1) }
    }
}
#endif
