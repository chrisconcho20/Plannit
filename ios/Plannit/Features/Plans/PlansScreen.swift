import SwiftUI
import UIKit

// Plans tab — group plans waiting on your answer, the ones you've said yes to,
// the New Plan (date-finder) flow, and the You screen.
//
// There is no voting here any more (decision D-12, revised): the organiser
// picks a date the finder found, everyone else answers going or not going, and
// saying yes is what puts it on your calendar.

/// The Plans tab's one destination beyond an event.
enum PlansRoute: Hashable { case activity }

struct PlansScreen: View {
    @EnvironmentObject private var model: AppModel

    private var invitations: [PEvent] { model.invitations }
    private var upcoming: [PEvent] { model.upcomingPlans }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Plans").textStyle(.title1, color: .textStrong)
                Spacer()
                NavigationLink(value: PlansRoute.activity) {
                    ZStack(alignment: .topTrailing) {
                        PIcon("bell", size: 18, color: .textBody)
                            .frame(width: 40, height: 40)
                            .background(Color.surface)
                            .clipShape(Circle())
                        if model.unreadActivity > 0 {
                            Circle().fill(Color.actionPrimary)
                                .frame(width: 10, height: 10)
                                .offset(x: 1, y: -1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.unreadActivity > 0
                                    ? "Activity, \(model.unreadActivity) new" : "Activity")
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 6)

            ScrollView {
                if let error = model.loadError {
                    LoadBanner(message: error) { Task { await model.loadData() } }
                }
                if !invitations.isEmpty {
                    SectionLabel("Are you in?") {
                        Text("\(invitations.count)").textStyle(.caption, color: .textFaint)
                    }
                    LazyVStack(spacing: Space.gapList) {
                        ForEach(invitations) { event in
                            InvitationCard(event: event)
                        }
                    }
                    .padding(.horizontal, Space.gutter)
                }

                if !upcoming.isEmpty {
                    SectionLabel("You're going")
                    LazyVStack(spacing: Space.gapList) {
                        ForEach(upcoming) { event in
                            NavigationLink(value: event) { PlanRow(event: event) }
                                .buttonStyle(CardPressStyle())
                        }
                    }
                    .padding(.horizontal, Space.gutter)
                }

                if model.firstLoad(of: model.events) {
                    SkeletonList(count: 2).padding(.horizontal, Space.gutter)
                } else if invitations.isEmpty && upcoming.isEmpty {
                    EmptyState(icon: "sparkles", title: "No plans in the air",
                               message: "Pick a group, say roughly when — “a weekend afternoon” — and Plannit checks everyone's calendars and comes back with dates that actually work.")
                }
                Color.clear.frame(height: 120)
            }
            .refreshable { await model.loadData() }
        }
        .background(Color.appBg)
        .navigationBarHidden(true)
        .liveRefresh(every: 20) { await model.refreshEvents() }
        .navigationDestination(for: PEvent.self) { EventDetailView(event: $0) }
        .navigationDestination(for: PlansRoute.self) { _ in ActivityScreen() }
    }
}

/// An invitation you haven't answered — the whole decision, on one card, so
/// nobody has to open a screen to say yes.
struct InvitationCard: View {
    let event: PEvent
    @EnvironmentObject private var model: AppModel
    @State private var answering = false

    private var group: PGroup? {
        event.sharedGroupIds.compactMap { id in model.groups.first { $0.id == id } }.first
    }

    var body: some View {
        PlannitCard(elevation: 1) {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink(value: event) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(event.title).textStyle(.headline, color: .textStrong)
                            Spacer()
                            Badge(text: "\(event.goingCount) going", tone: .primary, icon: "check")
                        }
                        HStack(spacing: 6) {
                            Circle().fill((group?.hue ?? event.hue).color).frame(width: 7, height: 7)
                            Text(group?.name ?? event.group ?? "A group")
                                .textStyle(.caption, color: .textMuted)
                        }
                        HStack(spacing: 10) {
                            PIcon("calendar", size: 16, color: .statusFree)
                            Text(PlanRow.when(event)).textStyle(.subhead, color: .textBody)
                            Spacer(minLength: 0)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    PlannitButton(title: "Going", variant: .free, size: .md,
                                  icon: "check", fullWidth: true) { answer(true) }
                        .disabled(answering)
                    PlannitButton(title: "Can't make it", variant: .secondary, size: .md,
                                  icon: "x", fullWidth: true) { answer(false) }
                        .disabled(answering)
                }
            }
        }
        .opacity(answering ? 0.6 : 1)
    }

    private func answer(_ going: Bool) {
        answering = true
        Task {
            let ok = await model.rsvp(to: event, going: going)
            answering = false
            if ok {
                model.say(going ? "Added to your calendar" : "You're down as not going")
            }
        }
    }
}

