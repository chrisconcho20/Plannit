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

    private static let deviceTimeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE d · h:mm a"; return f
    }()
    private static func deviceTime(_ d: DeviceEvent) -> String {
        d.isAllDay ? "All day" : deviceTimeFormatter.string(from: d.start)
    }

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
        return model.events.flatMap { $0.occurrences(in: monthRange) }
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
            return model.events.flatMap { $0.occurrences(in: day...end) }
                .filter { $0.isOn(selectedDate) }
                .sorted { $0.start < $1.start }
        }
        // Upcoming: a repeating event should appear on each of its next dates,
        // not once forever at its original start.
        let now = cal.startOfDay(for: Date())
        let horizon = cal.date(byAdding: .month, value: 3, to: now) ?? now
        return model.events.flatMap { $0.occurrences(in: now...horizon) }
            .sorted { $0.start < $1.start }
    }

    /// Your own calendar's events, scoped exactly like the Plannit ones above:
    /// the selected day, or everything upcoming in List mode. Unfiltered, this
    /// dumped all 60 days under whichever day you'd tapped — invisible on an
    /// empty simulator, a wall of text on a real phone.
    private var deviceEvents: [DeviceEvent] {
        let all = model.deviceEvents.sorted { $0.start < $1.start }
        if mode != .list, let selectedDate {
            return all.filter { cal.isDate($0.start, inSameDayAs: selectedDate) }
        }
        return all.filter { $0.start >= cal.startOfDay(for: Date()) }
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
                        ForEach(events) { event in
                            NavigationLink(value: event) {
                                EventCard(title: event.title, time: timeLabel(for: event),
                                          location: event.location,
                                          hue: event.hue, group: event.group, people: event.people,
                                          icon: event.icon, badge: event.badge, badgeTone: event.badgeTone)
                            }
                            .buttonStyle(CardPressStyle())
                        }
                    }
                    .padding(.horizontal, Space.gutter)

                    if model.firstLoad(of: model.events) {
                        SkeletonList(count: 3).padding(.horizontal, Space.gutter)
                    } else if events.isEmpty && deviceEvents.isEmpty {
                        EmptyState(icon: "calendar",
                                   title: mode != .list ? "Nothing on this day" : "Nothing coming up",
                                   message: mode != .list
                                            ? "A free day. Add something, or find a time with a group."
                                            : "Your calendar's clear from here. Enjoy it, or fill it.",
                                   actionTitle: "New event") { showNewEvent = true }
                    }

                    if !deviceEvents.isEmpty {
                        SectionLabel("Also on your calendar") {
                            Text("\(deviceEvents.count)").textStyle(.caption, color: .textFaint)
                        }
                        LazyVStack(spacing: Space.gapList) {
                            ForEach(deviceEvents) { device in
                                EventCard(title: device.title, time: Self.deviceTime(device),
                                          location: device.location, hue: .coral, group: nil,
                                          people: [], icon: "calendar", badge: "Private", badgeTone: .neutral)
                            }
                        }
                        .padding(.horizontal, Space.gutter)
                    }

                    Color.clear.frame(height: 120)
                }
            }
            .refreshable { await model.loadData() }
        }
        .background(Color.appBg)
        .navigationBarHidden(true)
        .navigationDestination(for: PEvent.self) { EventDetailView(event: $0) }
        .onAppear { model.refreshCalendar() }
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

    /// Re-read so the visibility row updates as soon as sharing changes.
    /// An expanded occurrence has a synthetic id, so resolve through the row it
    /// came from — otherwise editing next week's instance would find nothing.
    private var live: PEvent {
        (model.events.first { $0.id == event.rowId } ?? event)
    }
    private var isOwner: Bool { live.isOwned(by: model.userId) }

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

                if !event.people.isEmpty {
                    SectionLabel("Who's going")
                    VStack(spacing: Space.gapInline) {
                        ForEach(Array(event.people.enumerated()), id: \.offset) { i, name in
                            HStack(spacing: 12) {
                                Avatar(name: name, size: 36, status: i % 3 == 0 ? .busy : .free)
                                Text(name).textStyle(.body, color: .textBody)
                                Spacer()
                                Badge(text: i % 3 == 0 ? "Busy" : "Free", tone: i % 3 == 0 ? .neutral : .free)
                            }
                            .padding(.horizontal, Space.gutter)
                        }
                    }
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
            Text(live.isPrivate
                 ? "This removes it from your calendar."
                 : "This removes it for everyone it's shared with.")
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
