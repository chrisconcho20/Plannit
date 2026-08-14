import SwiftUI

// NewPlanSheet — the date-finder (the wedge). Pick a group, describe a
// plain-language constraint ("a weekend afternoon"), let Plannit check
// everyone's availability, then send ranked slots to the group to vote.
// Mirrors the ＋ flow in ui_kits/plannit-ios/PlansScreen.jsx.

struct NewPlanSheet: View {
    var groups: [PGroup] = Sample.groups
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
    @State private var sending = false
    @State private var slots: [PSlot] = []
    @State private var errorText: String?

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    init(groups: [PGroup] = Sample.groups, preselected: PGroup? = nil,
         onFound: @escaping (String, String) -> Void) {
        self.groups = groups
        self.preselected = preselected
        self.onFound = onFound
        _group = State(initialValue: preselected)
        _step = State(initialValue: preselected == nil ? 0 : 1)
    }

    private var total: Int { group?.members.count ?? 0 }
    private var isLive: Bool { Config.isLiveBackend }

    /// Demo-mode stand-in for the scheduler's output.
    private var sampleSlots: [PSlot] {
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
            ForEach(groups) { g in
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
            } else if let errorText {
                EmptyState(icon: "circle-alert", title: "Couldn’t check calendars",
                           message: errorText, actionTitle: "Try again") { findTimes() }
                    .frame(maxWidth: .infinity)
            } else if slots.isEmpty {
                EmptyState(icon: "calendar-x", title: "No times work",
                           message: "Nobody’s free for \(duration) \(timeOfDay.lowercased()) in the next \(SlotFinder.searchWeeks) weeks. Try more days or a shorter plan.",
                           actionTitle: "Change the plan") {
                    withAnimation(Motion.base) { step = 1 }
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 8) {
                    PIcon("circle-check", size: 18, color: .statusFree)
                    Text(constraintSummary).textStyle(.footnote, color: .textMuted)
                }
                ForEach(slots) { slot in
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
                    findTimes()
                }
                .disabled(days.isEmpty).opacity(days.isEmpty ? 0.5 : 1)
                .padding(Space.gutter)
            default:
                PlannitButton(title: sending ? "Sending…" : "Send to group to vote",
                              variant: .primary, size: .lg, icon: "send", fullWidth: true) {
                    send()
                }
                .disabled(sendDisabled).opacity(sendDisabled ? 0.5 : 1)
                .padding(Space.gutter)
            }
        }
        .background(.ultraThinMaterial)
    }

    private var sendDisabled: Bool { finding || sending || slots.isEmpty }

    // MARK: Actions

    /// Run the scheduler. Live mode previews real slots (`persist: false`) so an
    /// abandoned sheet never leaves an orphan proposal behind; the proposal is
    /// written only when the user sends it to the group.
    private func findTimes() {
        errorText = nil
        withAnimation(Motion.base) { step = 2; finding = true }

        guard isLive, let selected = group else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                slots = sampleSlots
                withAnimation(Motion.base) { finding = false }
            }
            return
        }

        Task {
            do {
                let res = try await invokeFindSlots(group: selected, persist: false)
                slots = res.slots.enumerated().map { i, dto in
                    SlotFinder.slot(from: dto, best: i == 0)
                }
            } catch {
                slots = []
                errorText = Self.message(for: error)
            }
            withAnimation(Motion.base) { finding = false }
        }
    }

    /// Persist the proposal so the group can vote on it.
    private func send() {
        guard isLive, let selected = group else {
            onFound(planTitle, group?.name ?? "your group")
            dismiss()
            return
        }

        sending = true
        Task {
            do {
                _ = try await invokeFindSlots(group: selected, persist: true)
                sending = false
                onFound(planTitle, selected.name)
                dismiss()
            } catch {
                sending = false
                errorText = Self.message(for: error)
            }
        }
    }

    @MainActor
    private func invokeFindSlots(group: PGroup, persist: Bool) async throws -> FindSlotsResponse {
        let body = FindSlotsRequest(
            groupId: group.id,
            title: planTitle,
            constraints: SlotFinder.constraints(days: days, timeOfDay: timeOfDay,
                                                duration: duration,
                                                memberCount: group.members.count),
            maxResults: SlotFinder.maxResults,
            persist: persist)
        return try await SupabaseClient.shared.invokeFunction("find-slots", body: body)
    }

    private var planTitle: String { title.isEmpty ? "New plan" : title }

    private static func message(for error: Error) -> String {
        guard let e = error as? SupabaseError else {
            return "Couldn’t reach Plannit. Check your connection and try again."
        }
        switch e {
        case .notConfigured:
            return "You’re signed out — sign in and try again."
        case .decoding:
            return "Plannit sent something we couldn’t read. Try again."
        case .http(let code, _):
            switch code {
            case 401: return "Your session expired — sign in and try again."
            case 403: return "You’re not a member of that group any more."
            default:  return "The scheduler failed (\(code)). Try again in a moment."
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased()).textStyle(.overline, color: .textFaint)
    }
}
