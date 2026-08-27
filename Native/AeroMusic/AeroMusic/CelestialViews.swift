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
    @Environment(\.aeroTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 60 : 1 / 20)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 20) / 20
            Canvas { context, size in
                if reduceTransparency {
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(theme.background))
                } else {
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                        Gradient(colors: [theme.background, theme.secondary.opacity(0.75), theme.background]),
                        startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
                }
                for index in 0..<70 {
                    let x = pseudo(index * 17) * size.width
                    let y = pseudo(index * 43) * size.height
                    let pulse = 0.35 + 0.55 * abs(sin(Double(index) + phase * .pi * 2))
                    let radius = 0.7 + pseudo(index * 29) * 1.8
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                                 with: .color(.white.opacity(pulse)))
                }
            }
            .overlay(alignment: .bottomLeading) {
                if !reduceTransparency {
                    Ellipse().fill(theme.primary.opacity(0.22)).frame(width: 700, height: 260).blur(radius: 80).offset(x: -120, y: 100)
                }
            }
            .overlay(alignment: .topTrailing) {
                if !reduceTransparency {
                    Ellipse().fill(theme.metal.opacity(0.20)).frame(width: 560, height: 240).blur(radius: 90).offset(x: 100, y: -70)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
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
            .background(reduceTransparency ? AnyShapeStyle(theme.background.opacity(0.98)) : AnyShapeStyle(.ultraThinMaterial),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.16)))
    }
}

extension View { func cloudSurface() -> some View { modifier(CloudSurfaceModifier()) } }
