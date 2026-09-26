import SwiftUI
import SwiftData
import Foundation
import ImageIO
import CMVLibrary
import CMVThemes
#if os(iOS)
import UIKit
#else
import AppKit
#endif

private func cmvLocalizedFormat(_ key: String, arguments: CVarArg...) -> String {
    let preference = UserDefaults.standard.string(forKey: AppLanguage.preferenceKey) ?? "system"
    return String(
        format: AppLanguage.localized(key),
        locale: AppLanguage.locale(for: preference),
        arguments: arguments
    )
}

struct CelestialBackground: View {
    var starSeedOffset = 0
    var showsLabels = true

    @Environment(\.cmvTheme) private var theme
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.scenePhase) private var scenePhase
    @State private var skyElapsed: TimeInterval = 0
    @State private var skyAnchor: TimeInterval?
    @State private var planisphereDate = Date.now
    @State private var isVisible = false

    private var shouldAnimate: Bool {
        !reduceMotion && scenePhase == .active && isVisible
    }

    var body: some View {
        GeometryReader { geometry in
        let overscan: CGFloat = 12
        let portraitShift = backgroundPortraitShift(for: geometry.size)
        // The leftward portrait crop must keep artwork behind the full viewport.
        // Widen both the image and Canvas so the shifted right edge never reveals
        // the view below; their shared size preserves the ring/atmosphere map.
        let contentSize = CGSize(width: geometry.size.width + overscan + 2 * abs(portraitShift),
                                 height: geometry.size.height + overscan)
        let artworkScale = max(contentSize.width / 1586, contentSize.height / 992)
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !shouldAnimate)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let time = reduceMotion ? 0 : skyElapsed + (skyAnchor.map { max(0, now - $0) } ?? 0)
            ZStack {
                if reduceTransparency {
                    theme.background
                } else {
                    Image(backgroundAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: contentSize.width, height: contentSize.height)
                        .clipped()
                        .layerEffect(
                            ShaderLibrary.saturnAtmosphere(
                                .float2(Float(contentSize.width), Float(contentSize.height)),
                                .float(Float(time.truncatingRemainder(dividingBy: 5760))),
                                .image(Image("SaturnCloudMap"))
                            ),
                            maxSampleOffset: CGSize(width: 50 * artworkScale, height: 28 * artworkScale),
                            isEnabled: theme.id == .titaniumEclipse
                        )
                        .saturation(1.05)
                        .overlay(theme.background.opacity(backgroundOverlayOpacity))
                }
                Canvas { context, size in
                    // Every stationary light is astronomical data. The theme
                    // artwork deliberately contains no baked point stars.
                    PlanisphereRenderer.draw(
                        in: &context,
                        size: size,
                        date: planisphereDate,
                        twinkleTime: time,
                        showsLabels: showsLabels,
                        theme: theme
                    )
                    if theme.id == .titaniumEclipse && !reduceTransparency {
                        SaturnRingRenderer.draw(in: &context, size: size, time: time)
                    }
                    if !reduceMotion {
                        let audioLevel = appModel.isCurrentMediaPlaying
                            ? Double(min(1, max(0, appModel.audioEnergy.snapshot.level)))
                            : 0
                        StarfallRenderer.draw(in: &context, size: size, time: time,
                                              theme: theme, seedOffset: starSeedOffset,
                                              audioLevel: audioLevel)
                    }
                }
            }
        }
        .isolatedAnimationSurface()
        .frame(width: contentSize.width, height: contentSize.height)
        .offset(x: portraitShift)
        .celestialParallax(.background, enabled: backgroundParallaxEnabled)
        .frame(width: geometry.size.width, height: geometry.size.height)
        .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            isVisible = true
            planisphereDate = .now
            updateSkyClock(running: shouldAnimate)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { planisphereDate = .now }
        }
        .onChange(of: shouldAnimate) { _, running in updateSkyClock(running: running) }
        .onDisappear {
            isVisible = false
            updateSkyClock(running: false)
        }
    }

    private var backgroundAssetName: String {
        switch theme.id {
        case .crimsonNebula: "SkyCrimsonNebula"
        case .titaniumEclipse: "SkySaturnOrbit"
        case .emeraldAurora: "SkyEmeraldAurora"
        case .amberDawn: "SkyAmberDawn"
        }
    }

    private var backgroundOverlayOpacity: Double {
        let baseOpacity: Double
        switch theme.id {
        case .amberDawn: baseOpacity = 0.32
        case .emeraldAurora: baseOpacity = 0.24
        case .crimsonNebula, .titaniumEclipse: baseOpacity = 0.10
        }
        return colorSchemeContrast == .increased ? min(0.22, baseOpacity + 0.08) : baseOpacity
    }

    private func backgroundPortraitShift(for size: CGSize) -> CGFloat {
        #if os(iOS)
        guard theme.id == .titaniumEclipse,
              UIDevice.current.userInterfaceIdiom == .pad,
              size.height > size.width else { return 0 }
        // In portrait the height determines the image scale. Align its right
        // edge with the viewport so the globe centre lands near the right edge
        // rather than shrinking to a thin sliver as the window gets narrower.
        let heightScale = (size.height + 12) / 992
        let artworkWidth = 1586 * heightScale
        return -max(0, (artworkWidth - size.width - 12) / 2)
        #else
        return 0
        #endif
    }

    private var backgroundParallaxEnabled: Bool {
        #if os(iOS)
        theme.id == .titaniumEclipse
        #else
        false
        #endif
    }

    private func updateSkyClock(running: Bool) {
        let now = Date.timeIntervalSinceReferenceDate
        if running {
            if skyAnchor == nil { skyAnchor = now }
        } else if let skyAnchor {
            skyElapsed += max(0, now - skyAnchor)
            self.skyAnchor = nil
        }
    }
}

