import SwiftUI

// Calendar tab — Month / Week / List, a month grid with hue marks, and the
// day's events. Mirrors ui_kits/plannit-ios/CalendarScreen.jsx.

struct CalendarScreen: View {
    enum Mode: String, CaseIterable { case month = "Month", week = "Week", list = "List" }

    @EnvironmentObject private var model: AppModel
    @State private var mode: Mode = .month
    @State private var visibleMonth = Date()          // any day inside the shown month
    @State private var selectedDay: Int? = Calendar.current.component(.day, from: Date())
    @State private var showNewEvent = false

    private let cal = Calendar.current

    private static let clock: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    private var year: Int { cal.component(.year, from: visibleMonth) }
    private var month: Int { cal.component(.month, from: visibleMonth) }

    /// The day-of-month to ring as "today", but only while that month is shown.
    private var todayInMonth: Int? {
        cal.isDate(visibleMonth, equalTo: Date(), toGranularity: .month)
            ? cal.component(.day, from: Date()) : nil
    }

    private var selectedDate: Date? {
        guard let selectedDay else { return nil }
        return cal.date(from: DateComponents(year: year, month: month, day: selectedDay))
    }

    /// The month on screen, as a range — repeating events are expanded into it.
    private var monthRange: ClosedRange<Date>? {
        guard let interval = cal.dateInterval(of: .month, for: visibleMonth) else { return nil }
        return interval.start...interval.end
    }

    /// Every occurrence in the shown month: a weekly five-a-side is four dots,
    /// not one.
    private var monthOccurrences: [PEvent] {
        guard let monthRange else { return [] }
        return calendarEvents.flatMap { $0.occurrences(in: monthRange) }
    }

    /// What belongs on *your* calendar. A group plan you haven't answered is an
    /// invitation, not a commitment — it lives in Plans until you say yes.
    private var calendarEvents: [PEvent] {
        model.events.filter { $0.isOnCalendar(for: model.userId) }
    }

    /// Events in the shown month, grouped by day — the source of the grid's dots.
    /// Derived from real events, so a day only gets a mark if something is on it.
    private var marks: [Int: [Color]] {
        var out: [Int: [Color]] = [:]
        for event in monthOccurrences {
            out[event.day, default: []].append(event.hue.color)
        }
        for device in model.deviceEvents
        where cal.isDate(device.start, equalTo: visibleMonth, toGranularity: .month) {
            out[cal.component(.day, from: device.start), default: []].append(GroupHue.coral.color)
        }
        return out
    }

    private var events: [PEvent] {
        if mode != .list, let selectedDate {
            let day = cal.startOfDay(for: selectedDate)
            let end = cal.date(byAdding: .day, value: 1, to: day) ?? day
            return calendarEvents.flatMap { $0.occurrences(in: day...end) }
                .filter { $0.isOn(selectedDate) }
                .sorted { $0.start < $1.start }
        }
        // Upcoming: a repeating event should appear on each of its next dates,
        // not once forever at its original start.
        let now = cal.startOfDay(for: Date())
        let horizon = cal.date(byAdding: .month, value: 3, to: now) ?? now
        return calendarEvents.flatMap { $0.occurrences(in: now...horizon) }
            .sorted { $0.start < $1.start }
    }

    /// Your own calendar's events, scoped exactly like the Plannit ones above:
    /// the selected day, or everything upcoming in List mode. Unfiltered, this
    /// dumped every day under whichever day you'd tapped — invisible on an
    /// empty simulator, a wall of text on a real phone.
    private var deviceEvents: [DeviceEvent] {
        let all = model.deviceEvents.sorted { $0.start < $1.start }
        if mode != .list, let selectedDate {
            return all.filter { cal.isDate($0.start, inSameDayAs: selectedDate) }
        }
        return all.filter { $0.start >= cal.startOfDay(for: Date()) }
    }

    /// A day is one list, in time order. Two stacked sections — Plannit's plans
    /// above, "also on your calendar" below — made a 9am dentist appointment
    /// sort after an 8pm film night, which is the exact split Plannit exists to
    /// remove. The source stays legible in the row itself, not in the layout.
    private enum Row: Identifiable {
        case plan(PEvent)
        case device(DeviceEvent)

