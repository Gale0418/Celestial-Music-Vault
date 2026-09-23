import SwiftUI
import CMVThemes
#if os(macOS)
import AppKit

/// A decoration owns its own SwiftUI graph. Display-clock invalidations cannot
/// negotiate the size of the surrounding navigation, artwork, or queue rows.
private struct IsolatedAnimationSurface<Content: View>: NSViewRepresentable {
    @Environment(\.cmvTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    let content: Content

    private var hostedContent: AnyView {
        AnyView(content
            .environment(\.cmvTheme, theme)
            .environment(\.scenePhase, scenePhase)
            .environment(\.colorScheme, colorScheme)
            .environment(\.displayScale, displayScale))
    }

    func makeNSView(context: Context) -> AnimationContainer {
        AnimationContainer(content: hostedContent)
    }

    func updateNSView(_ view: AnimationContainer, context: Context) {
        view.host.rootView = hostedContent
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: AnimationContainer, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions(by: .zero)
    }

    final class AnimationContainer: NSView {
        let host: NSHostingView<AnyView>

        init(content: AnyView) {
            host = NSHostingView(rootView: content)
            super.init(frame: .zero)
            host.sizingOptions = []
            host.autoresizingMask = [.width, .height]
            addSubview(host)
        }

        required init?(coder: NSCoder) { nil }

        override func layout() {
            super.layout()
            if host.frame != bounds { host.frame = bounds }
        }

        // Decorations must not intercept video controls or scroll gestures.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
#endif

extension View {
    @ViewBuilder
    func isolatedAnimationSurface() -> some View {
        #if os(macOS)
        IsolatedAnimationSurface(content: self)
            .accessibilityHidden(true)
        #else
        self
        #endif
    }
}
