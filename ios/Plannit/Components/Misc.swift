import SwiftUI

// Shared small components: section label, segmented control, empty state, toast, nav bar.

struct SectionLabel<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title.uppercased()).textStyle(.overline, color: .textFaint)
            Spacer()
            trailing
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }
}
extension SectionLabel where Trailing == EmptyView {
    init(_ title: String) { self.init(title) { EmptyView() } }
}

struct SegmentedControl<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    var label: (T) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { opt in
                let on = opt == selection
                Text(label(opt))
                    .textStyle(.subhead, color: on ? Palette.coral700 : .textMuted)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(on ? Color.surface : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .elevation(on ? 1 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(Motion.fast) { selection = opt } }
            }
        }
        .padding(4)
        .background(Color.sunk)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            Circle().fill(Color.sunk).frame(width: 64, height: 64)
                .overlay(PIcon(icon, size: 28, color: .textFaint))
            Text(title).textStyle(.title3, color: .textStrong)
            if let message {
                Text(message).textStyle(.subhead, color: .textMuted)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle {
                PlannitButton(title: actionTitle, variant: .secondary, size: .sm, action: action)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: 280)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

struct Toast: View {
    let text: String
    var icon: String = "circle-check"
    var tone: BadgeTone = .free

    var body: some View {
        HStack(spacing: 10) {
            PIcon(icon, size: 18, color: tone.fg)
            Text(text).textStyle(.subhead, color: .textStrong)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(tone.bg, lineWidth: 1))
        .elevation(3)
    }
}

// Large-title nav bar with optional back and trailing action.
struct NavBar<Trailing: View>: View {
    let title: String
    let onBack: (() -> Void)?
    let trailing: Trailing

    init(_ title: String, onBack: (() -> Void)? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.onBack = onBack
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            if let onBack {
                IconButton(icon: "chevron-left", variant: .secondary, size: 40, iconSize: 18,
                           accessibilityLabel: "Back", action: onBack)
            }
            Text(title).textStyle(.title1, color: .textStrong)
            Spacer()
            trailing
        }
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, 8)
    }
}
extension NavBar where Trailing == EmptyView {
    init(_ title: String, onBack: (() -> Void)? = nil) { self.init(title, onBack: onBack) { EmptyView() } }
}
