import SwiftUI
import AeroDomain

public enum AeroThemeID: String, CaseIterable, Codable, Sendable, Identifiable {
    case crimsonNebula, titaniumEclipse, emeraldAurora, amberDawn
    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .crimsonNebula: "緋紅星雲"
        case .titaniumEclipse: "鈦銀月蝕"
        case .emeraldAurora: "翠綠極光"
        case .amberDawn: "琥珀晨曦"
        }
    }
}

public enum AeroSkyStyle: Sendable {
    case nebula
    case eclipse
    case aurora
    case dawn
}

public struct AeroTheme: Sendable {
    public let id: AeroThemeID
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
    public let skyStyle: AeroSkyStyle

    public static func palette(_ id: AeroThemeID) -> AeroTheme {
        switch id {
        case .crimsonNebula:
            AeroTheme(
                id: id,
                background: Color(red: 0.055, green: 0.012, blue: 0.10),
                surface: Color(red: 0.25, green: 0.055, blue: 0.19),
                primary: Color(red: 1.0, green: 0.38, blue: 0.54),
                secondary: Color(red: 0.70, green: 0.16, blue: 0.48),
                text: .white,
                mutedText: Color(red: 1.0, green: 0.78, blue: 0.84),
                metal: Color(red: 1.0, green: 0.72, blue: 0.76),
                skyZenith: Color(red: 0.035, green: 0.006, blue: 0.075),
                skyMidpoint: Color(red: 0.20, green: 0.018, blue: 0.14),
                skyHorizon: Color(red: 0.40, green: 0.055, blue: 0.20),
                atmospherePrimary: Color(red: 1.0, green: 0.18, blue: 0.43),
                atmosphereSecondary: Color(red: 0.66, green: 0.16, blue: 0.76),
                starPrimary: Color(red: 1.0, green: 0.86, blue: 0.75),
                starSecondary: Color(red: 1.0, green: 0.48, blue: 0.66),
                skyStyle: .nebula
            )
        case .titaniumEclipse:
            AeroTheme(
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
                skyStyle: .eclipse
            )
        case .emeraldAurora:
            AeroTheme(
                id: id,
                background: Color(red: 0.003, green: 0.045, blue: 0.050),
                surface: Color(red: 0.018, green: 0.20, blue: 0.18),
                primary: Color(red: 0.25, green: 1.0, blue: 0.61),
                secondary: Color(red: 0.08, green: 0.48, blue: 0.49),
                text: .white,
                mutedText: Color(red: 0.72, green: 0.96, blue: 0.88),
                metal: Color(red: 0.68, green: 1.0, blue: 0.91),
                skyZenith: Color(red: 0.002, green: 0.024, blue: 0.035),
                skyMidpoint: Color(red: 0.002, green: 0.13, blue: 0.12),
                skyHorizon: Color(red: 0.016, green: 0.31, blue: 0.24),
                atmospherePrimary: Color(red: 0.20, green: 1.0, blue: 0.58),
                atmosphereSecondary: Color(red: 0.17, green: 0.69, blue: 0.92),
                starPrimary: Color(red: 0.81, green: 1.0, blue: 0.89),
                starSecondary: Color(red: 0.38, green: 1.0, blue: 0.72),
                skyStyle: .aurora
            )
        case .amberDawn:
            AeroTheme(
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
                skyStyle: .dawn
            )
        }
    }
}

private struct AeroThemeKey: EnvironmentKey { static let defaultValue = AeroTheme.palette(.crimsonNebula) }
public extension EnvironmentValues {
    var aeroTheme: AeroTheme { get { self[AeroThemeKey.self] } set { self[AeroThemeKey.self] = newValue } }
}
