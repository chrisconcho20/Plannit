import SwiftUI

// CreateSheet — what the ＋ opens. Both routes end in an event on the calendar;
// the question is only whether Plannit picks the time or you do. When it's
// opened from inside a group, both routes are scoped to that group.

struct CreateSheet: View {
    enum Choice { case findADate, addEvent, newGroup }

    var group: PGroup? = nil
    var offerNewGroup = false
    let onChoose: (Choice) -> Void

    @Environment(\.dismiss) private var dismiss

    private var forWhom: String { group.map { " with \($0.name)" } ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: group.map { "New in \($0.name)" } ?? "What are you making?") {
                dismiss()
            }
            VStack(spacing: Space.gapList) {
                option(icon: "wand-sparkles",
                       hue: .teal,
                       title: "Find a time that works",
                       body: "Plannit checks everyone's calendars\(forWhom) and offers the dates the whole group can make.",
                       choice: .findADate)

                option(icon: "calendar-plus",
                       hue: .coral,
                       title: "Add an event myself",
                       body: group == nil
                             ? "Pick the date, time and place. It stays private until you share it."
                             : "Pick the date, time and place, and share it with \(group!.name) right away.",
                       choice: .addEvent)

                if offerNewGroup {
                    option(icon: "users",
                           hue: .indigo,
                           title: "Make a group",
                           body: "A set of people you plan with — the date-finder works across a group.",
                           choice: .newGroup)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, 4)
            Spacer(minLength: 0)
        }
        .background(Color.appBg)
        .presentationDetents([.height(offerNewGroup ? 460 : 360)])
    }

    private func option(icon: String, hue: GroupHue, title: String, body: String,
                        choice: Choice) -> some View {
        Button { onChoose(choice) } label: {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(hue.soft).frame(width: 46, height: 46)
                    .overlay(PIcon(icon, size: 22, color: hue.color, weight: .semibold))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).textStyle(.headline, color: .textStrong)
                    Text(body).textStyle(.footnote, color: .textMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                PIcon("chevron-right", size: 16, color: .textFaint).padding(.top, 4)
            }
            .padding(Space.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Color.hairline, lineWidth: 1))
        }
        .buttonStyle(CardPressStyle())
    }
}
