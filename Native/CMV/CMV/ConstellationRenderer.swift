import SwiftUI
import CMVThemes

/// Static, decorative constellation line art for the background Canvas.
///
/// This intentionally draws two separate compositions rather than attempting
/// to reproduce the whole sky or the current observing time.  The normalized
/// points below were projected once from SIMBAD ICRS(J2000) positions using a
/// local tangent approximation (`x = ΔRA × cos(mean Dec)`, `y = ΔDec`) and are
/// fitted into each target rectangle with one uniform scale factor.  Thus the
/// recognizable relative shapes are retained without independently stretching
/// x and y.
enum ConstellationRenderer {
    private struct Constellation: Sendable {
        let points: [CGPoint]
        let edges: [(Int, Int)]
        let sparkleIndices: Set<Int>
    }

    private static let unitDot = Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2))
    private static let unitSparkle = makeSparklePath()

    // Summer Triangle: Vega, Deneb, Altair.  Values are centered and share a
    // single physical normalization denominator (not an x/y independent fit).
    private static let summerTriangle = Constellation(
        points: [
            CGPoint(x: -0.36642, y:  0.32158), // Vega   18 36 56.33635 +38 47 01.2802
            CGPoint(x:  0.36642, y:  0.50000), // Deneb  20 41 25.91514 +45 16 49.2197
            CGPoint(x:  0.06827, y: -0.50000)  // Altair 19 50 46.99855 +08 52 05.9563
        ],
        edges: [(0, 1), (1, 2), (2, 0)],
        sparkleIndices: [0]
    )

    // Big Dipper: Dubhe, Merak, Phecda, Megrez (bowl), then Alioth, Mizar,
    // Alkaid (handle).  Same local equal-scale projection as above.
    private static let bigDipper = Constellation(
        points: [
            CGPoint(x: -0.48861, y:  0.26559), // Dubhe  11 03 43.67152 +61 45 03.7249
            CGPoint(x: -0.50000, y:  0.03631), // Merak  11 01 50.47975 +56 22 56.7611
            CGPoint(x: -0.18624, y: -0.07847), // Phecda 11 53 49.84732 +53 41 41.1350
            CGPoint(x: -0.05591, y:  0.06408), // Megrez 12 15 25.55985 +57 01 57.4211
            CGPoint(x:  0.17706, y:  0.01826), // Alioth 12 54 01.74959 +55 57 35.3626
            CGPoint(x:  0.35748, y: -0.02591), // Mizar  13 23 55.54048 +54 55 31.2671
            CGPoint(x:  0.50000, y: -0.26559)  // Alkaid 13 47 32.43776 +49 18 47.7602
        ],
        edges: [
            (0, 1), (1, 2), (2, 3), (3, 0), // bowl
            (3, 4), (4, 5), (5, 6)          // handle
        ],
        sparkleIndices: [0, 4]
    )

    /// Draws both constellations as quiet, non-interactive background detail.
    static func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        theme: CMVTheme
    ) {
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return }

        // The listening stage owns this layer, not the full app window.
        // Its top breathing room keeps the patterns out of opaque queue/cards.
        let height = min(58.0, size.height * 0.10)
        let triangleRect = CGRect(x: size.width * 0.17, y: 7,
                                  width: size.width * 0.22, height: height)
        let dipperRect = CGRect(x: size.width * 0.59, y: 7,
                                width: size.width * 0.25, height: height)

        drawConstellation(in: &context, constellation: summerTriangle,
                          in: triangleRect, theme: theme)
        drawConstellation(in: &context, constellation: bigDipper,
                          in: dipperRect, theme: theme)
    }

    private static func drawConstellation(
        in context: inout GraphicsContext,
        constellation: Constellation,
        in rect: CGRect,
        theme: CMVTheme
    ) {
        let placedPoints = fit(constellation.points, in: rect)
        let lineWidth = max(0.55, min(1.0, min(rect.width, rect.height) * 0.018))
        var linePath = Path()
        for (startIndex, endIndex) in constellation.edges {
            guard constellation.points.indices.contains(startIndex),
                  constellation.points.indices.contains(endIndex) else { continue }
            linePath.move(to: placedPoints[startIndex])
            linePath.addLine(to: placedPoints[endIndex])
        }
        context.stroke(
            linePath,
            with: .color(theme.starSecondary.opacity(0.25)),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )

        let radius = max(1.1, min(1.7, min(rect.width, rect.height) * 0.026))
        for (index, point) in placedPoints.enumerated() {
            drawStar(in: &context, center: point, radius: radius,
                     theme: theme, opacity: 0.90)
            if constellation.sparkleIndices.contains(index) {
                drawSparkle(in: &context, center: point, radius: radius * 2.5,
                            theme: theme)
            }
        }
    }

    /// Uniformly fits already-projected points into a rectangle, preserving
    /// their aspect ratio and centering any unused space.
    private static func fit(_ points: [CGPoint], in rect: CGRect) -> [CGPoint] {
        guard let first = points.first else { return [] }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        let spanX = max(0.0001, maxX - minX)
        let spanY = max(0.0001, maxY - minY)
        let scale = min(rect.width / spanX, rect.height / spanY)
        let sourceCenter = CGPoint(x: (minX + maxX) * 0.5, y: (minY + maxY) * 0.5)
        let targetCenter = CGPoint(x: rect.midX, y: rect.midY)
        return points.map { point in
            CGPoint(
                // North up, east (increasing right ascension) to the left:
                // looking outward at the sky rather than at a celestial globe.
                x: targetCenter.x - (point.x - sourceCenter.x) * scale,
                y: targetCenter.y - (point.y - sourceCenter.y) * scale
            )
        }
    }

    private static func drawStar(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        theme: CMVTheme,
        opacity: Double
    ) {
        var starContext = context
        starContext.translateBy(x: center.x, y: center.y)
        starContext.scaleBy(x: radius, y: radius)
        starContext.fill(unitDot, with: .color(theme.starPrimary.opacity(opacity)))
        starContext.scaleBy(x: 0.42, y: 0.42)
        starContext.fill(unitDot, with: .color(Color.white.opacity(0.92)))
    }

    private static func drawSparkle(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        theme: CMVTheme
    ) {
        var sparkleContext = context
        sparkleContext.translateBy(x: center.x, y: center.y)
        sparkleContext.scaleBy(x: radius, y: radius)
        sparkleContext.stroke(
            unitSparkle,
            with: .color(theme.metal.opacity(0.34)),
            style: StrokeStyle(lineWidth: 0.24, lineCap: .round)
        )
    }

    private static func makeSparklePath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: -1)); path.addLine(to: CGPoint(x: 0, y: 1))
        path.move(to: CGPoint(x: -1, y: 0)); path.addLine(to: CGPoint(x: 1, y: 0))
        return path
    }
}

// MARK: - Public source notes
//
// SIMBAD Basic Query pages (ICRS coord., ep=J2000; rounded values embedded
// above):
// Vega   https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Vega
// Deneb  https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Deneb
// Altair https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Altair
// Dubhe  https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Dubhe
// Merak  https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Merak
// Phecda https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Phecda
// Megrez https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Megrez
// Alioth https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Alioth
// Mizar  https://simbad.u-strasbg.fr/simbad/sim-basic?Ident=zet+uma
// Alkaid https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Alkaid
// NASA Summer Triangle confirmation:
// https://science.nasa.gov/solar-system/skywatching/night-sky-network/summer-triangle-corner-altair/
