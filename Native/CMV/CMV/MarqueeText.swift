import SwiftUI

/// A single-line label that scrolls only when its measured text exceeds its container.
struct MarqueeText: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var availableWidth: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var animationStart = Date.now
    @State private var isVisible = false

    private var isOverflowing: Bool {
        textWidth > availableWidth + 0.5
    }

    private var shouldAnimate: Bool {
        isVisible && availableWidth > 0 && textWidth > 0 && isOverflowing && !reduceMotion && scenePhase == .active
    }

    var body: some View {
        Text(text)
            .lineLimit(1)
            .truncationMode(.tail)
            .opacity(shouldAnimate ? 0 : 1)
            .overlay(alignment: .leading) {
                if shouldAnimate {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        Text(text)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(width: availableWidth, alignment: .leading)
                            .offset(x: marqueeOffset(at: timeline.date,
                                                     travelDistance: textWidth - availableWidth))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.width
            } action: { width in
                if width != availableWidth { availableWidth = width }
            }
            .overlay(alignment: .topLeading) {
                Text(text)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .opacity(0)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                    .onGeometryChange(for: CGFloat.self) { geometry in
                        geometry.size.width
                    } action: { width in
                        if width != textWidth { textWidth = width }
                    }
            }
            .onAppear {
            isVisible = true
            animationStart = .now
        }
        .onDisappear { isVisible = false }
        .onChange(of: text) { _, _ in restartAnimation() }
        .onChange(of: availableWidth) { _, _ in restartAnimation() }
        .onChange(of: textWidth) { _, _ in restartAnimation() }
        .onChange(of: shouldAnimate) { _, active in
            if active { restartAnimation() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text))
    }

    private func restartAnimation() {
        animationStart = .now
    }

    private func marqueeOffset(at date: Date, travelDistance: CGFloat) -> CGFloat {
        guard travelDistance > 0 else { return 0 }
        let pause: TimeInterval = 1.8
        let travelDuration = max(1.0, Double(travelDistance) / 22.0)
        let cycle = pause * 2 + travelDuration * 2
        let elapsed = max(0, date.timeIntervalSince(animationStart)).truncatingRemainder(dividingBy: cycle)

        if elapsed < pause { return 0 }
        if elapsed < pause + travelDuration {
            let progress = smoothStep((elapsed - pause) / travelDuration)
            return -travelDistance * progress
        }
        if elapsed < pause + travelDuration + pause { return -travelDistance }

        let progress = smoothStep((elapsed - pause - travelDuration - pause) / travelDuration)
        return -travelDistance * (1 - progress)
    }

    private func smoothStep(_ value: TimeInterval) -> CGFloat {
        let clamped = min(1, max(0, value))
        return CGFloat(clamped * clamped * (3 - 2 * clamped))
    }
}
