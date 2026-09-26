import SwiftUI
import Foundation

#if os(iOS)
import CoreMotion
import UIKit
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
        CGSize(width: x * 4, height: y * 4)
    }

    /// Maximum displacement for the Now Playing cover artwork.
    var coverOffset: CGSize {
        CGSize(width: x * 4, height: y * 4)
    }

    /// Maximum cover tilt. The caller can use this with `rotationEffect`.
    var coverRotationDegrees: Double {
        Double(x) * 5
    }

    fileprivate func offset(for layer: CelestialParallaxLayer) -> CGSize {
        switch layer {
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
    case background
    case cover
}

#if os(iOS)

/// The one shared iOS motion source used by all celestial parallax modifiers.
///
/// Device motion gravity is used here. Info.plist declares the purpose with
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
                if let gravity = Self.manager.deviceMotion?.gravity {
                    self.consume(gravityX: gravity.x, gravityY: gravity.y)
                }
                // Poll only the latest sample. A busy main actor drops old
                // positions instead of accumulating one task per callback.
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func consume(gravityX: Double, gravityY: Double) {
        guard leaseCount > 0 else { return }

        // A small one-pole low pass removes hand tremor while preserving a
        // deliberate tilt. Gravity is already bounded by Core Motion, but the
        // clamp keeps malformed readings from escaping the visual budget.
        let orientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?.interfaceOrientation ?? .portrait
        let screenGravity: (x: Double, y: Double)
        switch orientation {
        case .portrait:
            screenGravity = (gravityX, -gravityY)
        case .portraitUpsideDown:
            screenGravity = (-gravityX, gravityY)
        case .landscapeLeft:
            screenGravity = (-gravityY, -gravityX)
        case .landscapeRight:
            screenGravity = (gravityY, gravityX)
        default:
            screenGravity = (gravityX, -gravityY)
        }
        let targetX = max(-1, min(1, screenGravity.x.isFinite ? screenGravity.x : 0))
        let targetY = max(-1, min(1, screenGravity.y.isFinite ? screenGravity.y : 0))
        let smoothing: Double = 0.16
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

/// macOS has no Core Motion source in this feature. The same modifier samples
/// the pointer position while it is over the view, so a stationary pointer
/// produces a stationary value and leaving the view returns it to zero.
@MainActor
private struct CelestialParallaxHoverModifier: ViewModifier {
    let layer: CelestialParallaxLayer
    let enabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var hoverSample = CelestialParallaxSample.zero
    @State private var contentSize = CGSize.zero

    private var shouldTrack: Bool {
        enabled && !reduceMotion && scenePhase == .active
    }

    func body(content: Content) -> some View {
        let visibleSample = shouldTrack ? hoverSample : .zero

        content
            .offset(visibleSample.offset(for: layer))
            .rotationEffect(visibleSample.rotation(for: layer))
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                contentSize = newSize
            }
            .onContinuousHover(coordinateSpace: .local) { phase in
                guard shouldTrack else { return }
                switch phase {
                case .active(let location):
                    let width = max(contentSize.width, 1)
                    let height = max(contentSize.height, 1)
                    let normalizedX = (location.x / width) * 2 - 1
                    let normalizedY = (location.y / height) * 2 - 1
                    hoverSample = CelestialParallaxSample(
                        x: normalizedX,
                        y: normalizedY
                    )
                case .ended:
                    hoverSample = .zero
                }
            }
            .onChange(of: reduceMotion) { _, _ in
                if reduceMotion { hoverSample = .zero }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { hoverSample = .zero }
            }
            .onChange(of: enabled) { _, isEnabled in
                if !isEnabled { hoverSample = .zero }
            }
    }
}

#endif

extension View {
    /// Applies a bounded, non-animated celestial parallax response.
    ///
    /// On iOS the response follows device gravity. On macOS it follows the
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
