import SwiftUI

// NewPlanSheet — the date-finder (the wedge). Pick a group, describe a
// plain-language constraint ("a weekend afternoon"), let Plannit check
// everyone's availability, then pick one of the dates it found and send *that*
// to the group (decision D-12, revised): the group answers going or not going,
// it doesn't vote between times. Whoever picks the time is going by definition.
// Mirrors the ＋ flow in ui_kits/plannit-ios/PlansScreen.jsx.

struct NewPlanSheet: View {
    var groups: [PGroup] = Sample.groups
    var preselected: PGroup? = nil
    var onFound: (_ name: String, _ group: String) -> Void

    @EnvironmentObject private var model: AppModel
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
    @State private var chosen: PSlot?
    @State private var everyoneFree = true
    @State private var errorText: String?
    @AppStorage(SearchWindow.key) private var searchMonths = SearchWindow.defaultMonths

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

    /// Demo-mode stand-in for the scheduler's output: this weekend and the
    /// next, with real instants so picking one still produces a real event.
    private var sampleSlots: [PSlot] {
        let cal = Calendar.current
        let hours = max(1, SlotFinder.minutes(from: duration) / 60)
        let saturday = cal.nextDate(after: Date(),
                                    matching: DateComponents(hour: 14, weekday: 7),
                                    matchingPolicy: .nextTime) ?? Date()
        let starts = [saturday,
                      cal.date(byAdding: .hour, value: 3, to: saturday) ?? saturday,
                      cal.date(byAdding: .day, value: 1, to: saturday) ?? saturday,
                      cal.date(byAdding: .day, value: 7, to: saturday) ?? saturday]
        return starts.enumerated().map { i, start in
            let end = cal.date(byAdding: .hour, value: hours, to: start) ?? start
            return SlotFinder.slot(
                from: FoundSlotDTO(start: Int64(start.timeIntervalSince1970 * 1000),
                                   end: Int64(end.timeIntervalSince1970 * 1000),
                                   score: i == 0 ? total : max(0, total - 1),
                                   availableUserIds: []),
                best: i == 0)
        }
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
        switch step { case 0: return "Pick a group"; case 1: return "What are you planning?"; default: return "Pick a date" }
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

            // Plain-language echo of the constraint, and the promise behind it.
            HStack(alignment: .top, spacing: 8) {
                PIcon("wand-sparkles", size: 16, color: Palette.teal600)
                VStack(alignment: .leading, spacing: 3) {
                    Text(constraintSummary).textStyle(.footnote, color: Palette.teal700)
                    Text("Searching \(SearchWindow.phrase(searchMonths)) for a time everyone can make.")
                        .textStyle(.caption, color: Palette.teal600)
                }
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
                    AvatarStack(names: group?.memberNames ?? [], size: 30, max: 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else if let errorText {
                EmptyState(icon: "circle-alert", title: "Couldn’t check calendars",
                           message: errorText, actionTitle: "Try again") { findTimes() }
                    .frame(maxWidth: .infinity)
            } else if slots.isEmpty {
                EmptyState(icon: "calendar-x", title: "No times work",
                           message: "Not enough of the group is free for \(duration) \(timeOfDay.lowercased()) in \(SearchWindow.phrase(searchMonths)). Try more days, a shorter plan, or a longer window in You → Date finder.",
                           actionTitle: "Change the plan") {
                    withAnimation(Motion.base) { step = 1 }
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 8) {
                    PIcon(everyoneFree ? "circle-check" : "circle-alert", size: 18,
                          color: everyoneFree ? .statusFree : .statusWarning)
                    Text(everyoneFree
                         ? constraintSummary
                         : "No time works for all \(total) in \(SearchWindow.phrase(searchMonths)) — here’s the best turnout.")
                        .textStyle(.footnote, color: .textMuted)
                }
                // One decision to make: which date. At most two times per
                // date — five slots on the same afternoon is a menu, not a
                // choice.
                ForEach(dates, id: \.date) { day in
                    VStack(alignment: .leading, spacing: Space.gapList) {
                        Text(dayHeading(day.date)).textStyle(.overline, color: .textFaint)
                        ForEach(day.slots) { slot in
                            Button { withAnimation(Motion.fast) { chosen = slot } } label: {
                                SlotCard(day: slot.day, date: slot.date, time: slot.time,
                                         freeCount: slot.free, total: total,
                                         people: people(for: slot),
                                         best: slot.best,
                                         selected: chosen?.id == slot.id)
                            }
                            .buttonStyle(CardPressStyle())
                        }
                    }
                }
            }
        }
    }

    private var dates: [(date: Date, slots: [PSlot])] { SlotFinder.byDate(slots) }

    /// "SATURDAY 16 AUGUST" — the year only when it isn't this one.
    private func dayHeading(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "EEEE d MMMM" : "EEEE d MMMM yyyy"
        return f.string(from: date).uppercased()
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
                PlannitButton(title: sending ? "Sending…" : sendTitle,
                              variant: .primary, size: .lg, icon: "send", fullWidth: true) {
                    send()
                }
                .disabled(sendDisabled).opacity(sendDisabled ? 0.5 : 1)
                .padding(Space.gutter)
            }
        }
        .background(.ultraThinMaterial)
    }

    private var sendDisabled: Bool { finding || sending || chosen == nil }

    /// Name the date you're about to commit to — "Send Sat 16 to the group".
    private var sendTitle: String {
        guard let start = chosen?.startsAt else { return "Pick a date" }
        let f = DateFormatter(); f.dateFormat = "EEE d"
        return "Send \(f.string(from: start)) to the group"
    }

    /// The members actually free then — the scheduler tells us who, so show
    /// their faces rather than the first N people in the group.
    private func people(for slot: PSlot) -> [String] {
        guard let group else { return [] }
        guard !slot.availableIds.isEmpty else {
            return Array(group.memberNames.prefix(slot.free))     // demo fallback
        }
        return group.members.filter { slot.availableIds.contains($0.id) }.map(\.name)
    }

    // MARK: Actions

    /// Run the scheduler. Nothing is persisted here (`persist: false`) — the
    /// search is a preview, and the only thing that outlives this sheet is the
    /// one date you pick.
    private func findTimes() {
        errorText = nil
        withAnimation(Motion.base) { step = 2; finding = true }

        guard isLive, let selected = group else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                slots = sampleSlots
                chosen = slots.first
                everyoneFree = true
                withAnimation(Motion.base) { finding = false }
            }
            return
        }

        Task {
            do {
                let res = try await invokeFindSlots(group: selected, persist: false)
                everyoneFree = res.everyoneFree ?? true
                slots = res.slots.enumerated().map { i, dto in
                    SlotFinder.slot(from: dto, best: i == 0)
                }
                chosen = dates.first?.slots.first
            } catch {
                slots = []
                errorText = Self.message(for: error)
            }
            withAnimation(Motion.base) { finding = false }
        }
    }

    /// Turn the picked slot into a real group event. You're going — picking the
    /// time is what said so — and everyone else gets an invitation to answer.
    private func send() {
        guard let selected = group, let slot = chosen,
              let start = slot.startsAt, let end = slot.endsAt else { return }

        sending = true
        Task {
            let ok = await model.proposeGroupEvent(title: planTitle, start: start,
                                                   end: end, to: selected)
            sending = false
            guard ok else {
                errorText = "Couldn’t send that to the group. Try again."
                return
            }
            onFound(planTitle, selected.name)
            dismiss()
        }
    }

    @MainActor
    private func invokeFindSlots(group: PGroup, persist: Bool) async throws -> FindSlotsResponse {
        let body = FindSlotsRequest(
            groupId: group.id,
            title: planTitle,
            constraints: SlotFinder.constraints(days: days, timeOfDay: timeOfDay,
                                                duration: duration, months: searchMonths),
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
