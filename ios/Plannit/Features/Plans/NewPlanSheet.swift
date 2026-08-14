import SwiftUI

// NewPlanSheet — the date-finder (the wedge). Pick a group, describe a
// plain-language constraint ("a weekend afternoon"), let Plannit check
// everyone's availability, then send ranked slots to the group to vote.
// Mirrors the ＋ flow in ui_kits/plannit-ios/PlansScreen.jsx.

struct NewPlanSheet: View {
    var preselected: PGroup? = nil
    var onFound: (_ name: String, _ group: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step = 0                    // 0 group · 1 constraint · 2 results
    @State private var group: PGroup?
    @State private var title = ""
    @State private var days: Set<Int> = [6, 0]     // Sat, Sun (0=Sun … 6=Sat)
    @State private var timeOfDay = "Afternoon"
    @State private var duration = "2h"
    @State private var finding = false

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    init(preselected: PGroup? = nil, onFound: @escaping (String, String) -> Void) {
        self.preselected = preselected
        self.onFound = onFound
        _group = State(initialValue: preselected)
        _step = State(initialValue: preselected == nil ? 0 : 1)
    }

    private var total: Int { group?.members.count ?? 0 }

    private var foundSlots: [PSlot] {
        [PSlot(day: "SAT", date: 16, time: "2:00 – 4:00 PM", free: total, best: true),
         PSlot(day: "SUN", date: 17, time: "11:00 AM – 1:00 PM", free: max(0, total - 1)),
         PSlot(day: "SAT", date: 23, time: "3:00 – 5:00 PM", free: max(0, total - 1))]
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: stepTitle) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch step {
                    case 0: groupStep
                    case 1: constraintStep
                    default: resultsStep
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 4)
            }
            footer
        }
        .background(Color.appBg)
        .presentationDetents([.large])
    }

    private var stepTitle: String {
        switch step { case 0: return "Pick a group"; case 1: return "What are you planning?"; default: return "Found some times" }
    }

    // MARK: Step 0 — group
    private var groupStep: some View {
        VStack(spacing: Space.gapList) {
            ForEach(Sample.groups) { g in
                Button { withAnimation(Motion.fast) { group = g } } label: {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(g.hue.color).frame(width: 44, height: 44)
                            .overlay(PIcon("users", size: 20, color: .white))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.name).textStyle(.headline, color: .textStrong)
                            Text("\(g.members.count) people").textStyle(.footnote, color: .textMuted)
                        }
                        Spacer()
                        PIcon(group?.id == g.id ? "circle-check" : "circle", size: 22,
                              color: group?.id == g.id ? .actionPrimary : .textFaint)
                    }
                    .padding(Space.card)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(group?.id == g.id ? Color.actionPrimary : Color.hairline,
                                      lineWidth: group?.id == g.id ? 2 : 1))
                }
                .buttonStyle(CardPressStyle())
            }
        }
    }

    // MARK: Step 1 — constraint
    private var constraintStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            fieldLabel("Name (optional)")
            PTextField(placeholder: "e.g. Five-a-side", text: $title, icon: "sparkles")

            fieldLabel("Which days")
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let on = days.contains(i)
                    Text(dayLabels[i])
                        .textStyle(.subhead, color: on ? .textOnPrimary : .textBody)
                        .frame(width: 40, height: 40)
                        .background(on ? Color.actionPrimary : Color.sunk)
                        .clipShape(Circle())
                        .contentShape(Circle())
                        .onTapGesture {
                            withAnimation(Motion.fast) {
                                if on { _ = days.remove(i) } else { _ = days.insert(i) }
                            }
                        }
                }
            }

            fieldLabel("Time of day")
            SegmentedControl(options: ["Morning", "Afternoon", "Evening"], selection: $timeOfDay) { $0 }

            fieldLabel("How long")
            HStack(spacing: 8) {
                ForEach(["1h", "2h", "3h", "4h"], id: \.self) { d in
                    SelectableChip(label: d, selected: duration == d) {
                        withAnimation(Motion.fast) { duration = d }
                    }
                }
            }

            // Plain-language echo of the constraint.
            HStack(spacing: 8) {
                PIcon("wand-sparkles", size: 16, color: Palette.teal600)
                Text(constraintSummary).textStyle(.footnote, color: Palette.teal700)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.teal50)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }

    private var constraintSummary: String {
        let d = days.sorted().map { dayNames[$0] }.joined(separator: ", ")
        return "\(group?.name ?? "Group") · \(d.isEmpty ? "any day" : d) · \(timeOfDay.lowercased()) · \(duration)"
    }

    // MARK: Step 2 — results
    private var resultsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if finding {
                VStack(spacing: 14) {
                    PIcon("hourglass", size: 30, color: .statusFree)
                    Text("Checking everyone’s calendars…").textStyle(.headline, color: .textStrong)
                    AvatarStack(names: group?.members ?? [], size: 30, max: 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                HStack(spacing: 8) {
                    PIcon("circle-check", size: 18, color: .statusFree)
                    Text(constraintSummary).textStyle(.footnote, color: .textMuted)
                }
                ForEach(foundSlots) { slot in
                    SlotCard(day: slot.day, date: slot.date, time: slot.time,
                             freeCount: slot.free, total: total,
                             people: Array((group?.members ?? []).prefix(slot.free)),
                             best: slot.best)
                }
            }
        }
    }

    // MARK: Footer
    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.hairline)
            switch step {
            case 0:
                PlannitButton(title: "Next", variant: .primary, size: .lg, fullWidth: true) {
                    withAnimation(Motion.base) { step = 1 }
                }
                .disabled(group == nil).opacity(group == nil ? 0.5 : 1)
                .padding(Space.gutter)
            case 1:
                PlannitButton(title: "Find times", variant: .free, size: .lg, icon: "wand-sparkles", fullWidth: true) {
                    withAnimation(Motion.base) { step = 2; finding = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        withAnimation(Motion.base) { finding = false }
                    }
                }
                .disabled(days.isEmpty).opacity(days.isEmpty ? 0.5 : 1)
                .padding(Space.gutter)
            default:
                PlannitButton(title: "Send to group to vote", variant: .primary, size: .lg,
                              icon: "send", fullWidth: true) {
                    onFound(title.isEmpty ? "New plan" : title, group?.name ?? "your group")
                    dismiss()
                }
                .disabled(finding).opacity(finding ? 0.5 : 1)
                .padding(Space.gutter)
            }
        }
        .background(.ultraThinMaterial)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased()).textStyle(.overline, color: .textFaint)
    }
}
