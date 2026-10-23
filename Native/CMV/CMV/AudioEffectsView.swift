import SwiftUI
import CMVDomain
import CMVThemes

extension AudioEffectPreset {
    var localizedName: String {
        switch self {
        case .original: AppLanguage.localized("原音")
        case .bassBoost: AppLanguage.localized("低音增強")
        case .vocal: AppLanguage.localized("人聲")
        case .electronic: AppLanguage.localized("電子")
        case .saturn: AppLanguage.localized("土星大氣層")
        case .orbit: AppLanguage.localized("軌道環繞")
        case .sewer: AppLanguage.localized("下水道")
        case .deepSpaceRadio: AppLanguage.localized("深空電台")
        case .cassette: AppLanguage.localized("老卡帶")
        case .underwater: AppLanguage.localized("水下")
        case .cathedral: AppLanguage.localized("大教堂")
        case .bathroom: AppLanguage.localized("浴室演唱會")
        case .custom: AppLanguage.localized("自訂音效")
        }
    }

    var localizedDetail: String {
        switch self {
        case .original: AppLanguage.localized("保留歌曲原本的音色。")
        case .bassBoost: AppLanguage.localized("讓低頻更厚實。")
        case .vocal: AppLanguage.localized("讓人聲更清楚。")
        case .electronic: AppLanguage.localized("加強低頻與高頻的輪廓。")
        case .saturn: AppLanguage.localized("柔和的高頻與寬闊殘響。")
        case .orbit: AppLanguage.localized("聲音緩慢左右移動，適合耳機聆聽；這是雙聲道效果。")
        case .sewer: AppLanguage.localized("短延遲與金屬空間回音。")
        case .deepSpaceRadio: AppLanguage.localized("窄頻通訊音色與輕微失真。")
        case .cassette: AppLanguage.localized("溫暖音色與輕微卡帶抖動。")
        case .underwater: AppLanguage.localized("柔暗低通濾波，像漂浮在水中。")
        case .cathedral: AppLanguage.localized("寬廣空間與綿長尾音。")
        case .bathroom: AppLanguage.localized("明亮而短促的空間反射。")
        case .custom: AppLanguage.localized("調整六項音色，再用強度混合原音。")
        }
    }
}

extension VideoAudioRouteStatus {
    var localizedTitle: String {
        switch self {
        case .pending: AppLanguage.localized("影片音效準備中")
        case .supported: AppLanguage.localized("影片音效可用")
        case .dryNoAudioTrack: AppLanguage.localized("影片沒有音軌，使用原音")
        case .dryStreamingAsset: AppLanguage.localized("串流影片使用原音")
        case .dryMultipleAudioTracks: AppLanguage.localized("影片有多條音軌，使用原音")
        case .dryUnsupportedFormat: AppLanguage.localized("影片格式不支援音效，使用原音")
        case .dryTapUnavailable: AppLanguage.localized("影片音效無法啟用，使用原音")
        case .dryProcessingFailed: AppLanguage.localized("影片音效處理失敗，使用原音")
        }
    }

    var localizedDetail: String {
        switch self {
        case .pending: AppLanguage.localized("正在讀取影片的實際 PCM 格式。")
        case .supported: AppLanguage.localized("同一個影片播放器時鐘已接上全部 13 種音效。")
        case .dryNoAudioTrack: AppLanguage.localized("這部影片沒有可處理的音軌。")
        case .dryStreamingAsset: AppLanguage.localized("串流來源目前只保留播放器原音。")
        case .dryMultipleAudioTracks: AppLanguage.localized("目前只處理單一音軌，為避免選錯音軌而保留原音。")
        case .dryUnsupportedFormat: AppLanguage.localized("只支援 44.1／48 kHz、Float32、mono／stereo PCM。")
        case .dryTapUnavailable: AppLanguage.localized("音效處理 tap 建立失敗，已安全回復原音。")
        case .dryProcessingFailed: AppLanguage.localized("即時音效處理未成功，已安全回復原音。")
        }
    }

    var symbol: String {
        switch self {
        case .supported: "waveform.circle.fill"
        case .pending: "hourglass"
        default: "info.circle"
        }
    }
}