/// A restrained procedural glint layer for the foreground rings in
/// SkySaturnOrbit. The source artwork is 1586x992; all geometry stays in those
/// coordinates so aspect-fill scaling preserves alignment on every display.
private enum SaturnRingRenderer {
    private static let sourceSize = CGSize(width: 1586, height: 992)
    private static let ringCenter = CGPoint(x: 980, y: 600)
    private static let majorRadius: CGFloat = 760
    private static let minorRadius: CGFloat = 72
    private static let ringAngle: CGFloat = -0.50
    private static let foregroundStart: CGFloat = 0.15
    private static let foregroundEnd: CGFloat = 3.00
    private static let particleCount = 13

    private struct RingTransform {
        let center: CGPoint
        let majorRadius: CGFloat
        let minorRadius: CGFloat
        let major: CGVector
        let minor: CGVector
    }

    static func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        guard size.width > 0, size.height > 0, time.isFinite else { return }

        let scale = max(size.width / sourceSize.width, size.height / sourceSize.height)
        let drawnSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let origin = CGPoint(x: (size.width - drawnSize.width) / 2,
                             y: (size.height - drawnSize.height) / 2)
        let transform = RingTransform(
            center: CGPoint(x: origin.x + ringCenter.x * scale,
                            y: origin.y + ringCenter.y * scale),
            majorRadius: majorRadius * scale,
            minorRadius: minorRadius * scale,
            major: CGVector(dx: cos(ringAngle), dy: sin(ringAngle)),
            minor: CGVector(dx: -sin(ringAngle), dy: cos(ringAngle))
        )

