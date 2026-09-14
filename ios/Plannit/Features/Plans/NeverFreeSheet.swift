import SwiftUI

// NeverFreeSheet — hours and days the date finder should treat you as busy,
// whatever your calendar says. Saved on the phone; applied the next time
// availability syncs, which saving triggers straight away.

struct NeverFreeSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var rule = NeverFreeHours.current

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let dayNames = Calendar.current.weekdaySymbols

    /// Half-hour steps. Earliest can't be midnight-at-the-end; latest can't be
    /// midnight-at-the-start — each keeps the other's end of the day.
    private var earliestOptions: [Int] {
        Array(stride(from: 0, to: NeverFreeHours.dayMinutes, by: NeverFreeHours.step))
    }
    private var latestOptions: [Int] {
        Array(stride(from: rule.earliestMinutes + NeverFreeHours.step,
                     through: NeverFreeHours.dayMinutes, by: NeverFreeHours.step))
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Hours you're never free") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Toggle(isOn: $rule.enabled.animation(Motion.fast)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use these hours").textStyle(.headline, color: .textStrong)
                            Text("The date finder won't suggest times outside them.")
                                .textStyle(.caption, color: .textMuted)
                        }
                    }
                    .tint(.actionPrimary)

                    if rule.enabled {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("FREE BETWEEN").textStyle(.overline, color: .textFaint)
                            HStack(spacing: 10) {
                                timeMenu(selection: $rule.earliestMinutes, options: earliestOptions)
                                Text("and").textStyle(.subhead, color: .textMuted)
                                timeMenu(selection: $rule.latestMinutes, options: latestOptions)
                                Spacer(minLength: 0)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("NEVER FREE ON").textStyle(.overline, color: .textFaint)
                            HStack(spacing: 6) {
                                ForEach(0..<7, id: \.self) { day in
                                    dayChip(day)
                                }
                            }
                        }

                        Text(rule.summary).textStyle(.footnote, color: .textMuted)
                    }

                    Text("Your groups only see that you're busy at those times — never why.")
                        .textStyle(.caption, color: .textFaint)
                    if !model.calendarConnected {
                        Text("Connect your calendar in You for these hours to reach your groups.")
                            .textStyle(.caption, color: .statusWarning)
                    }
                }
                .padding(Space.gutter)
            }
            PlannitButton(title: "Save", variant: .primary, size: .lg, fullWidth: true) {
                model.setNeverFreeHours(rule)
                dismiss()
            }
            .disabled(rule == NeverFreeHours.current)
            .opacity(rule == NeverFreeHours.current ? 0.5 : 1)
            .padding(Space.gutter)
        }
        .background(Color.appBg)
        .presentationDetents([.large])
        // Moving "free from" past "free until" would leave no free time at all;
        // push the end along instead of refusing the change.
        .onChange(of: rule.earliestMinutes) { _, earliest in
            if rule.latestMinutes <= earliest {
                rule.latestMinutes = min(earliest + NeverFreeHours.step, NeverFreeHours.dayMinutes)
            }
        }
    }

    private func timeMenu(selection: Binding<Int>, options: [Int]) -> some View {
        Menu {
            Picker("Time", selection: selection) {
                ForEach(options, id: \.self) { Text(NeverFreeHours.label($0)).tag($0) }
            }
        } label: {
            Text(NeverFreeHours.label(selection.wrappedValue))
                .textStyle(.headline, color: .textStrong)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(Color.lineStrong, lineWidth: 1))
        }
    }

    private func dayChip(_ day: Int) -> some View {
        let blocked = rule.blockedWeekdays.contains(day)
        return Text(dayLabels[day])
            .textStyle(.subhead, color: blocked ? .textOnPrimary : .textBody)
            .frame(width: 40, height: 40)
            .background(blocked ? Color.actionPrimary : Color.sunk)
            .clipShape(Circle())
            .contentShape(Circle())
            .onTapGesture {
                withAnimation(Motion.fast) {
                    if blocked { rule.blockedWeekdays.remove(day) } else { rule.blockedWeekdays.insert(day) }
                }
            }
            .accessibilityLabel("\(dayNames[day])\(blocked ? ", never free" : "")")
            .accessibilityAddTraits(blocked ? [.isButton, .isSelected] : .isButton)
    }
}
