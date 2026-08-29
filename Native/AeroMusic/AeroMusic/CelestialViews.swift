import SwiftUI
import SwiftData
import AeroLibrary
import AeroThemes
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct CelestialBackground: View {
    var starCount = 58
    var starSeedOffset = 0

    @Environment(\.aeroTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let shouldAnimate = !reduceMotion && scenePhase == .active
        ZStack {
            Canvas { context, size in
                if reduceTransparency {
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(theme.background))
                } else {
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                        Gradient(colors: [theme.skyZenith, theme.skyMidpoint, theme.skyHorizon]),
                        startPoint: CGPoint(x: size.width * 0.5, y: 0),
                        endPoint: CGPoint(x: size.width * 0.5, y: size.height)))
                    drawAtmosphere(in: &context, size: size)
                }
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
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func drawAtmosphere(in context: inout GraphicsContext, size: CGSize) {
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: max(28, min(size.width, size.height) * 0.07)))
            switch theme.skyStyle {
            case .nebula:
                fillGlow(
                    in: &layer,
                    rect: CGRect(x: -size.width * 0.18, y: size.height * 0.42,
                                 width: size.width * 0.82, height: size.height * 0.45),
                    colors: [theme.atmospherePrimary.opacity(0.42), theme.atmosphereSecondary.opacity(0.16), .clear]
                )
                fillGlow(
                    in: &layer,
                    rect: CGRect(x: size.width * 0.48, y: -size.height * 0.12,
                                 width: size.width * 0.70, height: size.height * 0.36),
                    colors: [theme.atmosphereSecondary.opacity(0.30), .clear]
                )
            case .eclipse:
                let diameter = min(size.width, size.height) * 0.42
                fillGlow(
                    in: &layer,
                    rect: CGRect(x: size.width * 0.68, y: -diameter * 0.22, width: diameter, height: diameter),
                    colors: [theme.atmospherePrimary.opacity(0.34), theme.atmosphereSecondary.opacity(0.10), .clear]
                )
                let moonRect = CGRect(x: size.width * 0.77, y: -diameter * 0.08,
                                      width: diameter * 0.54, height: diameter * 0.54)
                layer.fill(Path(ellipseIn: moonRect), with: .color(theme.skyZenith.opacity(0.92)))
                layer.stroke(Path(ellipseIn: moonRect), with: .color(theme.metal.opacity(0.52)), lineWidth: 2)
            case .aurora:
                for index in 0..<4 {
                    let bandWidth = size.width * (0.13 + CGFloat(index) * 0.025)
                    let rect = CGRect(
                        x: size.width * (0.05 + CGFloat(index) * 0.23),
                        y: -size.height * (0.18 + CGFloat(index % 2) * 0.12),
                        width: bandWidth,
                        height: size.height * 1.22
                    )
                    let color = index.isMultiple(of: 2) ? theme.atmospherePrimary : theme.atmosphereSecondary
                    layer.fill(Path(ellipseIn: rect), with: .linearGradient(
                        Gradient(colors: [.clear, color.opacity(0.25), .clear]),
                        startPoint: CGPoint(x: rect.midX, y: rect.minY),
                        endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                    ))
                }
            case .dawn:
                fillGlow(
                    in: &layer,
                    rect: CGRect(x: -size.width * 0.05, y: size.height * 0.62,
                                 width: size.width * 1.10, height: size.height * 0.58),
                    colors: [theme.atmospherePrimary.opacity(0.50), theme.atmosphereSecondary.opacity(0.18), .clear]
                )
                let sun = min(size.width, size.height) * 0.20
                layer.fill(
                    Path(ellipseIn: CGRect(x: size.width * 0.15, y: size.height * 0.70, width: sun, height: sun)),
                    with: .color(theme.starPrimary.opacity(0.30))
                )
            }
        }
    }

    private func fillGlow(in context: inout GraphicsContext, rect: CGRect, colors: [Color]) {
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: colors),
                center: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: 0,
                endRadius: max(rect.width, rect.height) * 0.5
            )
        )
    }

    private func pseudo(_ seed: Int) -> Double {
        Double((seed &* 1_103_515_245 &+ 12_345) & 0x7fffffff) / Double(0x7fffffff)
    }
}

struct AlbumWorldView: View {
    @Environment(\.aeroTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var size: CGFloat = 260
    var artworkData: Data?
    var albumTitle: String = "專輯"

    var body: some View {
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
            if let artworkData {
                #if os(iOS)
                if let image = UIImage(data: artworkData) {
                    Image(uiImage: image).resizable().scaledToFill().clipShape(Circle()).padding(size * 0.08)
                } else {
                    fallbackArtwork
                }
                #else
                if let image = NSImage(data: artworkData) {
                    Image(nsImage: image).resizable().scaledToFill().clipShape(Circle()).padding(size * 0.08)
                } else {
                    fallbackArtwork
                }
                #endif
            } else {
                fallbackArtwork
            }
            Circle().stroke(AngularGradient(colors: [theme.primary, theme.metal, theme.secondary, theme.primary], center: .center), lineWidth: 3)
                .shadow(color: theme.primary, radius: 18)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(albumTitle)專輯封面")
    }

    private var fallbackArtwork: some View {
        Image(systemName: "moon.stars.fill")
            .font(.system(size: size * 0.25, weight: .thin))
            .foregroundStyle(.white, theme.primary)
    }
}

struct CloudSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.aeroTheme) private var theme

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