        // The source already contains the complete ring and its planet occlusion.
        // Draw only moving glints on the foreground arc, preserving every static
        // edge and avoiding a synthetic, heavy annulus over the artwork.
        context.drawLayer { glints in
            drawParticles(in: &glints, transform: transform, time: time)
        }
    }

    private static func drawParticles(
        in context: inout GraphicsContext,
        transform: RingTransform,
        time: TimeInterval
    ) {
        let arcLength = foregroundEnd - foregroundStart
        for index in 0..<particleCount {
            let seed = Double(index)
            let phase = positiveRemainder(seed * 1.71, Double(arcLength))
            let speed = 0.082 + (seed.truncatingRemainder(dividingBy: 4) * 0.018)
            let angle = foregroundStart + CGFloat(
                positiveRemainder(Double(time) * speed + phase, Double(arcLength))
            )
            let widthOffset = CGFloat(sin(seed * 2.41)) * 0.46
            let center = ringPoint(angle: angle, offset: widthOffset, transform: transform)
            let tangent = ringTangent(angle: angle, transform: transform)
            let radius = max(0.8, transform.minorRadius * CGFloat(0.011 + (seed.truncatingRemainder(dividingBy: 3) * 0.004)))
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color(Color.white.opacity(0.12))
            )

            let tail = radius * 5.0
            var streak = Path()
            streak.move(to: CGPoint(x: center.x - tangent.dx * tail,
                                    y: center.y - tangent.dy * tail))
            streak.addLine(to: CGPoint(x: center.x + tangent.dx * radius,
                                       y: center.y + tangent.dy * radius))
            context.stroke(streak,
                           with: .color(Color(red: 1.0, green: 0.90, blue: 0.72).opacity(0.095)),
                           style: StrokeStyle(lineWidth: max(0.6, radius * 0.72), lineCap: .round))
        }
    }

    private static func ringPoint(angle: CGFloat, offset: CGFloat, transform: RingTransform) -> CGPoint {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        let majorDistance = transform.majorRadius * cosAngle
        let minorDistance = transform.minorRadius * (sinAngle + offset)
        return CGPoint(
            x: transform.center.x + transform.major.dx * majorDistance + transform.minor.dx * minorDistance,
            y: transform.center.y + transform.major.dy * majorDistance + transform.minor.dy * minorDistance
        )
    }

    private static func ringTangent(angle: CGFloat, transform: RingTransform) -> CGVector {
        let tangent = CGVector(
            dx: -transform.majorRadius * sin(angle) * transform.major.dx
                + transform.minorRadius * cos(angle) * transform.minor.dx,
            dy: -transform.majorRadius * sin(angle) * transform.major.dy
                + transform.minorRadius * cos(angle) * transform.minor.dy
        )
        let length = max(1, sqrt(tangent.dx * tangent.dx + tangent.dy * tangent.dy))
        return CGVector(dx: tangent.dx / length, dy: tangent.dy / length)
    }

    private static func positiveRemainder(_ value: Double, _ modulus: Double) -> Double {
        guard modulus > 0 else { return 0 }
        let remainder = value.truncatingRemainder(dividingBy: modulus)
        return remainder >= 0 ? remainder : remainder + modulus
    }
}

/// Navigation containers on iPad draw opaque backgrounds above their parent.
/// Keep one sky inside each visible destination, including pushed pages.
private struct CelestialPageBackground: ViewModifier {
    let showsLabels: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .scrollContentBackground(.hidden)
            .background { CelestialBackground(showsLabels: showsLabels) }
        #else
        content
        #endif
    }
}

extension View {
    func celestialPageBackground(showsLabels: Bool = true) -> some View {
        modifier(CelestialPageBackground(showsLabels: showsLabels))
    }
}

struct AlbumWorldView: View {
    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State private var decodedArtwork: CGImage?
    var size: CGFloat = 260
    var artworkID: UUID?
    var artworkData: Data?
    var albumTitle: String = AppLanguage.localized("專輯")
    let energyState: AudioEnergyState
    var isPlaying = false
    var tempoBPM: Double?

