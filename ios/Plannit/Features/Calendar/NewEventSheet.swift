import SwiftUI

// NewEventSheet — put something on your own calendar. In live mode this writes
// a row to `events` (owner_id = you, source = plannit); in demo mode it just
// appends locally. Sharing it with a group is a separate, deliberate step —
// events are private until you say otherwise.

struct NewEventSheet: View {
    var date: Date = Date()

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var location = ""
    @State private var start = Date()
    @State private var duration = "1h"
    @State private var saving = false
    @State private var errorText: String?

    private let durations = ["30m", "1h", "2h", "3h"]

    init(date: Date = Date()) {
        self.date = date
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
            SheetHeader(title: "New event") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    fieldLabel("What")
                    PTextField(placeholder: "e.g. Five-a-side", text: $title, icon: "sparkles")

                    fieldLabel("When")
                    VStack(spacing: 0) {
                        DatePicker("Starts", selection: $start)
                            .datePickerStyle(.compact)
                            .tint(.actionPrimary)
                            .textStyle(.body, color: .textStrong)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .strokeBorder(Color.lineStrong, lineWidth: 1))

                    fieldLabel("How long")
                    HStack(spacing: 8) {
                        ForEach(durations, id: \.self) { d in
                            SelectableChip(label: d, selected: duration == d) {
                                withAnimation(Motion.fast) { duration = d }
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

                    HStack(spacing: 8) {
                        PIcon("lock", size: 16, color: .textFaint)
                        Text("Only you can see this until you share it with a group.")
                            .textStyle(.caption, color: .textMuted)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 4)
            }

            VStack(spacing: 0) {
                Divider().overlay(Color.hairline)
                PlannitButton(title: saving ? "Saving…" : "Add to calendar",
                              variant: .primary, size: .lg, icon: "calendar-plus", fullWidth: true) {
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
        Task {
            let ok = await model.createEvent(
                title: title.trimmingCharacters(in: .whitespaces),
                start: start,
                minutes: Self.minutes(duration),
                location: location.trimmingCharacters(in: .whitespaces))
            saving = false
            if ok { dismiss() } else { errorText = "Couldn’t save that. Check your connection and try again." }
        }
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
