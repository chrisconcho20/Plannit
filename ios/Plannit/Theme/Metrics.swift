import SwiftUI

// Spacing, radius, elevation and motion — from the DS spacing/radius/elevation/motion tokens.

enum Space {
    static let x1: CGFloat = 2,  x2: CGFloat = 4,  x3: CGFloat = 6,  x4: CGFloat = 8
    static let x5: CGFloat = 12, x6: CGFloat = 16, x7: CGFloat = 20, x8: CGFloat = 24
    static let x9: CGFloat = 32, x10: CGFloat = 40, x11: CGFloat = 48, x12: CGFloat = 64
    // Layout roles
    static let gutter: CGFloat = 20   // screen side padding
    static let card: CGFloat = 16     // inside a card
    static let gapList: CGFloat = 12  // between stacked cards
    static let gapInline: CGFloat = 8
    static let tapMin: CGFloat = 44
    static let navH: CGFloat = 52
    static let tabBarH: CGFloat = 56
}

enum Radius {
    static let xs: CGFloat = 6, sm: CGFloat = 10, md: CGFloat = 14
    static let lg: CGFloat = 18, xl: CGFloat = 24, xxl: CGFloat = 32, pill: CGFloat = 999
    // Roles
    static let control: CGFloat = 14  // buttons, inputs
    static let card: CGFloat = 18     // cards, list groups
    static let sheet: CGFloat = 32    // bottom sheets
}

// Elevation — approximates the layered shadow tokens with a single soft shadow per level.
extension View {
    @ViewBuilder
    func elevation(_ level: Int) -> some View {
        switch level {
        case 1: shadow(color: Palette.ink900.opacity(0.06), radius: 3, x: 0, y: 1)
        case 2: shadow(color: Palette.ink900.opacity(0.10), radius: 10, x: 0, y: 4)
        case 3: shadow(color: Palette.ink900.opacity(0.16), radius: 26, x: 0, y: 14)
        default: self
        }
    }
    /// The coral glow under primary actions (shadow-primary).
    func primaryGlow() -> some View {
        shadow(color: Palette.coral600.opacity(0.36), radius: 14, x: 0, y: 6)
    }
}

enum Motion {
    static let fast = Animation.easeOut(duration: 0.14)
    static let base = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.22)   // ease-ios
    static let slow = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.34)
    static let pop  = Animation.timingCurve(0.34, 1.4, 0.64, 1, duration: 0.22) // confirmations
    static let pressScale: CGFloat = 0.97
}
