import SwiftUI
import Foundation

#if os(iOS)
import CoreMotion
import UIKit
#else
import AppKit
#endif

/// A normalized, bounded parallax sample shared by the celestial decorations.
///
/// `x` and `y` are always in `-1...1`. The layer specific values intentionally
/// keep the visual movement small enough that the artwork remains stable.
struct CelestialParallaxSample: Equatable, Sendable {
    let x: CGFloat
    let y: CGFloat

    static let zero = CelestialParallaxSample(x: 0, y: 0)

    init(x: CGFloat, y: CGFloat) {
        self.x = Self.clamp(x)
        self.y = Self.clamp(y)
    }

    /// Maximum displacement for the sky artwork.
    var backgroundOffset: CGSize {
        CGSize(width: x * 24, height: y * 24)
    }

    /// Maximum displacement for the Now Playing cover artwork.
    var coverOffset: CGSize {
        CGSize(width: x * 10, height: y * 10)
    }

    /// Maximum cover tilt. The caller can use this with `rotationEffect`.
    var coverRotationDegrees: Double {
        Double(x) * 5
    }

    fileprivate func offset(for layer: CelestialParallaxLayer) -> CGSize {
        switch layer {
        case .distantBackground: CGSize(width: -x * 8, height: -y * 8)
        case .background: backgroundOffset
        case .cover: coverOffset
        }
    }

    fileprivate func rotation(for layer: CelestialParallaxLayer) -> Angle {
        layer == .cover ? .degrees(coverRotationDegrees) : .zero
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return min(1, max(-1, value))
    }
}

enum CelestialParallaxLayer {
    case distantBackground
    case background
    case cover
}

/// A light response tied only to input, never to an idle animation clock.
private struct CelestialCardSheen: ViewModifier {
    let sample: CelestialParallaxSample
    let enabled: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .overlay {
                if enabled && !reduceTransparency {
                    GeometryReader { geometry in
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.15),
                                .init(color: .cyan.opacity(0.18), location: 0.40),
                                .init(color: .white.opacity(0.30), location: 0.49),
                                .init(color: .yellow.opacity(0.10), location: 0.58),
                                .init(color: .clear, location: 0.82)
                            ], startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .offset(x: sample.x * geometry.size.width * 0.24,
                                y: sample.y * geometry.size.height * 0.24)
                        .blendMode(.screen)
                    }
                    .clipShape(Circle())
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .rotation3DEffect(.degrees(enabled ? -Double(sample.y) * 10 : 0),
                              axis: (x: 1, y: 0, z: 0), perspective: 0.35)
            .rotation3DEffect(.degrees(enabled ? Double(sample.x) * 10 : 0),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.35)
    }
}

#if os(iOS)

/// The one shared iOS motion source used by all celestial parallax modifiers.
///
/// Relative device attitude is used here. Info.plist declares the purpose with
/// NSMotionUsageDescription as required by Core Motion's privacy contract. The manager is started
/// only while at least one visible modifier has a lease and is stopped when the
/// last lease disappears (including when the scene becomes inactive).
@MainActor
final class CelestialParallaxMotion: ObservableObject {
    static let shared = CelestialParallaxMotion()

    private static let manager = CMMotionManager()
    @Published private(set) var sample = CelestialParallaxSample.zero

    private var leaseCount = 0
    private var pollTask: Task<Void, Never>?
    private var filteredX = 0.0
    private var filteredY = 0.0
    private var publishedX = 0.0
    private var publishedY = 0.0
    private var referenceAttitude: CMAttitude?
    private var referenceOrientation: UIInterfaceOrientation?

    private init() {}

    func acquire() {
        leaseCount += 1
        guard leaseCount == 1 else { return }
        startUpdatesIfAvailable()
    }

    func release() {
        guard leaseCount > 0 else { return }
        leaseCount -= 1
        guard leaseCount == 0 else { return }

        pollTask?.cancel()
        pollTask = nil
        Self.manager.stopDeviceMotionUpdates()
        filteredX = 0
        filteredY = 0
        publishedX = 0
        publishedY = 0
        sample = .zero
        referenceAttitude = nil
        referenceOrientation = nil
    }

