import SwiftUI
import UIKit

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
    /// The system role this scales with. `.system(size:)` is a *fixed* point
    /// size — it ignores the reader's text-size setting entirely — so every
    /// style names a role and we scale through UIFontMetrics.
    let role: Font.TextStyle

    var font: Font { .system(size: size, weight: weight, design: design) }

    /// The design-system size, scaled for the current text-size setting.
    /// Capped: at the accessibility sizes an unbounded 56pt hero becomes
    /// unusable, and the layout is built around these proportions.
    func scaledSize(_ maximum: CGFloat = 1.6) -> CGFloat {
        let metrics = UIFontMetrics(forTextStyle: UIFont.TextStyle(role))
        return min(metrics.scaledValue(for: size), size * maximum)
    }

    // Display / headings use SF Pro Rounded.
    static let hero      = PlannitTextStyle(size: 56, weight: .heavy,    design: .rounded, trackingEm: -0.032, lineHeight: 1.08, role: .largeTitle)
    static let display   = PlannitTextStyle(size: 34, weight: .heavy,    design: .rounded, trackingEm: -0.024, lineHeight: 1.20, role: .largeTitle)
    static let title1    = PlannitTextStyle(size: 28, weight: .bold,     design: .rounded, trackingEm: -0.016, lineHeight: 1.20, role: .title)
    static let title2    = PlannitTextStyle(size: 22, weight: .bold,     design: .rounded, trackingEm: -0.016, lineHeight: 1.20, role: .title2)
    // Text roles use SF Pro Text (default design).
    static let title3    = PlannitTextStyle(size: 20, weight: .semibold, design: .default, trackingEm: -0.016, lineHeight: 1.20, role: .title3)
    static let headline  = PlannitTextStyle(size: 17, weight: .semibold, design: .default, trackingEm: -0.006, lineHeight: 1.35, role: .headline)
    static let body      = PlannitTextStyle(size: 17, weight: .regular,  design: .default, trackingEm: -0.006, lineHeight: 1.50, role: .body)
    static let subhead   = PlannitTextStyle(size: 15, weight: .medium,   design: .default, trackingEm: -0.006, lineHeight: 1.35, role: .subheadline)
    static let footnote  = PlannitTextStyle(size: 13, weight: .regular,  design: .default, trackingEm: 0,       lineHeight: 1.35, role: .footnote)
    static let caption   = PlannitTextStyle(size: 12, weight: .medium,   design: .default, trackingEm: 0,       lineHeight: 1.35, role: .caption)
    static let label     = PlannitTextStyle(size: 12, weight: .bold,     design: .default, trackingEm: 0.01,    lineHeight: 1.0, role: .caption)
    // Uppercase eyebrow labels (track-caps .06em).
    static let overline  = PlannitTextStyle(size: 12, weight: .semibold, design: .default, trackingEm: 0.06,    lineHeight: 1.0, role: .caption2)
}

extension View {
    /// Apply a Plannit text style (font + tracking + line spacing + color),
    /// scaled to the reader's text-size setting.
    func textStyle(_ style: PlannitTextStyle, color: Color = .textBody) -> some View {
        modifier(PlannitTextStyleModifier(style: style, color: color))
    }
}

private struct PlannitTextStyleModifier: ViewModifier {
    let style: PlannitTextStyle
    let color: Color

    // Reading this is what makes the view re-render when someone changes their
    // text size while the app is open.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let size = style.scaledSize()
        return content
            .font(.system(size: size, weight: style.weight, design: style.design))
            .tracking(style.trackingEm * size)
            .lineSpacing(max(0, size * (style.lineHeight - 1)))
            .foregroundStyle(color)
    }
}

private extension UIFont.TextStyle {
    /// SwiftUI's Font.TextStyle has no bridge to UIFont.TextStyle, and
    /// UIFontMetrics only speaks the UIKit one.
    init(_ style: Font.TextStyle) {
        switch style {
        case .largeTitle:  self = .largeTitle
        case .title:       self = .title1
        case .title2:      self = .title2
        case .title3:      self = .title3
        case .headline:    self = .headline
        case .subheadline: self = .subheadline
        case .callout:     self = .callout
        case .footnote:    self = .footnote
        case .caption:     self = .caption1
        case .caption2:    self = .caption2
        default:           self = .body
        }
    }
}