/// A plan you've said yes to.
struct PlanRow: View {
    let event: PEvent
    @EnvironmentObject private var model: AppModel

    private var group: PGroup? {
        event.sharedGroupIds.compactMap { id in model.groups.first { $0.id == id } }.first
    }

    var body: some View {
        PlannitCard(elevation: 1) {
            HStack(spacing: 14) {
                VStack(spacing: 0) {
                    Text(Self.weekday(event)).textStyle(.overline, color: Palette.teal700)
                    Text("\(event.day)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.teal700)
                }
                .frame(width: 52)
                .padding(.vertical, 6)
                .background(Palette.teal50)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title).textStyle(.headline, color: .textStrong)
                    HStack(spacing: 6) {
                        Circle().fill((group?.hue ?? event.hue).color).frame(width: 7, height: 7)
                        Text(group?.name ?? event.group ?? "A group")
                            .textStyle(.caption, color: .textMuted)
                        Text("·").foregroundStyle(Color.textFaint)
                        Text(Self.when(event)).textStyle(.caption, color: .textMuted)
                    }
                }
                Spacer(minLength: 0)
                Badge(text: "\(event.goingCount) going", tone: .free, icon: "check")
            }
        }
    }

    static func weekday(_ event: PEvent) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: event.start).uppercased()
    }

    /// "Sat 16 Aug · 2:00 PM" — the date first, because that's what was decided.
    static func when(_ event: PEvent) -> String {
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDate(event.start, equalTo: Date(), toGranularity: .year)
            ? "EEE d MMM" : "EEE d MMM yyyy"
        let day = f.string(from: event.start)
        guard !event.isAllDay else { return "\(day) · all day" }
        let t = DateFormatter(); t.dateFormat = "h:mm a"
        return "\(day) · \(t.string(from: event.start))"
    }
}

/// The only place the You tab navigates to, for now.
enum YouRoute: Hashable { case friends }

