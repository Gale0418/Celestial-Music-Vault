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

public struct AeroTheme: Sendable {
    public let id: AeroThemeID
    public let background: Color
    public let surface: Color
    public let primary: Color
    public let secondary: Color
    public let text: Color
    public let mutedText: Color
    public let metal: Color

    public static func palette(_ id: AeroThemeID) -> AeroTheme {
        switch id {
        case .crimsonNebula:
            AeroTheme(id: id, background: Color(red: 0.025, green: 0.06, blue: 0.22),
                      surface: Color(red: 0.18, green: 0.27, blue: 0.58), primary: Color(red: 1.0, green: 0.42, blue: 0.65),
                      secondary: Color(red: 0.55, green: 0.36, blue: 0.86), text: .white,
                      mutedText: Color(red: 0.77, green: 0.84, blue: 1.0), metal: Color(red: 0.52, green: 0.91, blue: 1.0))
        case .titaniumEclipse:
            AeroTheme(id: id, background: Color(red: 0.015, green: 0.035, blue: 0.12), surface: Color(red: 0.08, green: 0.16, blue: 0.34),
                      primary: Color(red: 0.58, green: 0.88, blue: 1.0), secondary: Color(red: 0.30, green: 0.40, blue: 0.68),
                      text: .white, mutedText: Color(red: 0.72, green: 0.82, blue: 0.96), metal: Color(red: 0.80, green: 0.90, blue: 1.0))
        case .emeraldAurora:
            AeroTheme(id: id, background: Color(red: 0.01, green: 0.08, blue: 0.18), surface: Color(red: 0.03, green: 0.28, blue: 0.36),
                      primary: Color(red: 0.22, green: 1.0, blue: 0.64), secondary: Color(red: 0.20, green: 0.50, blue: 0.80),
                      text: .white, mutedText: Color(red: 0.68, green: 0.92, blue: 0.90), metal: Color(red: 0.60, green: 0.95, blue: 0.92))
        case .amberDawn:
            AeroTheme(id: id, background: Color(red: 0.14, green: 0.08, blue: 0.28), surface: Color(red: 0.48, green: 0.24, blue: 0.44),
                      primary: Color(red: 1.0, green: 0.76, blue: 0.30), secondary: Color(red: 0.96, green: 0.45, blue: 0.52),
                      text: .white, mutedText: Color(red: 1.0, green: 0.84, blue: 0.74), metal: Color(red: 1.0, green: 0.90, blue: 0.68))
        }
    }
}

private struct AeroThemeKey: EnvironmentKey { static let defaultValue = AeroTheme.palette(.crimsonNebula) }
public extension EnvironmentValues {
    var aeroTheme: AeroTheme { get { self[AeroThemeKey.self] } set { self[AeroThemeKey.self] = newValue } }
}
