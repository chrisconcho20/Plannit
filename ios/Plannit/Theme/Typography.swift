import SwiftUI

// Typography — from design-system/tokens/typography.css.
// The DS fonts note states Plannit's real type is Apple SF Pro / SF Pro Rounded
// (Figtree was only a web stand-in), so display roles use the rounded design
// and text roles use the default (SF Pro Text). No bundled fonts needed.

struct PlannitTextStyle {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let trackingEm: CGFloat
    let lineHeight: CGFloat  // multiplier

    var font: Font { .system(size: size, weight: weight, design: design) }

    // Display / headings use SF Pro Rounded.
    static let hero      = PlannitTextStyle(size: 56, weight: .heavy,    design: .rounded, trackingEm: -0.032, lineHeight: 1.08)
    static let display   = PlannitTextStyle(size: 34, weight: .heavy,    design: .rounded, trackingEm: -0.024, lineHeight: 1.20)
    static let title1    = PlannitTextStyle(size: 28, weight: .bold,     design: .rounded, trackingEm: -0.016, lineHeight: 1.20)
    static let title2    = PlannitTextStyle(size: 22, weight: .bold,     design: .rounded, trackingEm: -0.016, lineHeight: 1.20)
    // Text roles use SF Pro Text (default design).
    static let title3    = PlannitTextStyle(size: 20, weight: .semibold, design: .default, trackingEm: -0.016, lineHeight: 1.20)
    static let headline  = PlannitTextStyle(size: 17, weight: .semibold, design: .default, trackingEm: -0.006, lineHeight: 1.35)
    static let body      = PlannitTextStyle(size: 17, weight: .regular,  design: .default, trackingEm: -0.006, lineHeight: 1.50)
    static let subhead   = PlannitTextStyle(size: 15, weight: .medium,   design: .default, trackingEm: -0.006, lineHeight: 1.35)
    static let footnote  = PlannitTextStyle(size: 13, weight: .regular,  design: .default, trackingEm: 0,       lineHeight: 1.35)
    static let caption   = PlannitTextStyle(size: 12, weight: .medium,   design: .default, trackingEm: 0,       lineHeight: 1.35)
    static let label     = PlannitTextStyle(size: 12, weight: .bold,     design: .default, trackingEm: 0.01,    lineHeight: 1.0)
    // Uppercase eyebrow labels (track-caps .06em).
    static let overline  = PlannitTextStyle(size: 12, weight: .semibold, design: .default, trackingEm: 0.06,    lineHeight: 1.0)
}

extension View {
    /// Apply a Plannit text style (font + tracking + line spacing + color).
    func textStyle(_ style: PlannitTextStyle, color: Color = .textBody) -> some View {
        self.font(style.font)
            .tracking(style.trackingEm * style.size)
            .lineSpacing(max(0, style.size * (style.lineHeight - 1)))
            .foregroundStyle(color)
    }
}