struct YouScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var showRename = false
    @State private var confirmSignOut = false
    @State private var connecting = false
    @State private var shareAvailability = true
    @State private var pushDateFound = true
    @State private var pushInvites = true
    @AppStorage(SearchWindow.key) private var searchMonths = SearchWindow.defaultMonths

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("You").textStyle(.title1, color: .textStrong)
                Spacer()
            }
            .padding(.horizontal, Space.gutter).padding(.vertical, 6)

            ScrollView {
                HStack(spacing: 14) {
                    Avatar(name: model.displayName, size: 60)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.displayName).textStyle(.title3, color: .textStrong)
                        Text(model.userEmail ?? (model.isLiveBackend ? "Signed in" : "Demo mode"))
                            .textStyle(.footnote, color: .textMuted)
                    }
                    Spacer()
                    PlannitButton(title: "Edit", variant: .secondary, size: .sm) { showRename = true }
                }
                .padding(Space.gutter)

                SectionLabel("Profile")
                settingsCard {
                    nameRow()
                    divider
                    NavigationLink(value: YouRoute.friends) {
                        HStack(spacing: 12) {
                            PIcon("users", size: 20, color: .textMuted).frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Friends").textStyle(.headline, color: .textStrong)
                                Text("Who you can add to groups and plans")
                                    .textStyle(.caption, color: .textMuted)
                            }
                            Spacer()
                            if !model.incomingRequests.isEmpty {
                                Badge(text: "\(model.incomingRequests.count) new", tone: .primary)
                            } else {
                                Text("\(model.friends.count)").textStyle(.subhead, color: .textMuted)
                            }
                            PIcon("chevron-right", size: 16, color: .textFaint)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                SectionLabel("Date finder")
                settingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            PIcon("wand-sparkles", size: 20, color: .textMuted).frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("How far ahead to look").textStyle(.headline, color: .textStrong)
                                Text("Plannit holds out for a time the whole group can make — a longer window makes that more likely.")
                                    .textStyle(.caption, color: .textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        SegmentedControl(options: SearchWindow.options, selection: $searchMonths) {
                            SearchWindow.label($0)
                        }
                        .padding(.leading, 34)
                    }
                    .padding(.vertical, 12)
                }

                SectionLabel("Calendar")
                settingsCard {
                    calendarRow
                    divider
                    toggleRow("eye-off", "Share availability", "Only free/busy — never event details", $shareAvailability)
                }

                SectionLabel("Notifications")
                settingsCard {
                    toggleRow("wand-sparkles", "A date was found", "When Plannit finds a time for a group", $pushDateFound)
                    divider
                    toggleRow("user-plus", "Invites & requests", "Friend requests and shared events", $pushInvites)
                }

                PlannitButton(title: "Sign out", variant: .danger, size: .md, fullWidth: true) {
                    confirmSignOut = true
                }
                .padding(.horizontal, Space.gutter).padding(.top, 16)

                Text("Plannit \(Bundle.appVersion)")
                    .textStyle(.caption, color: .textFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                Color.clear.frame(height: 120)
            }
        }
        .background(Color.appBg)
        .navigationBarHidden(true)
        .navigationDestination(for: YouRoute.self) { _ in FriendsScreen() }
        .sheet(isPresented: $showRename) {
            DisplayNameSheet(current: model.displayName).environmentObject(model)
        }
        .confirmationDialog("Sign out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { model.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need your email and password to get back in.")
        }
    }

    private var divider: some View { Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 46) }

    private func settingsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, Space.card)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Color.hairline, lineWidth: 1))
            .padding(.horizontal, Space.gutter)
    }

    /// The calendar connection, stated honestly and actionable in every state.
    /// This used to be a Toggle bound to a @State bool — it looked like a
    /// setting and controlled nothing, while the only route to the permission
    /// prompt was a demo-mode screen a live user never sees.
    @ViewBuilder
    private var calendarRow: some View {
        HStack(spacing: 12) {
            PIcon(model.calendarConnected ? "calendar-check" : "calendar",
                  size: 20, color: model.calendarConnected ? .statusFree : .textMuted)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Your calendar").textStyle(.headline, color: .textStrong)
                Text(calendarStatus).textStyle(.caption, color: .textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if model.calendarConnected {
                Badge(text: "On", tone: .free)
            } else if model.calendarNeedsSettings {
                PlannitButton(title: "Settings", variant: .secondary, size: .sm) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                PlannitButton(title: connecting ? "…" : "Connect", variant: .primary, size: .sm) {
                    connecting = true
                    Task { await model.connectCalendar(); connecting = false }
                }
                .disabled(connecting)
            }
        }
        .padding(.vertical, 12)
    }

    private var calendarStatus: String {
        if model.calendarConnected {
            return "\(model.deviceEvents.count) events read. Only free/busy is shared."
        }
        if model.calendarNeedsSettings {
            return "You said no earlier — iOS only asks once, so turn it on in Settings."
        }
        return "Plannit needs it to find times your groups are free."
    }

    private func nameRow() -> some View {
        Button { showRename = true } label: {
            HStack(spacing: 12) {
                PIcon("user", size: 20, color: .textMuted).frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Display name").textStyle(.headline, color: .textStrong)
                    Text("Everyone in your groups sees this")
                        .textStyle(.caption, color: .textMuted)
                }
                Spacer()
                Text(model.displayName).textStyle(.subhead, color: .textMuted)
                PIcon("chevron-right", size: 16, color: .textFaint)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(_ icon: String, _ title: String, _ subtitle: String, _ binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            PIcon(icon, size: 20, color: .textMuted).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).textStyle(.headline, color: .textStrong)
                Text(subtitle).textStyle(.caption, color: .textMuted)
            }
            Spacer()
            Toggle("", isOn: binding).labelsHidden().tint(.statusFree)
        }
        .padding(.vertical, 12)
    }
}

// Rename yourself. The name is written to `profiles.display_name`, which is what
// everyone in your groups sees — including the avatars on a found slot.
struct DisplayNameSheet: View {
    let current: String

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var saving = false
    @State private var errorText: String?

    init(current: String) {
        self.current = current
        _name = State(initialValue: current)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Display name") { dismiss() }
            VStack(alignment: .leading, spacing: 14) {
                PTextField(placeholder: "Your name", text: $name, icon: "user")
                Text("This is how you appear to everyone in your groups.")
                    .textStyle(.footnote, color: .textMuted)
                if let errorText {
                    Text(errorText).textStyle(.footnote, color: .statusDanger)
                }
                PlannitButton(title: saving ? "Saving…" : "Save", variant: .primary,
                              size: .lg, fullWidth: true) { save() }
                    .disabled(saving || trimmed.isEmpty || trimmed == current)
                    .opacity(saving || trimmed.isEmpty || trimmed == current ? 0.5 : 1)
            }
            .padding(Space.gutter)
            Spacer(minLength: 0)
        }
        .background(Color.appBg)
        .presentationDetents([.height(280)])
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        saving = true
        errorText = nil
        Task {
            let ok = await model.updateDisplayName(trimmed)
            saving = false
            if ok { dismiss() } else { errorText = "Couldn’t save that name. Try again." }
        }
    }
}
