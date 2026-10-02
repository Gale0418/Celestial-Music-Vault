import SwiftUI
import CMVThemes

/// Shared paper stock keeps the daylight theme coherent across native surfaces.
struct StorybookPaper: View {
    var cornerRadius: CGFloat = 24
    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(theme.surface.opacity(reduceTransparency || contrast == .increased ? 1 : 0.96))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(theme.metal.opacity(contrast == .increased ? 1 : 0.48),
                                  lineWidth: contrast == .increased ? 2 : 1.5)
            }
            .shadow(color: theme.text.opacity(reduceTransparency ? 0 : 0.10), radius: 8, x: 0, y: 4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct StorybookRainbowRule: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(CMVTheme.storybookRainbow.indices, id: \.self) { index in
                CMVTheme.storybookRainbow[index]
            }
        }
        .frame(height: 4)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The illustration is outside the display clock. Only the existing bounded
/// mascot pool animates; astronomical labels do not belong to this storybook.
struct SheepStorybookBackground: View {
    var seedOffset = 0
    @Environment(\.cmvTheme) private var theme
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("SheepRainbowMeadow")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                if !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1.0 / 20.0,
                                            paused: !isVisible || scenePhase != .active)) { timeline in
                        Canvas { context, size in
                            let level = appModel.isCurrentMediaPlaying
                                ? Double(min(1, max(0, appModel.audioEnergy.snapshot.level))) : 0
                            StarfallRenderer.draw(in: &context, size: size,
                                                  time: timeline.date.timeIntervalSinceReferenceDate,
                                                  theme: theme, seedOffset: seedOffset,
                                                  audioLevel: level)
                        }
                    }
                    .isolatedAnimationSurface()
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}