    private func startUpdatesIfAvailable() {
        guard Self.manager.isDeviceMotionAvailable else {
            sample = .zero
            return
        }

        // 20 Hz is enough for a quiet, tactile tilt response without creating
        // a display-clock loop or unnecessary work while the view is visible.
        Self.manager.deviceMotionUpdateInterval = 1.0 / 20.0
        Self.manager.startDeviceMotionUpdates(using: .xArbitraryZVertical)
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled, self.leaseCount > 0 {
                if let attitude = Self.manager.deviceMotion?.attitude {
                    self.consume(attitude: attitude)
                }
                // Poll only the latest sample. A busy main actor drops old
                // positions instead of accumulating one task per callback.
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func consume(attitude: CMAttitude) {
        guard leaseCount > 0 else { return }
        let orientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?.interfaceOrientation ?? .portrait
        // Calibrate once per active session/orientation, never continuously.
        // Relative attitude still responds when the iPad is held upright,
        // where raw gravity was already near its limit and barely changed.
        guard let referenceAttitude, referenceOrientation == orientation else {
            referenceAttitude = attitude.copy() as? CMAttitude
            referenceOrientation = orientation
            filteredX = 0; filteredY = 0
            publishedX = 0; publishedY = 0
            sample = .zero
            return
        }
        guard let relative = attitude.copy() as? CMAttitude else { return }
        relative.multiply(byInverseOf: referenceAttitude)
        let matrix = relative.rotationMatrix
        let horizontal = atan2(matrix.m13, matrix.m33)
        let vertical = atan2(matrix.m23, matrix.m33)
        let screenTilt: (x: Double, y: Double)
        switch orientation {
        case .portrait: screenTilt = (horizontal, -vertical)
        case .portraitUpsideDown: screenTilt = (-horizontal, vertical)
        case .landscapeLeft: screenTilt = (-vertical, -horizontal)
        case .landscapeRight: screenTilt = (vertical, horizontal)
        default: screenTilt = (horizontal, -vertical)
        }
        // 12 degrees reaches full travel; ordinary small tilts remain visible.
        let fullTravel = 12.0 * Double.pi / 180.0
        let targetX = max(-1, min(1, screenTilt.x.isFinite ? screenTilt.x / fullTravel : 0))
        let targetY = max(-1, min(1, screenTilt.y.isFinite ? screenTilt.y / fullTravel : 0))
        let smoothing: Double = 0.22
        filteredX += (targetX - filteredX) * smoothing
        filteredY += (targetY - filteredY) * smoothing

        // Do not invalidate SwiftUI for sub-pixel sensor noise. The hysteresis
        // lets a real, deliberate tilt cross the threshold while a stationary
        // device remains visually still.
        guard abs(filteredX - publishedX) >= 0.015
            || abs(filteredY - publishedY) >= 0.015 else { return }

        publishedX = filteredX
        publishedY = filteredY
        sample = CelestialParallaxSample(
            x: CGFloat(filteredX),
            y: CGFloat(filteredY)
        )
    }
}

@MainActor
private struct CelestialParallaxMotionModifier: ViewModifier {
    let layer: CelestialParallaxLayer
    let enabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var motion: CelestialParallaxMotion
    @State private var hasLease = false

    init(layer: CelestialParallaxLayer, enabled: Bool) {
        self.layer = layer
        self.enabled = enabled
        _motion = ObservedObject(wrappedValue: CelestialParallaxMotion.shared)
    }

    private var shouldRun: Bool {
        enabled && !reduceMotion && scenePhase == .active
    }

    func body(content: Content) -> some View {
        let visibleSample = shouldRun ? motion.sample : .zero

        content
            .modifier(CelestialCardSheen(sample: visibleSample, enabled: layer == .cover && shouldRun))
            .offset(visibleSample.offset(for: layer))
            .rotationEffect(visibleSample.rotation(for: layer))
            .onAppear { reconcileLease() }
            .onChange(of: scenePhase) { _, _ in reconcileLease() }
            .onChange(of: reduceMotion) { _, _ in reconcileLease() }
            .onChange(of: enabled) { _, _ in reconcileLease() }
            .onDisappear { releaseLease() }
    }

    private func reconcileLease() {
        if shouldRun {
            guard !hasLease else { return }
            motion.acquire()
            hasLease = true
        } else {
            releaseLease()
        }
    }

    private func releaseLease() {
        guard hasLease else { return }
        motion.release()
        hasLease = false
    }
}

#else

private struct CelestialPointerSampleKey: EnvironmentKey {
    static let defaultValue = CelestialParallaxSample.zero
}

private extension EnvironmentValues {
    var celestialPointerSample: CelestialParallaxSample {
        get { self[CelestialPointerSampleKey.self] }
        set { self[CelestialPointerSampleKey.self] = newValue }
    }
}

/// Read this window's pointer without consuming events or blocking controls.
private struct CelestialPointerReader: NSViewRepresentable {
    let onSample: (CelestialParallaxSample) -> Void

    func makeNSView(context: Context) -> PointerView {
        let view = PointerView()
        view.onSample = onSample
        return view
    }

    func updateNSView(_ view: PointerView, context: Context) {
        view.onSample = onSample
    }

    static func dismantleNSView(_ view: PointerView, coordinator: ()) { view.stop() }

    final class PointerView: NSView {
        var onSample: (CelestialParallaxSample) -> Void = { _ in }
        private var monitor: Any?
        private weak var observedWindow: NSWindow?
        private var previouslyAcceptedMovement = false
        private var lastUpdate: TimeInterval = 0

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard let window else { return }
            observedWindow = window
            previouslyAcceptedMovement = window.acceptsMouseMovedEvents
            window.acceptsMouseMovedEvents = true
            monitor = NSEvent.addLocalMonitorForEvents(matching: [
                .mouseMoved, .leftMouseDragged, .rightMouseDragged,
                .otherMouseDragged, .mouseEntered, .mouseExited, .leftMouseDown
            ]) { [weak self] event in
                // AppKit delivers local event monitors on the main thread.
                MainActor.assumeIsolated { self?.consume(event) }
                return event
            }
        }

        private func consume(_ event: NSEvent) {
            guard let window, event.window === window, window.isKeyWindow else { return }
            let point = convert(event.locationInWindow, from: nil)
            guard bounds.contains(point), bounds.width > 0, bounds.height > 0 else {
                onSample(.zero)
                return
            }
            let now = Date.timeIntervalSinceReferenceDate
            guard event.type == .leftMouseDown || now - lastUpdate >= 1.0 / 30.0 else { return }
            lastUpdate = now
            onSample(CelestialParallaxSample(
                x: (point.x - bounds.minX) / bounds.width * 2 - 1,
                y: 1 - (point.y - bounds.minY) / bounds.height * 2))
        }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            if let observedWindow, !previouslyAcceptedMovement {
                observedWindow.acceptsMouseMovedEvents = false
            }
            observedWindow = nil
        }
    }
}