        var id: String {
            switch self {
            case .plan(let e):   return "p-\(e.id)"
            case .device(let d): return "d-\(d.id)"
            }
        }
        var start: Date {
            switch self {
            case .plan(let e):   return e.start
            case .device(let d): return d.start
            }
        }
        /// All-day things lead the day, the way every calendar app shows them.
        var isAllDay: Bool {
            switch self {
            case .plan(let e):   return e.isAllDay
            case .device(let d): return d.isAllDay
            }
        }
    }

    private var rows: [Row] {
        (events.map(Row.plan) + deviceEvents.map(Row.device))
            .sorted { a, b in
                if a.isAllDay != b.isAllDay { return a.isAllDay }
                return a.start < b.start
            }
    }

    /// In Month and Week you already know the day you're looking at, so the time
    /// alone is enough. A flat upcoming list doesn't tell you that, so the date
    /// leads.
    private func timeLabel(for event: PEvent) -> String {
        guard mode == .list else { return event.time }
        let f = DateFormatter()
        f.dateFormat = cal.isDate(event.start, equalTo: Date(), toGranularity: .year)
            ? "EEE d MMM" : "EEE d MMM yyyy"
        return "\(f.string(from: event.start)) · \(event.time)"
    }

    /// Same rule as `timeLabel(for:)`: in Month and Week you already know the
    /// day, so the time alone is enough; a flat upcoming list needs the date.
    private func deviceTimeLabel(for device: DeviceEvent) -> String {
        let time = device.isAllDay ? "All day" : Self.clock.string(from: device.start)
        guard mode == .list else { return time }
        let f = DateFormatter()
        f.dateFormat = cal.isDate(device.start, equalTo: Date(), toGranularity: .year)
            ? "EEE d MMM" : "EEE d MMM yyyy"
        return "\(f.string(from: device.start)) · \(time)"
    }

    /// Read far enough ahead to cover the month on screen, plus a little.
    private func widenWindowIfNeeded() {
        guard let interval = cal.dateInterval(of: .month, for: visibleMonth) else { return }
        model.ensureDeviceEvents(through: interval.end)
    }

    private var sectionTitle: String {
        if mode != .list, let selectedDate {
            let f = DateFormatter(); f.dateFormat = "EEEE d MMMM"
            return f.string(from: selectedDate)
        }
        return "Upcoming"
    }

