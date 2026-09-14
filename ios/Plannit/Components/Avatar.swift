import SwiftUI

// Avatar + AvatarStack — from design-system/components/core/Avatar(.Stack).jsx.
// Initials on a name-derived hue; optional free/busy status dot.

enum AvatarStatus { case free, busy }

struct Avatar: View {
    let name: String
    var size: CGFloat = 40
    var status: AvatarStatus? = nil
    var ring: Color? = nil
    /// Overrides the name-derived colour when someone has picked one.
    var hue: GroupHue? = nil
    /// A photo to draw instead of initials. Falls back to initials while it
    /// loads and if it fails — a broken image where a face should be reads as
    /// an error, and this isn't one.
    var imageURL: String? = nil

    private var initialsCircle: some View {
        Text(initials)
            .font(.system(size: round(size * 0.4), weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background((hue ?? GroupHue.forName(name)).color)
    }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: initialsCircle
                        }
                    }
                } else {
                    initialsCircle
                }
            }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(ring ?? .clear, lineWidth: ring == nil ? 0 : 2)
                        .padding(-2)
                )
            if let status {
                Circle()
                    .fill(status == .free ? Color.statusFree : Color.statusBusy)
                    .frame(width: max(10, size * 0.28), height: max(10, size * 0.28))
                    .overlay(Circle().strokeBorder(Color.surface, lineWidth: 2))
                    .offset(x: 1, y: 1)
            }
        }
        .frame(width: size, height: size)
    }
}

struct AvatarStack: View {
    let people: [PMember]
    var size: CGFloat = 32
    var max: Int = 4

    /// Real people: each face uses the colour or photo they chose.
    init(members: [PMember], size: CGFloat = 32, max: Int = 4) {
        self.people = members
        self.size = size
        self.max = max
    }

    /// Names only, for sample rows with no profile behind them.
    init(names: [String], size: CGFloat = 32, max: Int = 4) {
        self.init(members: PMember.named(names), size: size, max: max)
    }

    /// "Maya, Theo and 4 others" — VoiceOver would otherwise read initials.
    private var spoken: String {
        guard !people.isEmpty else { return "" }
        let shown = people.prefix(2).map(\.name)
        let extra = people.count - shown.count
        if extra <= 0 { return shown.joined(separator: " and ") }
        return "\(shown.joined(separator: ", ")) and \(extra) other\(extra == 1 ? "" : "s")"
    }

    var body: some View {
        let shown = Array(people.prefix(max))
        let extra = people.count - shown.count
        HStack(spacing: -size * 0.3) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, person in
                Avatar(name: person.name, size: size, hue: person.hue, imageURL: person.avatarURL)
                    .overlay(Circle().strokeBorder(Color.surface, lineWidth: 2))
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.system(size: round(size * 0.36), weight: .bold))
                    .foregroundStyle(Color.textMuted)
                    .frame(width: size, height: size)
                    .background(Color.sunk)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.surface, lineWidth: 2))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }
}
