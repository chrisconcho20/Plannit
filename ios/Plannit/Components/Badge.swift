import SwiftUI

// Badge — from design-system/components/core/Badge.jsx. Small pill label.

enum BadgeTone { case neutral, primary, free, warning, danger, solid
    var bg: Color {
        switch self {
        case .neutral: return .sunk
        case .primary: return Palette.coral50
        case .free: return Palette.teal50
        case .warning: return Color(hex: "FDF3E0")
        case .danger: return Palette.red50
        case .solid: return .actionPrimary
        }
    }
    var fg: Color {
        switch self {
        case .neutral: return .textMuted
        case .primary: return Palette.coral700
        case .free: return Palette.teal700
        case .warning: return .statusWarning
        case .danger: return .statusDanger
        case .solid: return .textOnPrimary
        }
    }
}

struct Badge: View {
    let text: String
    var tone: BadgeTone = .neutral
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: PIcon.symbol(icon)).font(.system(size: 11, weight: .bold)) }
            Text(text)
        }
        .textStyle(.label, color: tone.fg)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tone.bg)
        .clipShape(Capsule())
    }
}
