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

    /// Events in the shown month, grouped by day — the source of the grid's dots.
    /// Derived from real events, so a day only gets a mark if something is on it.
    private var marks: [Int: [Color]] {
        var out: [Int: [Color]] = [:]
        for event in model.events
        where cal.isDate(event.start, equalTo: visibleMonth, toGranularity: .month) {
            out[event.day, default: []].append(event.hue.color)
        }
        for device in model.deviceEvents
        where cal.isDate(device.start, equalTo: visibleMonth, toGranularity: .month) {
            out[cal.component(.day, from: device.start), default: []].append(GroupHue.coral.color)
        }
        return out
    }

    private var events: [PEvent] {
        if mode == .month, let selectedDate {
            return model.events.filter { $0.isOn(selectedDate) }.sorted { $0.start < $1.start }
        }
        let now = cal.startOfDay(for: Date())
        return model.events.filter { $0.start >= now }.sorted { $0.start < $1.start }
    }

    private var sectionTitle: String {
        if mode == .month, let selectedDate {
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
                    }

                    SectionLabel(sectionTitle)

                    LazyVStack(spacing: Space.gapList) {
                        ForEach(events) { event in
                            NavigationLink(value: event) {
                                EventCard(title: event.title, time: event.time, location: event.location,
                                          hue: event.hue, group: event.group, people: event.people,
                                          icon: event.icon, badge: event.badge, badgeTone: event.badgeTone)
                            }
                            .buttonStyle(CardPressStyle())
                        }
                    }
                    .padding(.horizontal, Space.gutter)

                    if events.isEmpty && model.deviceEvents.isEmpty {
                        EmptyState(icon: "calendar", title: "Nothing here",
                                   message: mode == .month
                                            ? "No events on this day."
                                            : "Nothing coming up.",
                                   actionTitle: "New event") { showNewEvent = true }
                    }

                    if !model.deviceEvents.isEmpty {
                        SectionLabel("From your calendar") {
                            Text("\(model.deviceEvents.count)").textStyle(.caption, color: .textFaint)
                        }
                        LazyVStack(spacing: Space.gapList) {
                            ForEach(model.deviceEvents) { device in
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
    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false

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
                    detailRow(event.source == .device ? "lock" : "users",
                              "Visibility",
                              event.source == .device ? "Private (from your calendar)" : "Shared with \(event.group ?? "group")")
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

                PlannitButton(title: "Share to a group", variant: .primary, size: .lg,
                              icon: "share-2", fullWidth: true) { showShare = true }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 20)

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
                IconButton(icon: "ellipsis", variant: .secondary, size: 40, iconSize: 18,
                           accessibilityLabel: "More") {}
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showShare) { ShareSheet(event: event) }
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

// Per-group visibility sheet.
struct ShareSheet: View {
    let event: PEvent
    @Environment(\.dismiss) private var dismiss
    @State private var shared: Set<String> = []

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

            Text("Choose which groups can see it. Everything else stays private.")
                .textStyle(.footnote, color: .textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, 12)

            VStack(spacing: Space.gapInline) {
                ForEach(Sample.groups) { group in
                    Button { toggle(group.id) } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(group.hue.color).frame(width: 34, height: 34)
                                .overlay(PIcon("users", size: 16, color: .white))
                            Text(group.name).textStyle(.headline, color: .textStrong)
                            Spacer()
                            PIcon(shared.contains(group.id) ? "circle-check" : "circle",
                                  size: 22, color: shared.contains(group.id) ? .actionPrimary : .textFaint)
                        }
                        .padding(Space.card)
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .strokeBorder(Color.hairline, lineWidth: 1))
                    }
                    .buttonStyle(CardPressStyle())
                }
            }
            .padding(.horizontal, Space.gutter)

            Spacer(minLength: 0)
            PlannitButton(title: "Done", variant: .primary, size: .lg, fullWidth: true) { dismiss() }
                .padding(Space.gutter)
        }
        .background(Color.appBg)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private func toggle(_ id: String) {
        withAnimation(Motion.fast) {
            if shared.contains(id) { _ = shared.remove(id) } else { _ = shared.insert(id) }
        }
    }
}
