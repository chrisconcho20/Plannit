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
    @State private var duration = "1h"
    @State private var allDay = false
    @State private var shareWithGroup = true
    @State private var saving = false
    @State private var errorText: String?

    private let durations = ["30m", "1h", "2h", "3h"]

    init(date: Date = Date(), group: PGroup? = nil, editing: PEvent? = nil) {
        self.date = date
        self.group = group
        self.editing = editing

        if let editing {
            _title = State(initialValue: editing.title)
            _location = State(initialValue: editing.location ?? "")
            _start = State(initialValue: editing.start)
            let minutes = Int((editing.end ?? editing.start.addingTimeInterval(3600))
                                .timeIntervalSince(editing.start) / 60)
            _duration = State(initialValue: Self.label(forMinutes: minutes))
            _allDay = State(initialValue: editing.isAllDay)
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
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .strokeBorder(Color.lineStrong, lineWidth: 1))

                    if !allDay {
                        fieldLabel("How long")
                        HStack(spacing: 8) {
                            ForEach(durations, id: \.self) { d in
                                SelectableChip(label: d, selected: duration == d) {
                                    withAnimation(Motion.fast) { duration = d }
                                }
                            }
                        }
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
    }

    private func save() {
        saving = true
        errorText = nil
        let name = title.trimmingCharacters(in: .whitespaces)
        let place = location.trimmingCharacters(in: .whitespaces)
        Task {
            let ok: Bool
            if let editing {
                ok = await model.updateEvent(editing, title: name, start: start,
                                             minutes: Self.minutes(duration), location: place,
                                             allDay: allDay)
            } else {
                ok = await model.createEvent(title: name, start: start,
                                             minutes: Self.minutes(duration), location: place,
                                             allDay: allDay,
                                             shareWith: shareWithGroup ? group : nil)
            }
            saving = false
            if ok { dismiss() } else { errorText = "Couldn’t save that. Check your connection and try again." }
        }
    }

    /// Nearest chip to a real duration, so editing a 90-minute event doesn't
    /// silently round it away without showing you. Ordered, not a dictionary:
    /// an exact tie (90 minutes) must always resolve the same way — down.
    static func label(forMinutes minutes: Int) -> String {
        let options = [("30m", 30), ("1h", 60), ("2h", 120), ("3h", 180)]
        var best = options[0]
        for option in options.dropFirst() where abs(option.1 - minutes) < abs(best.1 - minutes) {
            best = option
        }
        return best.0   // strict <, so a tie keeps the shorter chip
    }

    /// "30m" → 30 · "2h" → 120.
    static func minutes(_ label: String) -> Int {
        let n = Int(label.filter(\.isNumber)) ?? 1
        return label.hasSuffix("m") ? n : n * 60
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased()).textStyle(.overline, color: .textFaint)
    }
}
