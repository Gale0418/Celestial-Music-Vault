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
        ZStack {
            if reduceTransparency {
                theme.background
            } else {
                Image(backgroundAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .saturation(1.05)
                    .overlay(theme.background.opacity(backgroundOverlayOpacity))
            }
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !shouldAnimate)) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let time = reduceMotion ? 0 : skyElapsed + (skyAnchor.map { max(0, now - $0) } ?? 0)
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
            .isolatedAnimationSurface()
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
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
        case .titaniumEclipse: "SkyTitaniumEclipse"
        case .emeraldAurora: "SkyEmeraldAurora"
        case .amberDawn: "SkyAmberDawn"
        }
    }

    private var backgroundOverlayOpacity: Double {
        switch theme.id {
        case .amberDawn: 0.32
        case .emeraldAurora: 0.24
        case .crimsonNebula, .titaniumEclipse: 0.10
        }
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
                Circle().fill(reduceTransparency ? AnyShapeStyle(theme.background.opacity(0.98)) : AnyShapeStyle(.ultraThinMaterial))
                Circle().fill(RadialGradient(colors: [theme.primary.opacity(0.92), theme.secondary.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: size / 2))
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.13 + Double(index % 3) * 0.07))
                        .frame(width: size * (0.26 + CGFloat(index % 3) * 0.08))
                        .blur(radius: 10)
                        .offset(x: CGFloat(index % 4 - 2) * size * 0.11, y: CGFloat(index / 3 - 1) * size * 0.14)
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
                Circle().stroke(AngularGradient(colors: [theme.primary, theme.metal, theme.secondary, theme.primary], center: .center), lineWidth: 3)
                    .shadow(color: theme.primary, radius: 18)
            }
            .frame(width: size, height: size)
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
        !reduceMotion && isActive && scenePhase == .active
    }

    var body: some View {
        TimelineView(.animation(
            minimumInterval: reduceMotion ? 1.0 / 15.0 : nil,
            paused: !isActive || scenePhase != .active
        )) { timeline in
            let snapshot = energyState.snapshot
            let timelineTime = timeline.date.timeIntervalSinceReferenceDate
            let elapsedRotationTime = rotationAnchor.map { max(0, timelineTime - $0) } ?? 0
            let activeRotationRadians = accumulatedRotationRadians
                + elapsedRotationTime * Self.radiansPerSecond(for: activeRotationDuration)
            let rotationRadians = reduceMotion
                ? 0
                : Self.normalizedRadians(activeRotationRadians)
            let elapsed = timelineTime - snapshot.publishedAt
            let rawBlend = min(1, max(0, elapsed / snapshot.interpolationDuration))
            let blend = rawBlend * rawBlend * (3 - 2 * rawBlend)

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
                    with: .color(theme.secondary.opacity(isActive ? 0.46 : 0.30)),
                    style: StrokeStyle(lineWidth: 1.6)
                )

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
                .shadow(color: theme.primary, radius: 18)
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
                        reduceTransparency ? AnyShapeStyle(theme.surface.opacity(0.98)) : AnyShapeStyle(.ultraThinMaterial),
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
                        reduceTransparency ? AnyShapeStyle(theme.surface.opacity(0.98)) : AnyShapeStyle(.ultraThinMaterial),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel("在獨立播放器開啟影片")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("月環影片播放器")
    }
}

struct CloudSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.cmvTheme) private var theme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(reduceTransparency ? AnyShapeStyle(theme.surface.opacity(0.98)) : AnyShapeStyle(.ultraThinMaterial))
                    .overlay {
                        if !reduceTransparency {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(theme.surface.opacity(0.16))
                        }
                    }
            }
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.16)))
    }
}

extension View { func cloudSurface() -> some View { modifier(CloudSurfaceModifier()) } }
