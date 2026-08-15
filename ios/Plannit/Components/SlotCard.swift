import SwiftUI

// SlotCard — from design-system/components/calendar/SlotCard.jsx.
// The date-finder result row: date tile, time, "X of Y free", Best badge.

struct SlotCard: View {
    let day: String
    let date: Int
    let time: String
    let freeCount: Int
    let total: Int
    var people: [String] = []
    var best: Bool = false
    var selected: Bool = false

    private var allFree: Bool { freeCount == total }

    /// "Saturday the 16th, 2:00 to 4:00 PM, everyone free, best option,
    /// selected" — the point of the card, in the order that matters.
    private var spoken: String {
        var parts = ["\(day) \(date)", time]
        parts.append(allFree ? "everyone free" : "\(freeCount) of \(total) free")
        if best { parts.append("best option") }
        if selected { parts.append("selected") }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        PlannitCard(elevation: selected ? 2 : 1, padding: 0) {
            HStack(spacing: 14) {
                VStack(spacing: 0) {
                    Text(day).textStyle(.overline, color: allFree ? Palette.teal700 : .textMuted)
                    Text("\(date)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(allFree ? Palette.teal700 : .textStrong)
                }
                .frame(width: 52)
                .padding(.vertical, 6)
                .background(allFree ? Palette.teal50 : Color.sunk)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(time).textStyle(.headline, color: .textStrong)
                        if best { Badge(text: "Best", tone: .primary, icon: "sparkles") }
                    }
                    HStack(spacing: 8) {
                        Badge(text: "\(freeCount) of \(total) free",
                              tone: allFree ? .free : .neutral,
                              icon: allFree ? "check" : nil)
                        Spacer(minLength: 0)
                        if !people.isEmpty { AvatarStack(names: people, size: 24, max: 4) }
                    }
                }
                PIcon("chevron-right", size: 18, color: .textFaint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Color.actionPrimary, lineWidth: selected ? 2 : 0)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