/// 播放列共用入口。音效面板不改動播放、佇列或來源授權。
struct AudioEffectsButton: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.cmvTheme) private var theme
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @AppStorage(AppLanguage.preferenceKey) private var appLanguage = "system"
    @State private var isPresented = false

    private var isActive: Bool {
        guard !appModel.isComparingOriginalSound,
              appModel.audioEffects.preset != .original,
              appModel.audioEffects.intensity > 0 else { return false }
        if appModel.videoURL != nil {
            return appModel.videoSession.videoAudioStatus == .supported
        }
        return true
    }

    var body: some View {
        let _ = appLanguage
        Button { isPresented = true } label: {
            Label(AppLanguage.localized("音效"), systemImage: "slider.horizontal.3")
                .labelStyle(.iconOnly)
                .modifier(PlaybackIconSize())
                .foregroundStyle(isActive ? theme.primary : (theme.isStorybook ? theme.mutedText : Color.secondary))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .help(AppLanguage.localized("音效"))
        .accessibilityValue(appModel.videoURL != nil
                            ? appModel.videoSession.videoAudioStatus.localizedTitle
                            : (appModel.isComparingOriginalSound
                               ? AppLanguage.localized("原音") : appModel.audioEffects.preset.localizedName))
        .accessibilityIdentifier("audio-effects-button")
        .popover(isPresented: $isPresented) {
            NavigationStack { AudioEffectsPanel(showsCloseButton: true) }
                .presentationCompactAdaptation(.sheet)
                #if os(macOS)
                .frame(width: 460,
                       height: appModel.audioEffects.preset == .custom ? 740 : 500)
                #else
                .frame(width: horizontalSizeClass == .regular ? 420 : nil,
                       height: horizontalSizeClass == .regular ? 600 : nil)
                #endif
        }
        .onChange(of: isPresented) { _, presented in
            if !presented { appModel.setOriginalSoundComparison(false) }
        }
    }
}

