import SwiftUI

// EventCard — from design-system/components/calendar/EventCard.jsx.

struct EventCard: View {
    let title: String
    let time: String
    var location: String? = nil
    var hue: GroupHue = .coral
    var group: String? = nil
    var people: [String] = []
    var icon: String = "calendar"
    var badge: String? = nil
    var badgeTone: BadgeTone = .neutral

    var body: some View {
        PlannitCard(elevation: 1, padding: 0) {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(hue.color)
                        .frame(width: 44, height: 44)
                        .overlay(PIcon(icon, size: 22, color: .white, weight: .semibold))

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(title).textStyle(.headline, color: .textStrong).lineLimit(1)
                            Spacer(minLength: 0)
                            if let badge { Badge(text: badge, tone: badgeTone) }
                        }
                        HStack(spacing: 6) {
                            PIcon("clock", size: 13, color: .textMuted)
                            Text(time).textStyle(.footnote, color: .textMuted)
                            if let location {
                                Text("·").foregroundStyle(Color.textFaint)
                                PIcon("map-pin", size: 13, color: .textMuted)
                                Text(location).textStyle(.footnote, color: .textMuted).lineLimit(1)
                            }
                        }
                        if group != nil || !people.isEmpty {
                            HStack(spacing: 8) {
                                if let group {
                                    HStack(spacing: 5) {
                                        Circle().fill(hue.color).frame(width: 7, height: 7)
                                        Text(group).textStyle(.caption, color: .textMuted)
                                    }
                                }
                                Spacer(minLength: 0)
                                if !people.isEmpty { AvatarStack(names: people, size: 24, max: 4) }
                            }
                            .padding(.top, 7)
                        }
                    }
                }
                .padding(.vertical, 14)
                .padding(.leading, 14)
                .padding(.trailing, 16)
        }
    }
}
