import SwiftUI

// Moving a group plan you organised.
//
// Separate from the ordinary event editor on purpose: changing a plan's time
// isn't editing a field, it's changing what several people already agreed to.
// The one thing this screen owes them is that the consequence is stated
// *before* the tap, and that the sentence matches what the database will
// actually do (`reschedule_event`, migration 0014).
//
// The rule: a different time on the same day keeps everyone's answers; a
// different day asks them again. See `AppModel.resetsAnswers(movingFrom:to:)`.

struct RescheduleSheet: View {
    let event: PEvent

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date
    @State private var saving = false
    @State private var errorText: String?

    init(event: PEvent) {
        self.event = event
        _start = State(initialValue: event.start)
        _end = State(initialValue: event.end ?? event.start.addingTimeInterval(3600))
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Move this plan") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 10) {
                        Circle().fill(event.hue.color).frame(width: 8, height: 8)
                        Text(event.title).textStyle(.headline, color: .textStrong)
                    }

                    fieldLabel("Starts")
                    DatePicker("", selection: $start).labelsHidden()
                        .datePickerStyle(.compact)
                        .onChange(of: start) { old, new in
                            // Drag the end along so the plan keeps its length.
                            end = end.addingTimeInterval(new.timeIntervalSince(old))
                        }

                    fieldLabel("Ends")
                    DatePicker("", selection: $end, in: start...).labelsHidden()
                        .datePickerStyle(.compact)

                    consequence

                    if let errorText {
                        Text(errorText).textStyle(.footnote, color: .statusDanger)
                    }
                }
                .padding(Space.gutter)
            }
            footer
        }
        .background(Color.appBg)
        .presentationDetents([.medium, .large])
    }

    /// The whole point of the screen: say what this does to the people who
    /// already answered, before it happens.
    private var consequence: some View {
        let resets = AppModel.resetsAnswers(movingFrom: event.start, to: start)
        let going = max(0, event.goingCount - 1)   // you don't re-answer your own plan
        return HStack(alignment: .top, spacing: 8) {
            PIcon(resets ? "circle-alert" : "circle-check", size: 16,
                  color: resets ? .statusWarning : .statusFree)
            VStack(alignment: .leading, spacing: 3) {
                Text(resets ? "A different day, so everyone will be asked again"
                            : "Same day — nobody has to answer again")
                    .textStyle(.footnote, color: resets ? Palette.ink700 : Palette.teal700)
                Text(detail(resets: resets, going: going))
                    .textStyle(.caption, color: .textMuted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(resets ? Palette.ink50 : Palette.teal50)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private func detail(resets: Bool, going: Int) -> String {
        guard going > 0 else {
            return resets
                ? "Nobody else has said yes yet, so there's nothing to undo."
                : "Nobody else has said yes yet."
        }
        let people = going == 1 ? "1 person" : "\(going) people"
        return resets
            ? "\(people) said yes to the old day. It comes off their calendar and "
              + "they'll see the new invitation."
            : "\(people) stay going, and the new time lands on their calendar."
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.hairline)
            PlannitButton(title: saving ? "Moving…" : "Move it", variant: .primary,
                          size: .lg, icon: "calendar-check", fullWidth: true) { save() }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
                .padding(Space.gutter)
        }
        .barSurface()
    }

    private var canSave: Bool {
        !saving && abs(start.timeIntervalSince(event.start)) > 1
    }

    private func save() {
        saving = true
        errorText = nil
        Task {
            let ok = await model.reschedule(event, to: start, end: end)
            saving = false
            if ok { dismiss() } else { errorText = "Couldn’t move that plan. Try again." }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased()).textStyle(.overline, color: .textFaint)
    }
}
