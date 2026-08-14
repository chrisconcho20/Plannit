import SwiftUI

// Button — from design-system/components/core/Button.jsx. Pill shape, press scale.

enum PBtnVariant { case primary, secondary, outline, ghost, free, danger }

enum PBtnSize {
    case sm, md, lg
    var height: CGFloat { self == .sm ? 36 : self == .md ? 46 : 54 }
    var padH: CGFloat { self == .sm ? 14 : self == .md ? 18 : 22 }
    var iconSize: CGFloat { self == .sm ? 16 : self == .md ? 18 : 20 }
    var gap: CGFloat { self == .sm ? 6 : self == .md ? 8 : 10 }
    var textStyle: PlannitTextStyle {
        switch self {
        case .sm: return .subhead
        case .md: return .headline
        case .lg: return PlannitTextStyle(size: 17, weight: .bold, design: .rounded, trackingEm: -0.006, lineHeight: 1, role: .headline)
        }
    }
}

struct PlannitButton: View {
    let title: String
    var variant: PBtnVariant = .primary
    var size: PBtnSize = .md
    var icon: String? = nil
    var iconAfter: String? = nil
    var fullWidth: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: size.gap) {
                if let icon { Image(systemName: PIcon.symbol(icon)).font(.system(size: size.iconSize, weight: .semibold)) }
                Text(title)
                if let iconAfter { Image(systemName: PIcon.symbol(iconAfter)).font(.system(size: size.iconSize, weight: .semibold)) }
            }
        }
        .buttonStyle(PlannitButtonStyle(variant: variant, size: size, fullWidth: fullWidth))
    }
}

struct PlannitButtonStyle: ButtonStyle {
    let variant: PBtnVariant
    let size: PBtnSize
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .textStyle(size.textStyle, color: fg)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: size.height)
            .padding(.horizontal, size.padH)
            .background(bg(pressed))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(Color.lineStrong, lineWidth: variant == .outline ? 1.5 : 0)
            )
            .modifier(PrimaryGlow(active: variant == .primary && !pressed))
            .scaleEffect(pressed ? Motion.pressScale : 1)
            .animation(Motion.fast, value: pressed)
    }

    private var fg: Color {
        switch variant {
        case .primary, .free: return .textOnPrimary
        case .secondary, .outline: return .textStrong
        case .ghost: return .textLink
        case .danger: return .statusDanger
        }
    }
    private func bg(_ p: Bool) -> Color {
        switch variant {
        case .primary: return p ? .actionPrimaryPress : .actionPrimary
        case .secondary: return p ? .actionSecondaryPress : .actionSecondary
        case .free: return p ? Palette.teal600 : .statusFree
        case .outline, .ghost: return p ? .sunk : .clear
        case .danger: return .clear
        }
    }
}

private struct PrimaryGlow: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        active ? AnyView(content.primaryGlow()) : AnyView(content)
    }
}

// Circular icon button — used for nav actions and the FAB.
struct IconButton: View {
    let icon: String
    var variant: PBtnVariant = .secondary
    var size: CGFloat = 44
    var iconSize: CGFloat = 20
    var accessibilityLabel: String = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: PIcon.symbol(icon))
                .font(.system(size: iconSize, weight: .semibold))
        }
        .buttonStyle(IconButtonStyle(variant: variant, size: size))
        // The circle can be as small as the design calls for, but the *target*
        // never goes below Apple's 44pt minimum — several of ours are 32pt, and
        // a missed tap on "remove member" is worse than a little extra padding.
        .frame(minWidth: Self.minimumTarget, minHeight: Self.minimumTarget)
        .contentShape(Rectangle())
        .accessibilityLabel(accessibilityLabel)
    }

    static let minimumTarget: CGFloat = 44
}

struct IconButtonStyle: ButtonStyle {
    let variant: PBtnVariant
    let size: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .foregroundStyle(fg)
            .frame(width: size, height: size)
            .background(bg(pressed))
            .clipShape(Circle())
            .modifier(PrimaryGlow(active: variant == .primary && !pressed))
            .scaleEffect(pressed ? Motion.pressScale : 1)
            .animation(Motion.fast, value: pressed)
    }
    private var fg: Color { variant == .primary ? .textOnPrimary : .textStrong }
    private func bg(_ p: Bool) -> Color {
        switch variant {
        case .primary: return p ? .actionPrimaryPress : .actionPrimary
        default: return p ? .actionSecondaryPress : .actionSecondary
        }
    }
}

// Subtle press feedback for tappable cards.
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(Motion.fast, value: configuration.isPressed)
    }
}
