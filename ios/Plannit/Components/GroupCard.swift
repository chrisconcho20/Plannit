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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(.isButton)
    }

    /// "Soccer, 6 people, Tuesday and weekend games" — the avatar stack is
    /// decoration, so it's summarised as a count rather than six names.
    private var spoken: String {
        var parts = [name]
        if !members.isEmpty {
            parts.append(members.count == 1 ? "1 person" : "\(members.count) people")
        }
        if let note, !note.isEmpty { parts.append(note) }
        return parts.joined(separator: ", ")
    }
}