    var body: some View {
        ZStack {
            ZStack {
                Circle().fill(reduceTransparency ? AnyShapeStyle(theme.background) : AnyShapeStyle(.ultraThinMaterial))
                if !reduceTransparency {
                    Circle().fill(RadialGradient(colors: [theme.primary.opacity(0.92), theme.secondary.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: size / 2))
                    ForEach(0..<7, id: \.self) { index in
                        Circle()
                            .fill(Color.white.opacity(0.13 + Double(index % 3) * 0.07))
                            .frame(width: size * (0.26 + CGFloat(index % 3) * 0.08))
                            .blur(radius: 10)
                            .offset(x: CGFloat(index % 4 - 2) * size * 0.11, y: CGFloat(index / 3 - 1) * size * 0.14)
                    }
                }
                if let decodedArtwork {
                    Image(decorative: decodedArtwork, scale: 1, orientation: .up)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                        .padding(size * 0.08)
                } else {
                    fallbackArtwork
                }
                Circle().stroke(AngularGradient(colors: [theme.primary, theme.metal, theme.secondary, theme.primary], center: .center), lineWidth: colorSchemeContrast == .increased ? 4 : 3)
                    .shadow(color: reduceTransparency ? .clear : theme.primary,
                            radius: colorSchemeContrast == .increased ? 22 : 18)
            }
            .frame(width: size, height: size)
            .celestialParallax(.cover, enabled: theme.id == .titaniumEclipse)
            AudioEnergyRing(
                diameter: size,
                energyState: energyState,
                isActive: isPlaying,
                tempoBPM: tempoBPM
            )
        }
        .frame(width: size, height: size)
        .accessibilityLabel(cmvLocalizedFormat("%@專輯封面", arguments: albumTitle))
        .task(id: artworkRequestID) {
            guard let artworkData else {
                decodedArtwork = nil
                return
            }
            let maximumDimension = max(256, Int((size * 2).rounded(.up)))
            let image = await Task.detached(priority: .utility) {
                Self.downsampledImage(from: artworkData, maximumDimension: maximumDimension)
            }.value
            guard !Task.isCancelled else { return }
            decodedArtwork = image
        }
    }

    private var artworkRequestID: String {
        guard let artworkData else { return "none-\(Int(size))" }
        let prefixSignature = artworkData.prefix(16).reduce(into: UInt64(14_695_981_039_346_656_037)) {
            $0 = ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
        return "\(artworkID?.uuidString ?? "unknown")-\(artworkData.count)-\(prefixSignature)-\(Int(size))"
    }

    private nonisolated static func downsampledImage(from data: Data, maximumDimension: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    private var fallbackArtwork: some View {
        Image(systemName: "moon.stars.fill")
            .font(.system(size: size * 0.25, weight: .thin))
            .foregroundStyle(.white, theme.primary)
    }
}

/// Audio-driven moonlight: curved, tapered beams dissolve outward from the
/// circular baseline while the complete waveform rotates.
private struct AudioEnergyRing: View {
    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @State private var accumulatedRotationRadians: Double = 0
    @State private var rotationAnchor: TimeInterval?
    @State private var activeRotationDuration: TimeInterval = 12
    let diameter: CGFloat
    let energyState: AudioEnergyState
    let isActive: Bool
    let tempoBPM: Double?

    // A display-clock transform rotates the whole waveform continuously; the
    // angle is never quantized to a bar index.
    // Twenty-four beats per orbit keeps fast tracks livelier without restoring
    // the old four-second "saw blade" motion. Missing analysis stays at 12 s.
    private static let defaultRotationDuration: TimeInterval = 12
    private static let beatsPerRotation = 24.0
    private static let minimumTempoBPM = 60.0
    private static let maximumTempoBPM = 180.0
    private static let segmentCount = 128
    private static let unitVectors: [CGVector] = (0..<segmentCount).map { index in
        let angle = Double(index) / Double(segmentCount) * .pi * 2 - .pi / 2
        return CGVector(dx: cos(angle), dy: sin(angle))
    }
    private static let shadowVectors: [CGVector] = (0..<segmentCount).map { index in
        let angle = (Double(index) + 0.5) / Double(segmentCount) * .pi * 2 - .pi / 2
        return CGVector(dx: cos(angle), dy: sin(angle))
    }

    private var shouldRotate: Bool {
        !reduceMotion && !reduceTransparency && isActive && scenePhase == .active
    }

    var body: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 30.0,
            paused: reduceMotion || reduceTransparency || !isActive || scenePhase != .active
        )) { timeline in
            // Accessibility modes keep a deterministic silent ring. Do not read
            // the live meter, so producer updates cannot redraw its decoration.
            let snapshot: AudioEnergySnapshot = (reduceMotion || reduceTransparency)
                ? .silent
                : energyState.snapshot
            let timelineTime = timeline.date.timeIntervalSinceReferenceDate
            let elapsedRotationTime = rotationAnchor.map { max(0, timelineTime - $0) } ?? 0
            let activeRotationRadians = accumulatedRotationRadians
                + elapsedRotationTime * Self.radiansPerSecond(for: activeRotationDuration)
            let rotationRadians = (reduceMotion || reduceTransparency)
                ? 0
                : Self.normalizedRadians(activeRotationRadians)
            let elapsed = timelineTime - snapshot.publishedAt
            let rawBlend = min(1, max(0, elapsed / snapshot.interpolationDuration))
            let blend = reduceMotion ? 1 : rawBlend * rawBlend * (3 - 2 * rawBlend)

            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let baseRadius = diameter / 2
                let level = lerp(snapshot.previousLevel, snapshot.level, blend)
                let pulse = CGFloat(level) * 8
                let orbitRect = CGRect(
                    x: center.x - baseRadius,
                    y: center.y - baseRadius,
                    width: baseRadius * 2,
                    height: baseRadius * 2
                )
                context.stroke(
                    Path(ellipseIn: orbitRect),
                    with: .color(reduceTransparency ? theme.secondary : theme.secondary.opacity(isActive ? 0.46 : 0.30)),
                    style: StrokeStyle(lineWidth: 1.6)
                )
                if reduceTransparency { return }

                // Rotate the graphics context once instead of performing two
                // trigonometric transforms for every segment on every frame.
                context.translateBy(x: center.x, y: center.y)
                context.rotate(by: .radians(rotationRadians))
                context.translateBy(x: -center.x, y: -center.y)

                var moonlightHaze = Path()
                let beamColors = Gradient(stops: [
                    .init(color: .white.opacity(isActive ? 0.78 : 0.22), location: 0),
                    .init(color: theme.primary.opacity(isActive ? 0.42 : 0.12), location: 0.20),
                    .init(color: theme.primary.opacity(isActive ? 0.12 : 0.035), location: 0.50),
                    .init(color: .clear, location: 0.80),
                    .init(color: .clear, location: 1)
                ])
                let shadowColors = Gradient(stops: [
                    .init(color: Color(red: 0.34, green: 0.48, blue: 1.0)
                        .opacity(isActive ? 0.24 : 0.08), location: 0),
                    .init(color: theme.atmosphereSecondary.opacity(isActive ? 0.09 : 0.03), location: 0.42),
                    .init(color: .clear, location: 0.78),
                    .init(color: .clear, location: 1)
                ])

                // One shared subpixel blur softens the geometric edges and
                // suppresses shimmer while the dense ring moves slowly.
                context.drawLayer { softenedBeams in
                    softenedBeams.addFilter(.blur(radius: 1.1))
                    for (index, direction) in Self.unitVectors.enumerated() {
                    let previousSample = smoothedSample(
                        at: index,
                        samples: snapshot.previousSamples,
                        writeIndex: snapshot.previousWriteIndex
                    )
                    let currentSample = smoothedSample(
                        at: index,
                        samples: snapshot.samples,
                        writeIndex: snapshot.writeIndex
                    )
                    let sample = lerp(previousSample, currentSample, blend)
                    let energy = CGFloat(isActive ? max(0.045, sample) : 0.035)
                    let baseline = CGPoint(
                        x: center.x + direction.dx * baseRadius,
                        y: center.y + direction.dy * baseRadius
                    )
                    // Fixed spatial variation gives the light an irregular
                    // silhouette; only measured PCM controls its movement.
                    let variation = CGFloat((index * 37) % 23) / 22
                    let length = min(156, (28 + pulse + energy * 110) * (0.78 + variation * 0.48))
                    let halfWidth = min(4.4, baseRadius * 0.024) * (0.55 + variation * 0.45)
                    let tip = CGPoint(
                        x: center.x + direction.dx * (baseRadius + length),
                        y: center.y + direction.dy * (baseRadius + length)
                    )
                    let beam = Self.beamPath(start: baseline, direction: direction,
                                             length: length, halfWidth: halfWidth)
                    moonlightHaze.addPath(beam)
                    softenedBeams.fill(
                        beam,
                        with: .linearGradient(beamColors, startPoint: baseline, endPoint: tip)
                    )

                    let shadowDirection = Self.shadowVectors[index]
                    let shadowStart = CGPoint(
                        x: center.x + shadowDirection.dx * baseRadius,
                        y: center.y + shadowDirection.dy * baseRadius
                    )
                    let shadowLength = length * 0.74
                    let shadow = Self.beamPath(start: shadowStart, direction: shadowDirection,
                                               length: shadowLength, halfWidth: halfWidth * 0.48)
                    softenedBeams.fill(shadow, with: .linearGradient(
                        shadowColors, startPoint: shadowStart, endPoint: CGPoint(
                            x: shadowStart.x + shadowDirection.dx * shadowLength,
                            y: shadowStart.y + shadowDirection.dy * shadowLength
                        )
                    ))
                    }
                }
                let rayGradient = GraphicsContext.Shading.radialGradient(
                    Gradient(stops: [
                        .init(color: .white.opacity(isActive ? 0.98 : 0.42), location: 0),
                        .init(color: theme.primary.opacity(isActive ? 0.95 : 0.36), location: 0.3),
                        .init(color: theme.primary.opacity(isActive ? 0.65 : 0.24), location: 0.75),
                        .init(color: theme.primary.opacity(0), location: 1)
                    ]),
                    center: center, startRadius: baseRadius, endRadius: baseRadius + 156
                )
                // One bounded haze pass for all rays, never one filter per bar.
                if !reduceTransparency {
                    context.drawLayer { haze in
                        haze.addFilter(.blur(radius: 4.0))
                        haze.opacity = 0.26
                        haze.fill(moonlightHaze, with: rayGradient)
                    }
                }
            }
        }
        .frame(width: diameter + 336, height: diameter + 336)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            activeRotationDuration = targetRotationDuration
            updateRotationClock(rotating: shouldRotate)
        }
        .onChange(of: shouldRotate) { _, rotating in
            updateRotationClock(rotating: rotating)
        }
        .onChange(of: targetRotationDuration) { _, duration in
            updateRotationDuration(duration)
        }
    }

    /// A curved taper with a narrow rounded cap instead of a triangular spike.
    /// The gradient is already transparent before this geometric cap.
    private static func beamPath(start: CGPoint, direction: CGVector,
                                 length: CGFloat, halfWidth: CGFloat) -> Path {
        func point(_ distance: CGFloat, _ width: CGFloat) -> CGPoint {
            CGPoint(x: start.x + direction.dx * distance - direction.dy * width,
                    y: start.y + direction.dy * distance + direction.dx * width)
        }
        let tipWidth = max(0.32, halfWidth * 0.16)
        let taperDistance = max(0, length - max(1.2, halfWidth * 0.8))
        var path = Path()
        path.move(to: point(0, halfWidth))
        path.addCurve(to: point(taperDistance, tipWidth),
                      control1: point(length * 0.32, halfWidth * 0.92),
                      control2: point(length * 0.74, tipWidth * 1.25))
        path.addQuadCurve(to: point(taperDistance, -tipWidth),
                          control: point(length + tipWidth, 0))
        path.addCurve(to: point(0, -halfWidth),
                      control1: point(length * 0.74, -tipWidth * 1.25),
                      control2: point(length * 0.32, -halfWidth * 0.92))
        path.closeSubpath()
        return path
    }

    private func updateRotationClock(rotating: Bool) {
        let now = Date.timeIntervalSinceReferenceDate
        if rotating {
            if rotationAnchor == nil { rotationAnchor = now }
        } else if let rotationAnchor {
            accumulatedRotationRadians = Self.normalizedRadians(
                accumulatedRotationRadians
                    + max(0, now - rotationAnchor) * Self.radiansPerSecond(for: activeRotationDuration)
            )
            self.rotationAnchor = nil
        }
    }

    private var targetRotationDuration: TimeInterval {
        let resolvedTempo = tempoBPM ?? energyState.estimatedTempoBPM
        guard let resolvedTempo, resolvedTempo.isFinite, resolvedTempo > 0 else {
            return Self.defaultRotationDuration
        }
        let boundedTempo = min(Self.maximumTempoBPM, max(Self.minimumTempoBPM, resolvedTempo))
        return Self.beatsPerRotation * 60 / boundedTempo
    }

    /// Preserve the current angle while switching to the next track's fixed
    /// tempo. Only angular velocity changes; there is no visible phase jump.
    private func updateRotationDuration(_ duration: TimeInterval) {
        let now = Date.timeIntervalSinceReferenceDate
        if let rotationAnchor {
            accumulatedRotationRadians = Self.normalizedRadians(
                accumulatedRotationRadians
                    + max(0, now - rotationAnchor) * Self.radiansPerSecond(for: activeRotationDuration)
            )
            self.rotationAnchor = now
        }
        activeRotationDuration = duration
    }

    private static func radiansPerSecond(for duration: TimeInterval) -> Double {
        .pi * 2 / max(1, duration)
    }

    private static func normalizedRadians(_ radians: Double) -> Double {
        radians.truncatingRemainder(dividingBy: .pi * 2)
    }

    /// The write index points at the next slot to be written, which is also
    /// the oldest logical sample in a full circular buffer. Sampling relative
    /// to that anchor keeps the waveform's time order stable across wraparound.
    private func smoothedSample(
        at segment: Int,
        samples: [Float],
        writeIndex: Int
    ) -> Float {
        guard !samples.isEmpty else { return 0 }
        let position = Double(segment) / Double(Self.unitVectors.count) * Double(samples.count)
        let lowerOffset = Int(position.rounded(.down)) % samples.count
        let upperOffset = (lowerOffset + 1) % samples.count
        let fraction = Float(position - position.rounded(.down))
        let lower = filteredSample(atLogicalOffset: lowerOffset, samples: samples, writeIndex: writeIndex)
        let upper = filteredSample(atLogicalOffset: upperOffset, samples: samples, writeIndex: writeIndex)
        return lower + (upper - lower) * fraction
    }

    private func filteredSample(
        atLogicalOffset center: Int,
        samples: [Float],
        writeIndex: Int
    ) -> Float {
        let count = samples.count
        guard count > 0 else { return 0 }
        let anchor = ((writeIndex % count) + count) % count
        func sample(at logicalOffset: Int) -> Float {
            let normalized = ((logicalOffset % count) + count) % count
            return samples[(anchor + normalized) % count]
        }
        return sample(at: center - 1) * 0.24
            + sample(at: center) * 0.52
            + sample(at: center + 1) * 0.24
    }

    private func lerp(_ from: Float, _ to: Float, _ amount: Double) -> Float {
        from + (to - from) * Float(amount)
    }
}

