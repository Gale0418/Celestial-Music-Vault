import SwiftUI
import CMVThemes

/// A small, deterministic Canvas renderer for the moving stars in the sky.
///
/// The renderer intentionally owns no state: `time` is supplied by the caller,
/// while particle placement is derived from a stable hash.  This keeps redraws
/// cheap and prevents a new random layout from being created on every frame.
enum StarfallRenderer {
    private static let particleCount = 36
    private static let meteorStartIndex = 32
    private static let twoPi = Double.pi * 2

    // Unit geometry is transformed by a local GraphicsContext per star.  No
    // SF Symbol lookup or per-particle SwiftUI View is needed on the hot path.
    private static let unitPentagram = makePentagramPath()
    private static let unitDot = Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2))

    /// Draws the complete fixed-size starfall pool for one Canvas frame.
    ///
    /// Every particle has a 12...26 second deterministic life cycle.  A cycle
    /// gets a fresh (but repeatable) start point, slope, and travel distance;
    /// all movement is linear, with meteor tail dots sampled on that same line.
    static func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        theme: CMVTheme,
        seedOffset: Int
    ) {
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0,
              time.isFinite else { return }

        let seed = UInt64(bitPattern: Int64(seedOffset))

        for index in 0..<particleCount {
            let particleSeed = hash(seed &+ UInt64(index) &* 0xD1B5_4A32_D192_ED03)
            let isMeteor = index >= meteorStartIndex
            let lifetime = isMeteor
                ? 12.0 + random(particleSeed, salt: 1) * 7.0
                : 17.0 + random(particleSeed, salt: 1) * 9.0
            let phase = random(particleSeed, salt: 2) * lifetime
            let cycleDouble = floor((time + phase) / lifetime)
            // TimeInterval values encountered in a display clock are modest,
            // but clamping keeps conversion safe for arbitrary test inputs.
            let boundedCycle = min(max(cycleDouble, -9_000_000_000_000.0), 9_000_000_000_000.0)
            let cycle = Int64(boundedCycle)
            let cycleSeed = hash(particleSeed &+ UInt64(bitPattern: cycle) &* 0x9E37_79B9_7F4A_7C15)
            let progress = positiveRemainder(time + phase, lifetime) / lifetime

            let start = CGPoint(
                x: size.width * (-0.18 + CGFloat(random(cycleSeed, salt: 3)) * 1.36),
                y: size.height * (-0.20 + CGFloat(random(cycleSeed, salt: 4)) * 0.24)
            )
            let horizontalTravel = size.width * CGFloat(
                -0.46 + random(cycleSeed, salt: 5) * 0.92
            )
            let verticalTravel = size.height * CGFloat(
                isMeteor
                    ? 1.58 + random(cycleSeed, salt: 6) * 0.62
                    : 1.30 + random(cycleSeed, salt: 6) * 0.56
            )
            let end = CGPoint(x: start.x + horizontalTravel, y: start.y + verticalTravel)
            let head = sampleLinearPoint(start: start, end: end, progress: progress)

            // Fade only at the cycle boundaries.  The base luminance remains
            // readable without overwhelming foreground controls.
            let fadeIn = min(1.0, progress / 0.12)
            let fadeOut = min(1.0, (1.0 - progress) / 0.14)
            let edgeFade = max(0.0, min(fadeIn, fadeOut))
            let opacity = (0.32 + random(cycleSeed, salt: 7) * 0.36) * edgeFade
            guard opacity > 0.001 else { continue }

            let color = particleColor(random(cycleSeed, salt: 8), theme: theme)
            let direction = normalizedVector(from: start, to: end)

            if isMeteor {
                drawMeteor(
                    in: &context,
                    head: head,
                    direction: direction,
                    size: size,
                    opacity: opacity,
                    color: color,
                    seed: cycleSeed,
                    theme: theme
                )
            } else if index.isMultiple(of: 3) {
                // A handful of readable star silhouettes among the fine
                // dust, with short straight trails rather than large halos.
                for tailIndex in 1...4 {
                    let distance = CGFloat(tailIndex) * 7
                    drawDot(in: &context,
                            center: CGPoint(x: head.x - direction.dx * distance,
                                            y: head.y - direction.dy * distance),
                            radius: 0.75,
                            color: color,
                            opacity: opacity * (0.26 - Double(tailIndex) * 0.045))
                }
                let radius = CGFloat(5.0 + random(cycleSeed, salt: 9) * 5.0)
                drawPentagram(
                    in: &context,
                    center: head,
                    radius: radius,
                    rotation: (random(cycleSeed, salt: 10) - 0.5) * 0.45 + progress * 0.8,
                    tumbleScale: signedTumbleScale(
                        angle: progress * twoPi * (2.2 + random(cycleSeed, salt: 14) * 2.4)
                            + random(cycleSeed, salt: 15) * twoPi
                    ),
                    color: color,
                    opacity: opacity
                )
            } else {
                let radius = CGFloat(0.65 + random(cycleSeed, salt: 9) * 1.35)
                drawDot(
                    in: &context,
                    center: head,
                    radius: radius,
                    color: color,
                    opacity: opacity
                )
            }
        }
    }

    /// Samples a point on a straight particle trajectory.
    /// Clamping makes this helper safe to use from geometry tests as well as
    /// from the renderer's normalized 0...1 progress value.
    static func sampleLinearPoint(start: CGPoint, end: CGPoint, progress: Double) -> CGPoint {
        let t = CGFloat(min(1.0, max(0.0, progress.isFinite ? progress : 0)))
        return CGPoint(
            x: start.x + (end.x - start.x) * t,
            y: start.y + (end.y - start.y) * t
        )
    }

    private static func drawMeteor(
        in context: inout GraphicsContext,
        head: CGPoint,
        direction: CGVector,
        size: CGSize,
        opacity: Double,
        color: Color,
        seed: UInt64,
        theme: CMVTheme
    ) {
        let tailCount = 5 + Int(random(seed, salt: 11) * 4.0) // 5...8 dots
        let spacing = max(4.0, min(size.width, size.height) * (0.012 + random(seed, salt: 12) * 0.012))

        for tailIndex in stride(from: tailCount, through: 1, by: -1) {
            let distance = CGFloat(tailIndex) * spacing
            let point = CGPoint(
                x: head.x - direction.dx * distance,
                y: head.y - direction.dy * distance
            )
            let tailProgress = 1.0 - Double(tailIndex) / Double(tailCount + 1)
            let tailRadius = CGFloat(0.55 + tailProgress * 1.15)
            let tailOpacity = opacity * (0.10 + tailProgress * 0.42)
            drawDot(
                in: &context,
                center: point,
                radius: tailRadius,
                color: color,
                opacity: tailOpacity
            )
        }

        let headRadius = CGFloat(1.35 + random(seed, salt: 13) * 1.55)
        drawDot(
            in: &context,
            center: head,
            radius: headRadius,
            color: color,
            opacity: opacity
        )
        // A small white core gives meteors a crisp centre without blur or a
        // separate bitmap asset.
        drawDot(
            in: &context,
            center: head,
            radius: headRadius * 0.34,
            color: theme.metal,
            opacity: min(0.55, opacity * 0.92)
        )
    }

    private static func drawPentagram(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        rotation: Double,
        tumbleScale: CGFloat,
        color: Color,
        opacity: Double
    ) {
        var transformed = context
        transformed.translateBy(x: center.x, y: center.y)
        transformed.rotate(by: .radians(rotation))
        // The signed x scale creates a cheap 3D-like tumble: a full star
        // narrows to a bright edge, mirrors, then opens again.  Keeping a
        // small minimum width prevents a one-frame disappearance.
        transformed.scaleBy(x: radius * tumbleScale, y: radius)
        transformed.fill(unitPentagram, with: .color(color.opacity(opacity)))

        // Keep the centre bright but quiet enough that text remains readable.
        transformed.scaleBy(x: 0.35, y: 0.35)
        transformed.fill(unitPentagram, with: .color(Color.white.opacity(opacity * 0.82)))
    }

    private static func drawDot(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color,
        opacity: Double
    ) {
        guard radius > 0, opacity > 0 else { return }
        var transformed = context
        transformed.translateBy(x: center.x, y: center.y)
        transformed.scaleBy(x: radius, y: radius)
        transformed.fill(unitDot, with: .color(color.opacity(opacity)))
    }

    private static func makePentagramPath() -> Path {
        var path = Path()
        for index in 0..<10 {
            // Start at the top, then alternate outer and inner vertices.
            let angle = -Double.pi / 2 + Double(index) * Double.pi / 5
            let radius = index.isMultiple(of: 2) ? 1.0 : 0.42
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private static func particleColor(_ value: Double, theme: CMVTheme) -> Color {
        switch value {
        case ..<0.52: theme.starPrimary
        case ..<0.82: theme.starSecondary
        default: theme.metal
        }
    }

    private static func signedTumbleScale(angle: Double) -> CGFloat {
        let raw = cos(angle)
        let sign: CGFloat = raw < 0 ? -1 : 1
        return sign * CGFloat(max(0.12, abs(raw)))
    }

    private static func normalizedVector(from start: CGPoint, to end: CGPoint) -> CGVector {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(0.0001, sqrt(dx * dx + dy * dy))
        return CGVector(dx: dx / length, dy: dy / length)
    }

    private static func positiveRemainder(_ value: Double, _ modulus: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: modulus)
        return remainder >= 0 ? remainder : remainder + modulus
    }

    private static func random(_ seed: UInt64, salt: UInt64) -> Double {
        // 53 high bits are exactly representable as a Double in [0, 1).
        Double(hash(seed &+ salt &* 0xA24B_AED4_963E_E407) >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    private static func hash(_ value: UInt64) -> UInt64 {
        var x = value &+ 0x9E37_79B9_7F4A_7C15
        x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
        x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
        return x ^ (x >> 31)
    }
}