private struct CelestialPointerSurface: ViewModifier {
    let enabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var sample = CelestialParallaxSample.zero

    private var shouldTrack: Bool { enabled && !reduceMotion && scenePhase == .active }

    func body(content: Content) -> some View {
        content
            .environment(\.celestialPointerSample, shouldTrack ? sample : .zero)
            .background {
                if shouldTrack {
                    CelestialPointerReader { next in
                        if sample != next { sample = next }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .onChange(of: shouldTrack) { _, active in
                if !active { sample = .zero }
            }
            .onDisappear { sample = .zero }
    }
}

/// All Mac depth layers share the window's pointer sample, including while
/// the pointer crosses a control or album artwork. No idle animation is used.
@MainActor
private struct CelestialParallaxHoverModifier: ViewModifier {
    let layer: CelestialParallaxLayer
    let enabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.celestialPointerSample) private var pointerSample

    private var shouldTrack: Bool { enabled && !reduceMotion && scenePhase == .active }

    func body(content: Content) -> some View {
        let visibleSample = shouldTrack ? pointerSample : .zero
        content
            .modifier(CelestialCardSheen(sample: visibleSample, enabled: layer == .cover && shouldTrack))
            .offset(visibleSample.offset(for: layer))
            .rotationEffect(visibleSample.rotation(for: layer))
    }
}

#endif

extension View {
    @ViewBuilder
    func celestialPointerSurface(enabled: Bool) -> some View {
        #if os(macOS)
        modifier(CelestialPointerSurface(enabled: enabled))
        #else
        self
        #endif
    }

    /// Applies a bounded, non-animated celestial parallax response.
    ///
    /// On iOS the response follows calibrated device attitude. On macOS it follows the
    /// pointer while hovering over this view. Reduce Motion and inactive scene
    /// phases always return the layer to its neutral position.
    @ViewBuilder
    func celestialParallax(
        _ layer: CelestialParallaxLayer,
        enabled: Bool = true
    ) -> some View {
        #if os(iOS)
        modifier(CelestialParallaxMotionModifier(layer: layer, enabled: enabled))
        #else
        modifier(CelestialParallaxHoverModifier(layer: layer, enabled: enabled))
        #endif
    }
}
