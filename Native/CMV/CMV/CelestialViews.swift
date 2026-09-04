import SwiftUI
import SwiftData
import ImageIO
import CMVLibrary
import CMVThemes
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct CelestialBackground: View {
    var starCount = 58
    var starSeedOffset = 0

    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let shouldAnimate = !reduceMotion && scenePhase == .active
        ZStack {
            if reduceTransparency {
                theme.background
            } else {
                Image(backgroundAssetName)
                    .resizable()
                    .scaledToFill()
                    .saturation(1.05)
                    .overlay(theme.background.opacity(0.12))
            }
            TimelineView(.animation(minimumInterval: 1 / 12, paused: !shouldAnimate)) { timeline in
                let time = shouldAnimate ? timeline.date.timeIntervalSinceReferenceDate : 0
                Canvas { context, size in
                    for localIndex in 0..<starCount {
                        let index = localIndex + starSeedOffset
                        let x = pseudo(index * 17) * size.width
                        let y = pseudo(index * 43) * size.height
                        let baseOpacity = 0.20 + pseudo(index * 71) * 0.24
                        let amplitude = 0.10 + pseudo(index * 31) * 0.22
                        let speed = 0.30 + pseudo(index * 47) * 0.55
                        let offset = pseudo(index * 97) * .pi * 2
                        let pulse = baseOpacity + amplitude * (0.5 + 0.5 * sin(time * speed + offset))
                        let radius = 0.55 + pseudo(index * 29) * 1.45
                        let starColor = index.isMultiple(of: 5) ? theme.starSecondary : theme.starPrimary
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                            with: .color(starColor.opacity(pulse))
                        )
                    }
                    if shouldAnimate { drawMeteorShower(in: &context, size: size, time: time) }
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var backgroundAssetName: String {
        switch theme.id {
        case .crimsonNebula: "SkyCrimsonNebula"
        case .titaniumEclipse: "SkyTitaniumEclipse"
        case .emeraldAurora: "SkyEmeraldAurora"
        case .amberDawn: "SkyAmberDawn"
        }
    }

    private func pseudo(_ seed: Int) -> Double {
        Double((seed &* 1_103_515_245 &+ 12_345) & 0x7fffffff) / Double(0x7fffffff)
    }

    private func drawMeteorShower(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let cycle = 22.0
        for index in 0..<5 {
            let localTime = (time + cycle - Double(index) * 0.19)
                .truncatingRemainder(dividingBy: cycle)
            guard localTime >= 0, localTime < 1.35 else { continue }
            let progress = localTime / 1.35
            let startX = size.width * (0.52 + pseudo(700 + index * 41) * 0.42)
            let startY = size.height * (0.04 + pseudo(900 + index * 37) * 0.22)
            let head = CGPoint(
                x: startX - size.width * 0.20 * progress,
                y: startY + size.height * 0.15 * progress
            )
            let tail = CGPoint(x: head.x + 105, y: head.y - 64)
            var path = Path()
            path.move(to: tail)
            path.addLine(to: head)
            let opacity = sin(.pi * progress) * (0.45 + pseudo(1_100 + index * 23) * 0.45)
            context.stroke(path, with: .color(theme.starSecondary.opacity(opacity * 0.28)),
                           style: StrokeStyle(lineWidth: 5, lineCap: .round))
            context.stroke(path, with: .color(Color.white.opacity(opacity)),
                           style: StrokeStyle(lineWidth: 1.25, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: head.x - 2, y: head.y - 2, width: 4, height: 4)),
                         with: .color(theme.metal.opacity(opacity)))
        }
    }
}

struct AlbumWorldView: View {
    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var decodedArtwork: CGImage?
    var size: CGFloat = 260
    var artworkID: UUID?
    var artworkData: Data?
    var albumTitle: String = "專輯"
    let energyState: AudioEnergyState
    var isPlaying = false

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
                isActive: isPlaying
            )
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(albumTitle)專輯封面")
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

/// A mirrored linear equalizer bent around the moon. Bars grow inward and
/// outward from one circular baseline while the complete waveform rotates.
private struct AudioEnergyRing: View {
    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var accumulatedRotationTime: TimeInterval = 0
    @State private var rotationAnchor: TimeInterval?
    let diameter: CGFloat
    let energyState: AudioEnergyState
    let isActive: Bool

    // The old 120-segment/4-second pair advanced exactly one 3-degree segment
    // per nominal 30 fps frame, aliasing continuous motion into slot-by-slot swaps.
    private static let scanDuration: TimeInterval = 6
    private static let segmentCount = 80
    private static let unitVectors: [CGVector] = (0..<segmentCount).map { index in
        let angle = Double(index) / Double(segmentCount) * .pi * 2 - .pi / 2
        return CGVector(dx: cos(angle), dy: sin(angle))
    }

    private var shouldRotate: Bool {
        !reduceMotion && isActive && scenePhase == .active
    }

    var body: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 30.0,
            paused: !shouldRotate
        )) { timeline in
            let snapshot = energyState.snapshot
            let timelineTime = timeline.date.timeIntervalSinceReferenceDate
            let activeRotationTime = accumulatedRotationTime
                + (rotationAnchor.map { max(0, timelineTime - $0) } ?? 0)
            let rotationRadians = reduceMotion
                ? 0
                : activeRotationTime
                    .truncatingRemainder(dividingBy: Self.scanDuration)
                    / Self.scanDuration * .pi * 2
            let elapsed = timelineTime - snapshot.publishedAt
            let rawBlend = min(1, max(0, elapsed / (1.0 / 30.0)))
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

                var outerBars = Path()
                var innerBars = Path()

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
                    let mirroredLength = min(40, 4 + pulse * 0.65 + energy * 32)
                    outerBars.move(to: baseline)
                    outerBars.addLine(to: CGPoint(
                        x: center.x + direction.dx * (baseRadius + mirroredLength),
                        y: center.y + direction.dy * (baseRadius + mirroredLength)
                    ))
                    innerBars.move(to: baseline)
                    innerBars.addLine(to: CGPoint(
                        x: center.x + direction.dx * (baseRadius - mirroredLength),
                        y: center.y + direction.dy * (baseRadius - mirroredLength)
                    ))
                }

                context.stroke(
                    outerBars,
                    with: .linearGradient(
                        Gradient(colors: [
                            theme.primary.opacity(isActive ? 0.94 : 0.40),
                            theme.starPrimary.opacity(isActive ? 0.98 : 0.42),
                            theme.starSecondary.opacity(isActive ? 0.92 : 0.36),
                            theme.primary.opacity(isActive ? 0.94 : 0.40)
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
                    ),
                    style: StrokeStyle(lineWidth: 1.75, lineCap: .round)
                )
                context.stroke(
                    innerBars,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.34, green: 0.48, blue: 1.0)
                                .opacity(isActive ? 0.92 : 0.34),
                            theme.atmosphereSecondary.opacity(isActive ? 0.88 : 0.32),
                            Color(red: 0.55, green: 0.72, blue: 1.0)
                                .opacity(isActive ? 0.96 : 0.36)
                        ]),
                        startPoint: CGPoint(x: canvasSize.width, y: 0),
                        endPoint: CGPoint(x: 0, y: canvasSize.height)
                    ),
                    style: StrokeStyle(lineWidth: 1.45, lineCap: .round)
                )
            }
        }
        .frame(width: diameter + 88, height: diameter + 88)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { updateRotationClock(rotating: shouldRotate) }
        .onChange(of: shouldRotate) { _, rotating in
            updateRotationClock(rotating: rotating)
        }
    }

    private func updateRotationClock(rotating: Bool) {
        let now = Date.timeIntervalSinceReferenceDate
        if rotating {
            if rotationAnchor == nil { rotationAnchor = now }
        } else if let rotationAnchor {
            accumulatedRotationTime += max(0, now - rotationAnchor)
            self.rotationAnchor = nil
        }
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
                isActive: appModel.videoSession.isPlaying
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
            .accessibilityLabel(appModel.videoSession.isPlaying ? "暫停影片" : "播放影片")
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