    private var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: visibleMonth)
    }

    private func stepMonth(_ delta: Int) {
        guard let next = cal.date(byAdding: .month, value: delta, to: visibleMonth) else { return }
        withAnimation(Motion.fast) {
            visibleMonth = next
            // Keep "today" selected when we land back on the current month.
            selectedDay = cal.isDate(next, equalTo: Date(), toGranularity: .month)
                ? cal.component(.day, from: Date()) : nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    if let error = model.loadError {
                        LoadBanner(message: error) { Task { await model.loadData() } }
                    }
                    if mode == .month {
                        PlannitCard(elevation: 1) {
                            VStack(spacing: 8) {
                                monthBar
                                MonthGrid(year: year, month: month, marks: marks,
                                          today: todayInMonth, selected: $selectedDay)
                            }
                        }
                        .padding(.horizontal, Space.gutter)
                        .padding(.top, 4)
                    } else if mode == .week {
                        PlannitCard(elevation: 1) { weekStrip }
                            .padding(.horizontal, Space.gutter)
                            .padding(.top, 4)
                    }

                    SectionLabel(sectionTitle)

                    LazyVStack(spacing: Space.gapList) {
                        ForEach(rows) { row in
                            switch row {
                            case .plan(let event):
                                NavigationLink(value: event) {
                                    EventCard(title: event.title, time: timeLabel(for: event),
                                              location: event.location,
                                              hue: event.hue, group: event.group, people: event.people,
                                              icon: event.icon, badge: event.badge,
                                              badgeTone: event.badgeTone)
                                }
                                .buttonStyle(CardPressStyle())
                            case .device(let device):
                                NavigationLink(value: device) {
                                    EventCard(title: device.title, time: deviceTimeLabel(for: device),
                                              location: device.location, hue: .coral, group: nil,
                                              people: [], icon: "calendar",
                                              badge: "Private", badgeTone: .neutral)
                                }
                                .buttonStyle(CardPressStyle())
                            }
                        }
                    }
                    .padding(.horizontal, Space.gutter)

                    if model.firstLoad(of: calendarEvents) {
                        SkeletonList(count: 3).padding(.horizontal, Space.gutter)
                    } else if events.isEmpty && deviceEvents.isEmpty {
                        EmptyState(icon: "calendar",
                                   title: mode != .list ? "Nothing on this day" : "Nothing coming up",
                                   message: mode != .list
                                            ? "A free day. Add something, or find a time with a group."
                                            : "Your calendar's clear from here. Enjoy it, or fill it.",
                                   actionTitle: "New event") { showNewEvent = true }
                    }

                    Color.clear.frame(height: 120)
                }
            }
            .refreshable { await model.loadData() }
        }
        .background(Color.appBg)
        .navigationBarHidden(true)
        .navigationDestination(for: PEvent.self) { EventDetailView(event: $0) }
        .navigationDestination(for: DeviceEvent.self) { DeviceEventDetail(event: $0) }
        .onAppear { widenWindowIfNeeded() }
        .task { await model.refreshCalendar() }
        .onChange(of: visibleMonth) { _, _ in widenWindowIfNeeded() }
        .sheet(isPresented: $showNewEvent) {
            NewEventSheet(date: selectedDate ?? Date()).environmentObject(model)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Calendar").textStyle(.title1, color: .textStrong)
            Spacer()
            SegmentedControl(options: Mode.allCases, selection: $mode) { $0.rawValue }
                .frame(width: 170)
            IconButton(icon: "calendar-plus", variant: .secondary, size: 40, iconSize: 18,
                       accessibilityLabel: "New event") { showNewEvent = true }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    /// The seven days around the selected one. A week can straddle two months,
    /// so days carry their own date rather than a day-of-month number.
    private var weekDays: [Date] {
        let anchor = selectedDate ?? Date()
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: anchor)?.start ?? anchor
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private func select(_ date: Date) {
        withAnimation(Motion.fast) {
            visibleMonth = date
            selectedDay = cal.component(.day, from: date)
        }
    }

    private func dots(for date: Date) -> [Color] {
        var out = model.events.filter { $0.isOn(date) }.map(\.hue.color)
        out += model.deviceEvents.filter { cal.isDate($0.start, inSameDayAs: date) }
            .map { _ in GroupHue.coral.color }
        return out
    }

    private var weekStrip: some View {
        VStack(spacing: 8) {
            HStack {
                IconButton(icon: "chevron-left", variant: .ghost, size: 32, iconSize: 16,
                           accessibilityLabel: "Previous week") {
                    if let d = cal.date(byAdding: .day, value: -7, to: selectedDate ?? Date()) {
                        select(d)
                    }
                }
                Spacer()
                Text(weekTitle).textStyle(.headline, color: .textStrong)
                Spacer()
                IconButton(icon: "chevron-right", variant: .ghost, size: 32, iconSize: 16,
                           accessibilityLabel: "Next week") {
                    if let d = cal.date(byAdding: .day, value: 7, to: selectedDate ?? Date()) {
                        select(d)
                    }
                }
            }
            HStack(spacing: 2) {
                ForEach(weekDays, id: \.self) { day in
                    let isSelected = selectedDate.map { cal.isDate($0, inSameDayAs: day) } ?? false
                    let isToday = cal.isDateInToday(day)
                    VStack(spacing: 3) {
                        Text(Self.weekdayLetter.string(from: day))
                            .textStyle(.overline, color: .textFaint)
                        Text("\(cal.component(.day, from: day))")
                            .font(.system(size: 16, weight: isToday || isSelected ? .bold : .regular,
                                          design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(isSelected ? Color.white
                                             : (isToday ? Color.actionPrimary : Color.textBody))
                            .frame(width: 34, height: 34)
                            .background(isSelected ? Color.actionPrimary : .clear)
                            .clipShape(Circle())
                        HStack(spacing: 3) {
                            ForEach(Array(dots(for: day).prefix(3).enumerated()), id: \.offset) { _, c in
                                Circle().fill(c).frame(width: 5, height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { select(day) }
                }
            }
        }
    }

    private var weekTitle: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let f = DateFormatter(); f.dateFormat = "d MMM"
        return "\(f.string(from: first)) – \(f.string(from: last))"
    }

    private static let weekdayLetter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEEE"; return f
    }()

    private var monthBar: some View {
        HStack {
            IconButton(icon: "chevron-left", variant: .ghost, size: 32, iconSize: 16,
                       accessibilityLabel: "Previous month") { stepMonth(-1) }
            Spacer()
            Text(monthTitle).textStyle(.headline, color: .textStrong)
            Spacer()
            IconButton(icon: "chevron-right", variant: .ghost, size: 32, iconSize: 16,
                       accessibilityLabel: "Next month") { stepMonth(1) }
        }
    }
}

struct EventDetailView: View {
    let event: PEvent
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false
    @State private var showEdit = false
    @State private var confirmDelete = false
    @State private var confirmDecline = false
    @State private var answering = false

    /// Re-read so the visibility row updates as soon as sharing changes.
    /// An expanded occurrence has a synthetic id, so resolve through the row it
    /// came from — otherwise editing next week's instance would find nothing.
    private var live: PEvent {
        (model.events.first { $0.id == event.rowId } ?? event)
    }
    private var isOwner: Bool { live.isOwned(by: model.userId) }
    /// Your answer to a group plan: true going, false not, nil not yet.
    private var answer: Bool? { live.myRsvp(model.userId) }
    private var invitingGroup: PGroup? {
        live.sharedGroupIds.compactMap { id in model.groups.first { $0.id == id } }.first
    }

    /// Everyone the plan was offered to, with what they said. Real names and
    /// real answers — the old "Busy/Free" row was sample data wearing a badge.
    private var attendees: [(member: PMember, going: Bool?)] {
        guard let group = invitingGroup else { return [] }
        return group.members.map { ($0, live.myRsvp($0.id)) }
            .sorted { rank($0.1) < rank($1.1) }
    }
    private func rank(_ going: Bool?) -> Int {
        switch going { case .some(true): return 0; case .none: return 1; default: return 2 }
    }

    /// "Private" · "Shared with Soccer" · "Shared with Soccer and Maya + 2 more".
    private var visibility: String {
        let groupNames = live.sharedGroupIds.compactMap { id in model.groups.first { $0.id == id }?.name }
        let peopleNames = live.sharedUserIds.compactMap { id in
            model.addablePeople.first { $0.id == id }?.name
        }
        let names = groupNames + peopleNames
        switch names.count {
        case 0:  return live.source == .device ? "Private (from your calendar)" : "Private — only you"
        case 1:  return "Shared with \(names[0])"
        case 2:  return "Shared with \(names[0]) and \(names[1])"
        default: return "Shared with \(names[0]) + \(names.count - 1) more"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hue hero
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 52, height: 52)
                        .overlay(PIcon(event.icon, size: 26, color: .white, weight: .semibold))
                    Text(event.title).textStyle(.title1, color: .white)
                    if let group = event.group {
                        Text(group.uppercased()).textStyle(.overline, color: .white.opacity(0.85))
                    }
                }
                .padding(Space.gutter)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(event.hue.color)

                VStack(spacing: 0) {
                    detailRow("clock", "Time", event.time)
                    if let location = event.location { detailRow("map-pin", "Place", location) }
                    if live.recurrence != .never {
                        detailRow("repeat", "Repeats", live.recurrence.label.lowercased()
                                    .replacingOccurrences(of: "every", with: "Every"))
                    }
                    detailRow(live.isPrivate ? "lock" : "users", "Visibility", visibility)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 8)

                if live.isGroupEvent && !attendees.isEmpty {
                    SectionLabel("Who's going") {
                        Text("\(live.goingCount) of \(attendees.count)")
                            .textStyle(.caption, color: .textFaint)
                    }
                    VStack(spacing: Space.gapInline) {
                        ForEach(attendees, id: \.member.id) { row in
                            HStack(spacing: 12) {
                                Avatar(name: row.member.name, size: 36,
                                       status: row.going == true ? .free : .busy)
                                Text(row.member.name).textStyle(.body, color: .textBody)
                                Spacer()
                                switch row.going {
                                case .some(true):  Badge(text: "Going", tone: .free, icon: "check")
                                case .some(false): Badge(text: "Can't make it", tone: .neutral)
                                case .none:        Badge(text: "No answer yet", tone: .neutral)
                                }
                            }
                            .padding(.horizontal, Space.gutter)
                        }
                    }
                } else if !live.isGroupEvent && !event.people.isEmpty {
                    SectionLabel("Who's going")
                    VStack(spacing: Space.gapInline) {
                        ForEach(Array(event.people.enumerated()), id: \.offset) { i, name in
                            HStack(spacing: 12) {
                                Avatar(name: name, size: 36, status: .free)
                                Text(name).textStyle(.body, color: .textBody)
                                Spacer()
                            }
                            .padding(.horizontal, Space.gutter)
                        }
                    }
                }

                if live.isGroupEvent && !isOwner {
                    rsvpBlock
                } else if isOwner && live.isGroupEvent {
                    HStack(spacing: 8) {
                        PIcon("calendar-check", size: 16, color: .statusFree)
                        Text("You're going — you picked the time.")
                            .textStyle(.footnote, color: .textMuted)
                    }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 20)
                }

                // Sharing is the owner's call — RLS won't let anyone else write
                // shares, so we don't offer a button that can only fail.
                if isOwner {
                    PlannitButton(title: live.isPrivate ? "Share to a group" : "Change who can see it",
                                  variant: .primary, size: .lg,
                                  icon: "share-2", fullWidth: true) { showShare = true }
                        .padding(.horizontal, Space.gutter)
                        .padding(.top, 20)
                } else {
                    HStack(spacing: 8) {
                        PIcon("users", size: 16, color: .textFaint)
                        Text("Shared with you — only the owner can change this.")
                            .textStyle(.footnote, color: .textMuted)
                    }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 20)
                }

                Color.clear.frame(height: 40)
            }
        }
        .background(Color.appBg)
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top) {
            HStack {
                IconButton(icon: "chevron-left", variant: .secondary, size: 40, iconSize: 18,
                           accessibilityLabel: "Back") { dismiss() }
                Spacer()
                if isOwner {
                    Menu {
                        Button { showEdit = true } label: { Label("Edit event", systemImage: "pencil") }
                        Button { showShare = true } label: { Label("Share to a group", systemImage: "person.2.fill") }
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Delete event", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.textBody)
                            .frame(width: 40, height: 40)
                            .background(Color.surface)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("More")
                } else if live.isGroupEvent && answer == true {
                    Button { confirmDecline = true } label: {
                        Text("Remove").textStyle(.subhead, color: .statusDanger)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showShare) { ShareSheet(event: live).environmentObject(model) }
        .sheet(isPresented: $showEdit) {
            NewEventSheet(date: live.start, editing: live).environmentObject(model)
        }
        .confirmationDialog("Delete “\(live.title)”?", isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Delete event", role: .destructive) {
                Task { await model.deleteEvent(live) }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteWarning)
        }
        .confirmationDialog("Not going to “\(live.title)”?", isPresented: $confirmDecline,
                            titleVisibility: .visible) {
            Button("Remove from my calendar", role: .destructive) {
                answerInvitation(false)
                dismiss()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("It comes off your calendar and the group sees you as not going.")
        }
    }

    private var deleteWarning: String {
        if live.isGroupEvent {
            let going = max(0, live.goingCount - 1)
            return going == 0
                ? "The plan is off — nobody else has said yes yet."
                : "The plan is off. \(going) \(going == 1 ? "person who's" : "people who are") going will be told."
        }
        return live.isPrivate
            ? "This removes it from your calendar."
            : "This removes it for everyone it's shared with."
    }

    /// Going or not — the whole of a group plan's participation model. Saying
    /// yes is what puts it on your calendar (decision D-12, revised).
    @ViewBuilder
    private var rsvpBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let group = invitingGroup {
                HStack(spacing: 6) {
                    Circle().fill(group.hue.color).frame(width: 7, height: 7)
                    Text(answer == nil
                         ? "\(group.name) — are you in?"
                         : (answer == true ? "You're going" : "You said you can't make it"))
                        .textStyle(.subhead, color: .textBody)
                }
            }
            HStack(spacing: 10) {
                PlannitButton(title: "Going", variant: answer == true ? .free : .secondary,
                              size: .lg, icon: "check", fullWidth: true) {
                    answerInvitation(true)
                }
                .disabled(answering)
                PlannitButton(title: "Can't make it",
                              variant: answer == false ? .primary : .secondary,
                              size: .lg, icon: "x", fullWidth: true) {
                    answerInvitation(false)
                }
                .disabled(answering)
            }
            Text(answer == true
                 ? "It's on your calendar. You can change your mind any time."
                 : "Say yes and it goes straight on your calendar.")
                .textStyle(.caption, color: .textFaint)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, 20)
    }

    private func answerInvitation(_ going: Bool) {
        answering = true
        Task {
            await model.rsvp(to: live, going: going)
            answering = false
        }
    }

    private func detailRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            PIcon(icon, size: 18, color: .textMuted)
            Text(label).textStyle(.subhead, color: .textMuted).frame(width: 76, alignment: .leading)
            Text(value).textStyle(.body, color: .textStrong)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1) }
    }
}

