import SwiftUI

// NewEventSheet — put something on your own calendar, or change something
// that's already there. In live mode this writes a row to `events`
// (owner_id = you, source = plannit); in demo mode it just appends locally.
// Sharing it with a group is a separate, deliberate step — events are private
// until you say otherwise.

struct NewEventSheet: View {
    var date: Date = Date()
    /// Set when the sheet is opened from inside a group: the event is shared
    /// with it on save unless you untick.
    var group: PGroup? = nil
    /// Set to edit an existing event instead of creating one.
    var editing: PEvent? = nil

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var location = ""
    @State private var start = Date()
    @State private var end = Date()
    @State private var allDay = false
    @State private var repeats: RepeatRule = .never
    @State private var shareWithGroup = true
    @State private var saving = false
    @State private var errorText: String?

    init(date: Date = Date(), group: PGroup? = nil, editing: PEvent? = nil) {
        self.date = date
        self.group = group
        self.editing = editing

        if let editing {
            _title = State(initialValue: editing.title)
            _location = State(initialValue: editing.location ?? "")
            _start = State(initialValue: editing.start)
            _end = State(initialValue: editing.end ?? editing.start.addingTimeInterval(3600))
            _allDay = State(initialValue: editing.isAllDay)
            _repeats = State(initialValue: editing.recurrence)
            _shareWithGroup = State(initialValue: false)   // sharing is its own sheet
            return
        }
        // Open on the chosen day at the next whole hour, or 9am for a future day.
        let cal = Calendar.current
        let base: Date
        if cal.isDateInToday(date) {
            base = cal.date(bySetting: .minute, value: 0,
                            of: cal.date(byAdding: .hour, value: 1, to: date) ?? date) ?? date
        } else {
            base = cal.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        }
        _start = State(initialValue: base)
        _end = State(initialValue: base.addingTimeInterval(3600))
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: editing == nil ? "New event" : "Edit event") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    fieldLabel("What")
                    PTextField(placeholder: "e.g. Five-a-side", text: $title, icon: "sparkles")

                    fieldLabel("When")
                    VStack(spacing: 0) {
                        // Real calendars are full of all-day entries; without
                        // this you can only make timed ones.
                        Toggle(isOn: $allDay.animation(Motion.fast)) {
                            Text("All day").textStyle(.body, color: .textStrong)
                        }
                        .tint(.actionPrimary)
                        .padding(.vertical, 10)
                        Divider().overlay(Color.hairline)
                        DatePicker(allDay ? "Date" : "Starts", selection: $start,
                                   displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .tint(.actionPrimary)
                            .textStyle(.body, color: .textStrong)
                            .padding(.vertical, 4)
                        if !allDay {
                            Divider().overlay(Color.hairline)
                            // An end time, not a duration. "How long" is a
                            // constraint for the date-finder — when you already
                            // know the time, you know when it ends.
                            DatePicker("Ends", selection: $end,
                                       in: start...,
                                       displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .tint(.actionPrimary)
                                .textStyle(.body, color: .textStrong)
                                .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .strokeBorder(Color.lineStrong, lineWidth: 1))

                    fieldLabel("Repeats")
                    Menu {
                        ForEach(RepeatRule.allCases) { rule in
                            Button(rule.label) { repeats = rule }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            PIcon("repeat", size: 18, color: .textFaint)
                            Text(repeats.label).textStyle(.body, color: .textStrong)
                            Spacer()
                            PIcon("chevron-down", size: 16, color: .textFaint)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                            .strokeBorder(Color.lineStrong, lineWidth: 1))
                    }

                    fieldLabel("Where (optional)")
                    PTextField(placeholder: "Add a place", text: $location, icon: "map-pin")

                    if let errorText {
                        HStack(spacing: 8) {
                            PIcon("circle-alert", size: 16, color: .statusDanger)
                            Text(errorText).textStyle(.footnote, color: .statusDanger)
                        }
                    }

                    if let group, editing == nil {
                        Button { withAnimation(Motion.fast) { shareWithGroup.toggle() } } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .fill(group.hue.color).frame(width: 30, height: 30)
                                    .overlay(PIcon("users", size: 15, color: .white))
                                Text("Share with \(group.name)").textStyle(.body, color: .textStrong)
                                Spacer()
                                PIcon(shareWithGroup ? "circle-check" : "circle", size: 22,
                                      color: shareWithGroup ? .actionPrimary : .textFaint)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        PIcon("lock", size: 16, color: .textFaint)
                        Text(group != nil && shareWithGroup
                             ? "Everyone in \(group!.name) will see this event."
                             : "Only you can see this until you share it with a group.")
                            .textStyle(.caption, color: .textMuted)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 4)
            }

            VStack(spacing: 0) {
                Divider().overlay(Color.hairline)
                PlannitButton(title: saving ? "Saving…" : (editing == nil ? "Add to calendar" : "Save changes"),
                              variant: .primary, size: .lg,
                              icon: editing == nil ? "calendar-plus" : "check", fullWidth: true) {
                    save()
                }
                .disabled(saving || title.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(saving || title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                .padding(Space.gutter)
            }
            .background(.ultraThinMaterial)
        }
        .background(Color.appBg)
        .presentationDetents([.large])
        // Dragging the start past the end would otherwise save an event that
        // finishes before it begins; the DatePicker's range stops you choosing
        // one, but not moving the other.
        .onChange(of: start) { _, newStart in
            if end <= newStart { end = newStart.addingTimeInterval(3600) }
        }
    }

    private func save() {
        saving = true
        errorText = nil
        let name = title.trimmingCharacters(in: .whitespaces)
        let place = location.trimmingCharacters(in: .whitespaces)
        Task {
            let ok: Bool
            if let editing {
                ok = await model.updateEvent(editing, title: name, start: start, end: end,
                                             location: place, allDay: allDay, repeats: repeats)
            } else {
                ok = await model.createEvent(title: name, start: start, end: end,
                                             location: place, allDay: allDay, repeats: repeats,
                                             shareWith: shareWithGroup ? group : nil)
            }
            saving = false
            if ok { dismiss() } else { errorText = "Couldn’t save that. Check your connection and try again." }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased()).textStyle(.overline, color: .textFaint)
    }
}
