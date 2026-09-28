import SwiftUI

// QuietPlanSheet — offer a window without telling anybody.
//
// The other two routes from the ＋ announce themselves: a found date goes to
// the group, an event you add can be shared. This one says nothing. It stores a
// window, and only if enough of the group independently says the same does any
// of it become visible — as an ordinary plan everyone answers.
//
// So the copy has one job: make it unmistakable that nothing is being sent.
// Somebody who thinks they've invited their friends, and hasn't, has been
// misled by this screen.

struct QuietPlanSheet: View {
    /// Set when opened from inside a group; otherwise they pick one.
    var group: PGroup? = nil
    var date: Date = Date()

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var chosenGroup: PGroup?
    @State private var start = Date()
    @State private var end = Date()
    @State private var minMinutes = 60
    @State private var saving = false
    @State private var errorText: String?

    private static let lengths = [30, 60, 90, 120, 180]

    init(group: PGroup? = nil, date: Date = Date()) {
        self.group = group
        self.date = date
        _chosenGroup = State(initialValue: group)
        let cal = Calendar.current
        // Default to an afternoon: the window people actually mean when they
        // say "free on Saturday".
        let base = cal.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        _start = State(initialValue: base)
        _end = State(initialValue: cal.date(bySettingHour: 18, minute: 0, second: 0, of: date) ?? base)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Quiet plan") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    calloutCard

                    fieldLabel("With which group")
                    groupPicker

                    fieldLabel("What, if you know")
                    PTextField(placeholder: "e.g. a walk, or nothing in particular",
                               text: $title, icon: "sparkles")

                    fieldLabel("When you're free")
                    windowCard

                    fieldLabel("Worth it if you get at least")
                    Menu {
                        ForEach(Self.lengths, id: \.self) { minutes in
                            Button(Self.lengthLabel(minutes)) { minMinutes = minutes }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            PIcon("clock", size: 18, color: .textFaint)
                            Text(Self.lengthLabel(minMinutes)).textStyle(.body, color: .textStrong)
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

                    if let errorText {
                        Text(errorText).textStyle(.footnote, color: .statusDanger)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        PIcon("eye-off", size: 16, color: .textFaint)
                        Text("Change who this can match with, and how many people it takes, under You → Quiet plans.")
                            .textStyle(.caption, color: .textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }

            VStack(spacing: 0) {
                Divider().overlay(Color.hairline)
                PlannitButton(title: saving ? "Saving…" : "Keep it quiet",
                              variant: .primary, size: .lg, icon: "moon", fullWidth: true) {
                    save()
                }
                .disabled(saving || chosenGroup == nil)
                .opacity(saving || chosenGroup == nil ? 0.5 : 1)
                .padding(Space.gutter)
            }
            .barSurface()
        }
        .background(Color.appBg)
        .presentationDetents([.large])
        .onChange(of: start) { _, newStart in
            if end <= newStart { end = newStart.addingTimeInterval(3600) }
        }
    }

    private var calloutCard: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(GroupHue.indigo.soft).frame(width: 40, height: 40)
                .overlay(PIcon("moon", size: 20, color: GroupHue.indigo.color, weight: .semibold))
            Text("Nobody is told about this. If enough of the group quietly says they're free at the same time, it turns into a plan and everyone hears about it at once.")
                .textStyle(.footnote, color: .textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GroupHue.indigo.soft.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    @ViewBuilder
    private var groupPicker: some View {
        if model.groups.isEmpty {
            Text("A quiet plan goes to one group, and you're not in one yet.")
                .textStyle(.footnote, color: .textMuted)
        } else {
            Menu {
                ForEach(model.groups) { g in
                    Button(g.name) { chosenGroup = g }
                }
            } label: {
                HStack(spacing: 10) {
                    PIcon("users", size: 18, color: .textFaint)
                    Text(chosenGroup?.name ?? "Choose a group")
                        .textStyle(.body, color: chosenGroup == nil ? .textMuted : .textStrong)
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
        }
    }

    private var windowCard: some View {
        VStack(spacing: 0) {
            DatePicker("From", selection: $start, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .tint(.actionPrimary)
                .textStyle(.body, color: .textStrong)
                .padding(.vertical, 4)
            Divider().overlay(Color.hairline)
            DatePicker("Until", selection: $end, in: start...,
                       displayedComponents: [.date, .hourAndMinute])
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
    }

    private static func lengthLabel(_ minutes: Int) -> String {
        switch minutes {
        case 30:  return "Half an hour together"
        case 60:  return "An hour together"
        case 90:  return "An hour and a half"
        case 120: return "Two hours together"
        default:  return "\(minutes / 60) hours together"
        }
    }

    private func save() {
        guard let chosenGroup else { return }
        // The window has to be able to hold the overlap being asked for, or it
        // can never match anything.
        guard end.timeIntervalSince(start) >= Double(minMinutes) * 60 else {
            errorText = "That window is shorter than the time you're asking for."
            return
        }
        saving = true
        errorText = nil
        let name = title.trimmingCharacters(in: .whitespaces)
        Task {
            let ok = await model.createQuietPlan(group: chosenGroup, start: start, end: end,
                                                 title: name, minMinutes: minMinutes)
            saving = false
            if ok { dismiss() } else { errorText = "Couldn't save that. Try again." }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased()).textStyle(.overline, color: .textFaint)
    }
}
