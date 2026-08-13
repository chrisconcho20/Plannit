import SwiftUI

// Plannit color tokens — translated 1:1 from design-system/tokens/colors.css.
// The design system is a light, warm "Ink / Paper" palette; values are literal.

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        switch s.count {
        case 8: // RRGGBBAA
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        default: // RRGGBB
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

enum Palette {
    // Coral "Ember" — primary
    static let coral50 = Color(hex: "FFF3EE"), coral100 = Color(hex: "FFE2D7")
    static let coral400 = Color(hex: "FF8360"), coral500 = Color(hex: "F76941")
    static let coral600 = Color(hex: "E4501F"), coral700 = Color(hex: "BC3D13")
    // Teal "Free" — availability / the date-finder
    static let teal50 = Color(hex: "E7F7F4"), teal100 = Color(hex: "C6EDE6")
    static let teal500 = Color(hex: "14A98F"), teal600 = Color(hex: "0E8A75"), teal700 = Color(hex: "0A6B5B")
    // Warm neutrals "Ink / Paper"
    static let ink900 = Color(hex: "1A1714"), ink800 = Color(hex: "2C2721"), ink700 = Color(hex: "3E3831")
    static let ink600 = Color(hex: "5A524A"), ink500 = Color(hex: "7A7268"), ink400 = Color(hex: "9E958A")
    static let ink300 = Color(hex: "C2B9AD"), ink200 = Color(hex: "E0D8CC"), ink100 = Color(hex: "EFE9DF"), ink50 = Color(hex: "F7F2EA")
    static let paper = Color(hex: "FFFBF6"), white = Color(hex: "FFFFFF")
    // Semantic status
    static let green500 = Color(hex: "2FA96B"), amber500 = Color(hex: "D98A0B")
    static let red500 = Color(hex: "DC3B45"), red50 = Color(hex: "FDECEC"), blue500 = Color(hex: "3E8FEB")
}

// Semantic aliases — components use these, never raw ramp values.
extension Color {
    static let appBg = Palette.paper
    static let surface = Palette.white
    static let sunk = Palette.ink50
    static let tintPrimary = Palette.coral50
    static let tintFree = Palette.teal50

    static let textStrong = Palette.ink900
    static let textBody = Palette.ink800
    static let textMuted = Palette.ink500
    static let textFaint = Palette.ink400
    static let textOnPrimary = Palette.white
    static let textLink = Palette.coral600

    static let hairline = Palette.ink100
    static let lineStrong = Palette.ink200
    static let lineFocus = Palette.coral400

    static let actionPrimary = Palette.coral500
    static let actionPrimaryPress = Palette.coral600
    static let actionSecondary = Palette.ink50
    static let actionSecondaryPress = Palette.ink100
    static let actionDisabled = Palette.ink200

    static let statusFree = Palette.teal500
    static let statusBusy = Palette.ink300
    static let statusSuccess = Palette.green500
    static let statusWarning = Palette.amber500
    static let statusDanger = Palette.red500
    static let statusInfo = Palette.blue500

    static let scrim = Color(hex: "1A1714").opacity(0.44)
}

// Per-group event hues (six, assigned round-robin) — colors.css group hues.
enum GroupHue: String, CaseIterable, Codable {
    case coral, amber, teal, sky, indigo, rose

    var color: Color {
        switch self {
        case .coral: return Color(hex: "F76941")
        case .amber: return Color(hex: "F2A63B")
        case .teal: return Color(hex: "14A98F")
        case .sky: return Color(hex: "3E8FEB")
        case .indigo: return Color(hex: "6A6FE0")
        case .rose: return Color(hex: "E45A96")
        }
    }
    var soft: Color {
        switch self {
        case .coral: return Color(hex: "FFE2D7")
        case .amber: return Color(hex: "FDEDD3")
        case .teal: return Color(hex: "C6EDE6")
        case .sky: return Color(hex: "DCEAFD")
        case .indigo: return Color(hex: "E2E3FB")
        case .rose: return Color(hex: "FBDFEB")
        }
    }

    /// Deterministic hue from a name (mirrors the DS Avatar hash).
    static func forName(_ name: String) -> GroupHue {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return allCases[sum % allCases.count]
    }
}