/// A video-as-avatar treatment: the square video is centered, aspect-filled,
/// and clipped by the same celestial ring as album artwork.
struct VideoMoonPortalView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var size: CGFloat = 260

    var body: some View {
        ZStack {
            VideoExperienceView(
                player: appModel.videoSession.player,
                showsPlaybackControls: false
            )
            .frame(width: size, height: size)
            .clipShape(Circle())

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [theme.primary, theme.metal, theme.secondary, theme.primary],
                        center: .center
                    ),
                    lineWidth: 4
                )
                .frame(width: size, height: size)
                .shadow(color: reduceTransparency ? .clear : theme.primary, radius: 18)
                .allowsHitTesting(false)

            AudioEnergyRing(
                diameter: size,
                energyState: appModel.audioEnergy,
                isActive: appModel.videoSession.isPlaying,
                tempoBPM: appModel.currentTrack?.analysis?.bpm
            )
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomLeading) {
            Button {
                appModel.videoSession.togglePlayback()
            } label: {
                Image(systemName: appModel.videoSession.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 44, height: 44)
                    .background(
                        reduceTransparency ? AnyShapeStyle(theme.surface) : AnyShapeStyle(.ultraThinMaterial),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppLanguage.localized(appModel.videoSession.isPlaying ? "暫停影片" : "播放影片"))
            .padding(10)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                appModel.videoPresentationMode = .separatePlayer
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .frame(width: 44, height: 44)
                    .background(
                        reduceTransparency ? AnyShapeStyle(theme.surface) : AnyShapeStyle(.ultraThinMaterial),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel(AppLanguage.localized("在獨立播放器開啟影片"))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AppLanguage.localized("月環影片播放器"))
    }
}

struct CloudSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.cmvTheme) private var theme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(reduceTransparency ? AnyShapeStyle(theme.surface) : AnyShapeStyle(.ultraThinMaterial))
                    .overlay {
                        if !reduceTransparency {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(theme.surface.opacity(0.16))
                        }
                    }
            }
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(reduceTransparency ? theme.metal : .white.opacity(0.16)))
    }
}

extension View { func cloudSurface() -> some View { modifier(CloudSurfaceModifier()) } }
