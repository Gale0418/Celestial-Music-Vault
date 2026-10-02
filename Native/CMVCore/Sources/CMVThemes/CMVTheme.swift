import SwiftUI
import CMVDomain

public enum CMVThemeID: String, CaseIterable, Codable, Sendable, Identifiable {
    case crimsonNebula, titaniumEclipse, emeraldAurora, amberDawn
    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .crimsonNebula: "銀河月夜"
        case .titaniumEclipse: "土星環軌站"
        case .emeraldAurora: "綿羊幻想鄉"
        case .amberDawn: "星海晨光"
        }
    }
}

public enum CMVSkyStyle: Sendable, Equatable {
    case milkyWayNight
    case saturnRingStation
    case sheepDreamland
    case celestialDawn
}

public struct CMVTheme: Sendable {
    public let id: CMVThemeID
    public let background: Color
    public let surface: Color
    public let primary: Color
    public let secondary: Color
    public let text: Color
    public let mutedText: Color
    public let metal: Color
    public let skyZenith: Color
    public let skyMidpoint: Color
    public let skyHorizon: Color
    public let atmospherePrimary: Color
    public let atmosphereSecondary: Color
    public let starPrimary: Color
    public let starSecondary: Color
    public let skyStyle: CMVSkyStyle

    public var isStorybook: Bool { id == .emeraldAurora }

    /// Decorative pigments only; controls and status keep semantic ink colors.
    public static let storybookRainbow: [Color] = [
        Color(red: 0.88, green: 0.48, blue: 0.49),
        Color(red: 0.93, green: 0.64, blue: 0.39),
        Color(red: 0.92, green: 0.78, blue: 0.37),
        Color(red: 0.49, green: 0.68, blue: 0.49),
        Color(red: 0.42, green: 0.65, blue: 0.75),
        Color(red: 0.62, green: 0.49, blue: 0.74)
    ]

    public static func palette(_ id: CMVThemeID) -> CMVTheme {
        switch id {
        case .crimsonNebula:
            CMVTheme(
                id: id,
                background: Color(red: 0.018, green: 0.040, blue: 0.10),
                surface: Color(red: 0.055, green: 0.10, blue: 0.20),
                primary: Color(red: 0.62, green: 0.82, blue: 1.0),
                secondary: Color(red: 0.31, green: 0.42, blue: 0.72),
                text: .white,
                mutedText: Color(red: 0.78, green: 0.86, blue: 0.97),
                metal: Color(red: 0.90, green: 0.95, blue: 1.0),
                skyZenith: Color(red: 0.008, green: 0.018, blue: 0.060),
                skyMidpoint: Color(red: 0.035, green: 0.090, blue: 0.20),
                skyHorizon: Color(red: 0.13, green: 0.18, blue: 0.34),
                atmospherePrimary: Color(red: 0.64, green: 0.77, blue: 1.0),
                atmosphereSecondary: Color(red: 0.42, green: 0.48, blue: 0.82),
                starPrimary: Color(red: 0.96, green: 0.98, blue: 1.0),
                starSecondary: Color(red: 0.70, green: 0.84, blue: 1.0),
                skyStyle: .milkyWayNight
            )
        case .titaniumEclipse:
            CMVTheme(
                id: id,
                background: Color(red: 0.008, green: 0.018, blue: 0.050),
                surface: Color(red: 0.045, green: 0.090, blue: 0.17),
                primary: Color(red: 0.49, green: 0.88, blue: 1.0),
                secondary: Color(red: 0.20, green: 0.31, blue: 0.52),
                text: .white,
                mutedText: Color(red: 0.76, green: 0.84, blue: 0.94),
                metal: Color(red: 0.88, green: 0.94, blue: 1.0),
                skyZenith: Color(red: 0.003, green: 0.008, blue: 0.025),
                skyMidpoint: Color(red: 0.018, green: 0.055, blue: 0.13),
                skyHorizon: Color(red: 0.095, green: 0.15, blue: 0.27),
                atmospherePrimary: Color(red: 0.72, green: 0.90, blue: 1.0),
                atmosphereSecondary: Color(red: 0.22, green: 0.50, blue: 0.78),
                starPrimary: Color(red: 0.92, green: 0.97, blue: 1.0),
                starSecondary: Color(red: 0.46, green: 0.84, blue: 1.0),
                skyStyle: .saturnRingStation
            )
        case .emeraldAurora:
            CMVTheme(
                id: id,
                background: Color(red: 0.98, green: 0.95, blue: 0.88),
                surface: Color(red: 1.0, green: 0.98, blue: 0.93),
                primary: Color(red: 0.43, green: 0.25, blue: 0.40),
                secondary: Color(red: 0.80, green: 0.73, blue: 0.85),
                text: Color(red: 0.24, green: 0.19, blue: 0.17),
                mutedText: Color(red: 0.40, green: 0.33, blue: 0.30),
                metal: Color(red: 0.49, green: 0.38, blue: 0.32),
                skyZenith: Color(red: 0.68, green: 0.86, blue: 0.90),
                skyMidpoint: Color(red: 0.83, green: 0.93, blue: 0.91),
                skyHorizon: Color(red: 0.98, green: 0.91, blue: 0.74),
                atmospherePrimary: Color(red: 0.93, green: 0.66, blue: 0.69),
                atmosphereSecondary: Color(red: 0.57, green: 0.72, blue: 0.55),
                starPrimary: Color(red: 0.76, green: 0.51, blue: 0.20),
                starSecondary: Color(red: 0.63, green: 0.49, blue: 0.69),
                skyStyle: .sheepDreamland
            )
        case .amberDawn:
            CMVTheme(
                id: id,
                background: Color(red: 0.12, green: 0.050, blue: 0.20),
                surface: Color(red: 0.38, green: 0.16, blue: 0.31),
                primary: Color(red: 1.0, green: 0.74, blue: 0.25),
                secondary: Color(red: 0.96, green: 0.39, blue: 0.42),
                text: .white,
                mutedText: Color(red: 1.0, green: 0.86, blue: 0.72),
                metal: Color(red: 1.0, green: 0.92, blue: 0.69),
                skyZenith: Color(red: 0.075, green: 0.030, blue: 0.16),
                skyMidpoint: Color(red: 0.30, green: 0.11, blue: 0.28),
                skyHorizon: Color(red: 0.62, green: 0.25, blue: 0.22),
                atmospherePrimary: Color(red: 1.0, green: 0.64, blue: 0.22),
                atmosphereSecondary: Color(red: 1.0, green: 0.38, blue: 0.48),
                starPrimary: Color(red: 1.0, green: 0.94, blue: 0.72),
                starSecondary: Color(red: 1.0, green: 0.68, blue: 0.45),
                skyStyle: .celestialDawn
            )
        }
    }
}

private struct CMVThemeKey: EnvironmentKey { static let defaultValue = CMVTheme.palette(.crimsonNebula) }
public extension EnvironmentValues {
    var cmvTheme: CMVTheme { get { self[CMVThemeKey.self] } set { self[CMVThemeKey.self] = newValue } }
}
