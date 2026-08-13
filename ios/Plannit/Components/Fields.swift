import SwiftUI

// Form controls used by the create sheets — from the DS forms/* components.

struct PTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let icon { PIcon(icon, size: 18, color: .textFaint) }
            TextField(placeholder, text: $text).textStyle(.body, color: .textStrong)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
            .strokeBorder(Color.lineStrong, lineWidth: 1))
    }
}

struct HuePicker: View {
    @Binding var selection: GroupHue

    var body: some View {
        HStack(spacing: 12) {
            ForEach(GroupHue.allCases, id: \.self) { hue in
                Circle().fill(hue.color).frame(width: 36, height: 36)
                    .overlay(Circle().strokeBorder(Color.actionPrimary, lineWidth: selection == hue ? 3 : 0).padding(-3))
                    .overlay(selection == hue ? PIcon("check", size: 16, color: .white, weight: .bold) : nil)
                    .contentShape(Circle())
                    .onTapGesture { withAnimation(Motion.fast) { selection = hue } }
            }
            Spacer(minLength: 0)
        }
    }
}

struct SelectableChip: View {
    let label: String
    let selected: Bool
    var onTap: () -> Void

    var body: some View {
        Text(label)
            .textStyle(.subhead, color: selected ? .textOnPrimary : .textBody)
            .padding(.horizontal, 14)
            .frame(minHeight: 38)
            .background(selected ? Color.actionPrimary : Color.sunk)
            .clipShape(Capsule())
            .contentShape(Capsule())
            .onTapGesture(perform: onTap)
    }
}

// Sheet grabber + title header used by the create/detail sheets.
struct SheetHeader: View {
    let title: String
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.lineStrong).frame(width: 40, height: 5).padding(.vertical, 10)
            HStack {
                Text(title).textStyle(.title3, color: .textStrong)
                Spacer()
                IconButton(icon: "x", variant: .secondary, size: 36, iconSize: 16,
                           accessibilityLabel: "Close", action: onClose)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, 8)
        }
    }
}