struct AudioEffectsPanel: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.cmvTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppLanguage.preferenceKey) private var appLanguage = "system"
    var showsCloseButton = false

    private let equalizers: [AudioEffectPreset] = [.original, .bassBoost, .vocal, .electronic]
    private let scenes: [AudioEffectPreset] = [.saturn, .orbit, .sewer, .deepSpaceRadio, .cassette, .underwater, .cathedral, .bathroom]

    var body: some View {
        let _ = appLanguage
        Form {
            if appModel.videoURL != nil {
                Section {
                    Label(appModel.videoSession.videoAudioStatus.localizedTitle,
                          systemImage: appModel.videoSession.videoAudioStatus.symbol)
                    Text(appModel.videoSession.videoAudioStatus.localizedDetail)
                        .font(.callout).foregroundStyle(theme.mutedText)
                }
            }
            Section {
                Picker(AppLanguage.localized("音效模式"), selection: presetBinding) {
                    Section(AppLanguage.localized("等化器")) {
                        ForEach(equalizers, id: \.self) { Text($0.localizedName).tag($0) }
                    }
                    Section(AppLanguage.localized("音場場景")) {
                        ForEach(scenes, id: \.self) { Text($0.localizedName).tag($0) }
                    }
                    Text(AudioEffectPreset.custom.localizedName).tag(AudioEffectPreset.custom)
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44)
                .accessibilityIdentifier("audio-effects-preset")
                Text(appModel.audioEffects.preset.localizedDetail)
                    .font(.callout).foregroundStyle(theme.mutedText)
                if reduceMotion {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) { explorationButtons }
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) { explorationButtons }
                            VStack(alignment: .leading, spacing: 8) { explorationButtons }
                        }
                    }
                } else {
                    HStack(spacing: 12) { explorationButtons }
                }
                Text(AppLanguage.localized(appModel.isComparingOriginalSound
                     ? "目前對照原音。返回音效後，強度與自訂值會保留。"
                     : "用同一首歌探索不同音色，隨時對照原音。"))
                    .font(.caption).foregroundStyle(theme.mutedText)
            }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent(AppLanguage.localized("音效強度"), value: percent(appModel.audioEffects.intensity))
                    Slider(value: intensityBinding, in: 0...1, step: 0.01)
                        .frame(minHeight: 44)
                        .accessibilityLabel(AppLanguage.localized("音效強度"))
                        .accessibilityValue(percent(appModel.audioEffects.intensity))
                        .accessibilityIdentifier("audio-effects-intensity")
                }
                .disabled(appModel.audioEffects.preset == .original)
                Text(AppLanguage.localized("0% 為原音。從低強度開始，依歌曲調整。"))
                    .font(.caption).foregroundStyle(theme.mutedText)
            }
            if appModel.audioEffects.preset == .custom {
                Section(AppLanguage.localized("自訂音效")) {
                    parameterSlider("混響", keyPath: \.reverb, range: 0...100, suffix: "%")
                    parameterSlider("延遲", keyPath: \.delay, range: 0...500, suffix: " ms")
                    parameterSlider("低音", keyPath: \.bass, range: -12...12, suffix: " dB")
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent(AppLanguage.localized("濾波截止"), value: number(appModel.audioEffects.custom.filter) + " Hz")
                        Slider(value: filterBinding, in: log2(150)...log2(20_000))
                            .frame(minHeight: 44)
                            .accessibilityLabel(AppLanguage.localized("濾波截止"))
                            .accessibilityValue(number(appModel.audioEffects.custom.filter) + " Hz")
                    }
                    parameterSlider("音場寬度", keyPath: \.width, range: 0...2, suffix: "×")
                    parameterSlider("失真", keyPath: \.distortion, range: 0...100, suffix: "%")
                }
            }
            Section {
                Button(AppLanguage.localized("恢復原音"), systemImage: "arrow.counterclockwise") {
                    appModel.updateAudioEffects(AudioEffectsSettings())
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("audio-effects-reset")
            }
        }
        .disabled(appModel.videoURL != nil && !appModel.videoSession.videoAudioStatus.allowsEffects)
        .formStyle(.grouped)
        .modifier(CMVStorybookContainerStyle())
        .tint(theme.primary)
        .navigationTitle(AppLanguage.localized("音效"))
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppLanguage.localized("完成")) {
                        appModel.setOriginalSoundComparison(false)
                        dismiss()
                    }
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .accessibilityIdentifier("audio-effects-panel")
        .onDisappear { appModel.setOriginalSoundComparison(false) }
    }

    @ViewBuilder
    private var explorationButtons: some View {
        Button {
            let index = scenes.firstIndex(of: appModel.audioEffects.preset)
            let next = index.map { ($0 + 1) % scenes.count } ?? 0
            var settings = appModel.audioEffects
            settings.preset = scenes[next]
            if settings.intensity == 0 { settings.intensity = 0.3 }
            appModel.updateAudioEffects(settings)
        } label: {
            explorationButtonLabel(AppLanguage.localized("下一個音色"), systemImage: "sparkles")
        }
        .buttonStyle(.bordered)
        .frame(minWidth: 0, maxWidth: reduceMotion ? nil : .infinity)
        .accessibilityLabel(AppLanguage.localized("下一個音色"))
        .accessibilityHint(AppLanguage.localized("依序探索八種音場場景，不改動播放佇列"))
        .accessibilityIdentifier("audio-effects-explore")

        Button {
            appModel.setOriginalSoundComparison(!appModel.isComparingOriginalSound)
        } label: {
            explorationButtonLabel(
                AppLanguage.localized(appModel.isComparingOriginalSound ? "返回音效" : "對照原音"),
                systemImage: appModel.isComparingOriginalSound ? "slider.horizontal.3" : "waveform"
            )
        }
        .buttonStyle(.bordered)
        .frame(minWidth: 0, maxWidth: reduceMotion ? nil : .infinity)
        .accessibilityLabel(AppLanguage.localized(appModel.isComparingOriginalSound ? "返回音效" : "對照原音"))
        .disabled((appModel.videoURL != nil
                   && appModel.videoSession.videoAudioStatus != .supported)
                  || (!appModel.isComparingOriginalSound
                      && (appModel.audioEffects.preset == .original || appModel.audioEffects.intensity == 0)))
        .accessibilityValue(appModel.isComparingOriginalSound
                            ? AppLanguage.localized("原音") : appModel.audioEffects.preset.localizedName)
        .accessibilityIdentifier("audio-effects-compare")
    }

    @ViewBuilder
    private func explorationButtonLabel(_ text: String, systemImage: String) -> some View {
        if reduceMotion {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .modifier(PlaybackIconSize(points: 18))
                    .fixedSize()
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                           alignment: .leading)
            }
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                       alignment: .leading)
                .frame(minHeight: 44)
        } else {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .modifier(PlaybackIconSize(points: 18))
                    .fixedSize()
                MarqueeText(text: text)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 44)
        }
    }

    private var presetBinding: Binding<AudioEffectPreset> {
        Binding(get: { appModel.audioEffects.preset }, set: { preset in
            var settings = appModel.audioEffects
            settings.preset = preset
            appModel.updateAudioEffects(settings)
        })
    }

    private var intensityBinding: Binding<Double> {
        Binding(get: { appModel.audioEffects.intensity }, set: { intensity in
            var settings = appModel.audioEffects
            settings.intensity = intensity
            appModel.updateAudioEffects(settings)
        })
    }

    private func customBinding(_ keyPath: WritableKeyPath<AudioEffectParameters, Double>) -> Binding<Double> {
        Binding(get: { appModel.audioEffects.custom[keyPath: keyPath] }, set: { value in
            var settings = appModel.audioEffects
            settings.custom[keyPath: keyPath] = value
            appModel.updateAudioEffects(settings)
        })
    }

    private var filterBinding: Binding<Double> {
        let binding = customBinding(\.filter)
        return Binding(get: { log2(binding.wrappedValue) }, set: { binding.wrappedValue = pow(2, $0) })
    }

    private func parameterSlider(_ title: String, keyPath: WritableKeyPath<AudioEffectParameters, Double>,
                                 range: ClosedRange<Double>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent(AppLanguage.localized(title), value: number(appModel.audioEffects.custom[keyPath: keyPath]) + suffix)
            Slider(value: customBinding(keyPath), in: range)
                .frame(minHeight: 44)
                .accessibilityLabel(AppLanguage.localized(title))
                .accessibilityValue(number(appModel.audioEffects.custom[keyPath: keyPath]) + suffix)
        }
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(AppLanguage.currentLocale))
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)).locale(AppLanguage.currentLocale))
    }
}