// Per-group visibility sheet — the one place an event stops being private.
// Ticking a group inserts an `event_shares` row; unticking deletes it.
struct ShareSheet: View {
    let event: PEvent

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var shared: Set<String>
    @State private var sharedPeople: Set<String>
    @State private var saving = false
    @State private var errorText: String?

    init(event: PEvent) {
        self.event = event
        _shared = State(initialValue: Set(event.sharedGroupIds))
        _sharedPeople = State(initialValue: Set(event.sharedUserIds))
    }

    private var changed: Bool {
        shared != Set(event.sharedGroupIds) || sharedPeople != Set(event.sharedUserIds)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.lineStrong).frame(width: 40, height: 5).padding(.vertical, 10)
            HStack {
                Text("Share this event").textStyle(.title3, color: .textStrong)
                Spacer()
                IconButton(icon: "x", variant: .secondary, size: 36, iconSize: 16,
                           accessibilityLabel: "Close") { dismiss() }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, 8)

            Text(shared.isEmpty && sharedPeople.isEmpty
                 ? "Only you can see this. Pick who should see it too."
                 : "Everyone ticked can see this event. Untick to take it back.")
                .textStyle(.footnote, color: .textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: Space.gapInline) {
                    if model.groups.isEmpty {
                        EmptyState(icon: "users", title: "No groups yet",
                                   message: "Make a group first — then you can share events with it.")
                    }
                    ForEach(model.groups) { group in
                        Button { toggle(group.id) } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .fill(group.hue.color).frame(width: 34, height: 34)
                                    .overlay(PIcon("users", size: 16, color: .white))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(group.name).textStyle(.headline, color: .textStrong)
                                    Text("\(group.members.count) people")
                                        .textStyle(.caption, color: .textMuted)
                                }
                                Spacer()
                                PIcon(shared.contains(group.id) ? "circle-check" : "circle",
                                      size: 22, color: shared.contains(group.id) ? .actionPrimary : .textFaint)
                            }
                            .padding(Space.card)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                                .strokeBorder(shared.contains(group.id) ? Color.actionPrimary : Color.hairline,
                                              lineWidth: shared.contains(group.id) ? 2 : 1))
                        }
                        .buttonStyle(CardPressStyle())
                    }
                    if !model.friends.isEmpty {
                        SectionLabel("Or one person")
                        ForEach(model.friends) { friend in
                            Button { togglePerson(friend.id) } label: {
                                HStack(spacing: 12) {
                                    Avatar(name: friend.name, size: 34)
                                    Text(friend.name).textStyle(.headline, color: .textStrong)
                                    Spacer()
                                    PIcon(sharedPeople.contains(friend.id) ? "circle-check" : "circle",
                                          size: 22,
                                          color: sharedPeople.contains(friend.id) ? .actionPrimary : .textFaint)
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let errorText {
                        Text(errorText).textStyle(.footnote, color: .statusDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, Space.gutter)
            }

            PlannitButton(title: saving ? "Saving…" : (changed ? "Save" : "Done"),
                          variant: .primary, size: .lg, fullWidth: true) {
                changed ? save() : dismiss()
            }
            .disabled(saving)
            .opacity(saving ? 0.5 : 1)
            .padding(Space.gutter)
        }
        .background(Color.appBg)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private func save() {
        saving = true
        errorText = nil
        Task {
            let ok = await model.shareEvent(event, with: shared, people: sharedPeople)
            saving = false
            if ok { dismiss() } else { errorText = "Couldn’t update sharing. Only the event's owner can." }
        }
    }

    private func toggle(_ id: String) {
        withAnimation(Motion.fast) {
            if shared.contains(id) { _ = shared.remove(id) } else { _ = shared.insert(id) }
        }
    }

    private func togglePerson(_ id: String) {
        withAnimation(Motion.fast) {
            if sharedPeople.contains(id) { _ = sharedPeople.remove(id) }
            else { _ = sharedPeople.insert(id) }
        }
    }
}
