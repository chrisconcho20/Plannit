import SwiftUI

// Avatar + AvatarStack — from design-system/components/core/Avatar(.Stack).jsx.
// Initials on a name-derived hue; optional free/busy status dot.

enum AvatarStatus { case free, busy }

struct Avatar: View {
    let name: String
    var size: CGFloat = 40
    var status: AvatarStatus? = nil
    var ring: Color? = nil

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(initials)
                .font(.system(size: round(size * 0.4), weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(GroupHue.forName(name).color)
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
    let names: [String]
    var size: CGFloat = 32
    var max: Int = 4

    var body: some View {
        let shown = Array(names.prefix(max))
        let extra = names.count - shown.count
        HStack(spacing: -size * 0.3) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, n in
                Avatar(name: n, size: size)
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
    }
}
