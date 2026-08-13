import SwiftUI

// Calendar tab — Month / Week / List, a month grid with hue marks, and the
// day's events. Mirrors ui_kits/plannit-ios/CalendarScreen.jsx.

struct CalendarScreen: View {
    enum Mode: String, CaseIterable { case month = "Month", week = "Week", list = "List" }

    @State private var mode: Mode = .month
    @State private var selectedDay: Int? = 16

    private var events: [PEvent] {
        if mode == .month, let day = selectedDay {
            return Sample.events.filter { $0.day == day }
        }
        return Sample.events.sorted { $0.day < $1.day }
    }

    private var sectionTitle: String {
        if mode == .month, let day = selectedDay { return "August \(day)" }
        return "Upcoming"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    if mode == .month {
                        PlannitCard(elevation: 1) {
                            MonthGrid(year: 2026, month: 8, marks: Sample.marks, today: 13, selected: $selectedDay)
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

                    if events.isEmpty {
                        EmptyState(icon: "calendar", title: "Nothing here",
                                   message: "No events on this day. Tap ＋ to find a time with a group.")
                    }

                    Color.clear.frame(height: 120)
                }
            }
        }
        .background(Color.appBg)
        .navigationBarHidden(true)
        .navigationDestination(for: PEvent.self) { EventDetailView(event: $0) }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Calendar").textStyle(.title1, color: .textStrong)
            Spacer()
            SegmentedControl(options: Mode.allCases, selection: $mode) { $0.rawValue }
                .frame(width: 190)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, 6)
        .padding(.bottom, 6)
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
        withAnimation(Motion.fast) { _ = shared.contains(id) ? shared.remove(id) : shared.insert(id) }
    }
}
