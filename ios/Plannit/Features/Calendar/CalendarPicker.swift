import EventKit
import SwiftUI

// Which of your calendars Plannit is allowed to look at.
//
// This is a scheduling control, not a display preference. Everything switched on
// here feeds availability, so a subscribed fixtures feed or a shared family
// calendar can mark you busy for the whole group — and until this screen existed
// there was no way to say "that one isn't me".
//
// Off means off in both directions: the events stop appearing in the calendar
// list *and* stop counting towards when you're free. Anything else would be a
// confusing half-measure.

struct CalendarPicker: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var excluded = CalendarService.excludedCalendarIds

    private var calendars: [EKCalendar] { model.selectableCalendars() }

    /// Grouped by account, the way the Calendar app shows them — "Work" means
    /// something different under Exchange than under iCloud.
    private var bySource: [(source: String, calendars: [EKCalendar])] {
        let groups = Dictionary(grouping: calendars) { $0.source?.title ?? "Other" }
        return groups.keys.sorted().map { (source: $0, calendars: groups[$0] ?? []) }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Your calendars") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 8) {
                        PIcon("info", size: 16, color: Palette.teal600)
                        Text("Anything switched on counts towards when you're busy. "
                             + "Titles never leave your phone — only free/busy does.")
                            .textStyle(.footnote, color: Palette.teal700)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.teal50)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

                    if calendars.isEmpty {
                        EmptyState(icon: "calendar",
                                   title: "No calendars to show",
                                   message: model.calendarAuthorized
                                            ? "This device has no calendars yet. Add one in the Calendar app."
                                            : "Plannit can't read your calendars yet. Turn that on in Settings.")
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(bySource, id: \.source) { group in
                        VStack(alignment: .leading, spacing: Space.gapList) {
                            Text(group.source.uppercased())
                                .textStyle(.overline, color: .textFaint)
                            VStack(spacing: 0) {
                                ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                                    row(for: calendar)
                                    if calendar.calendarIdentifier
                                        != group.calendars.last?.calendarIdentifier {
                                        Rectangle().fill(Color.hairline).frame(height: 1)
                                    }
                                }
                            }
                            .padding(.horizontal, Space.card)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                                .strokeBorder(Color.hairline, lineWidth: 1))
                        }
                    }

                    Text("A calendar added later is included automatically — Plannit only "
                         + "remembers the ones you switch off.")
                        .textStyle(.caption, color: .textFaint)

                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 4)
            }
        }
        .background(Color.appBg)
    }

    private func row(for calendar: EKCalendar) -> some View {
        let on = !excluded.contains(calendar.calendarIdentifier)
        return HStack(spacing: 12) {
            Circle()
                .fill(calendar.cgColor.map { Color($0) } ?? GroupHue.coral.color)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(calendar.title).textStyle(.headline, color: .textStrong)
                if !calendar.allowsContentModifications {
                    Text("Subscribed").textStyle(.caption, color: .textMuted)
                }
            }
            Spacer(minLength: 0)
            Toggle("", isOn: Binding(
                get: { on },
                set: { newValue in
                    if newValue { excluded.remove(calendar.calendarIdentifier) }
                    else { excluded.insert(calendar.calendarIdentifier) }
                    model.setCalendar(calendar, enabled: newValue)
                }))
                .labelsHidden()
                .tint(.statusFree)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(calendar.title), \(on ? "on" : "off")")
    }
}
