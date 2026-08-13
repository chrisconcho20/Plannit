import SwiftUI

// GroupCard — a group row with hue tile, name, note and member stack.

struct GroupCard: View {
    let name: String
    var note: String? = nil
    var hue: GroupHue = .coral
    var members: [String] = []
    var icon: String = "users"

    var body: some View {
        PlannitCard(elevation: 1, padding: 0) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(hue.color)
                    .frame(width: 48, height: 48)
                    .overlay(PIcon(icon, size: 22, color: .white, weight: .semibold))

                VStack(alignment: .leading, spacing: 3) {
                    Text(name).textStyle(.headline, color: .textStrong)
                    if let note { Text(note).textStyle(.footnote, color: .textMuted).lineLimit(1) }
                }
                Spacer(minLength: 0)
                if !members.isEmpty { AvatarStack(names: members, size: 26, max: 3) }
                PIcon("chevron-right", size: 18, color: .textFaint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
    }
}
