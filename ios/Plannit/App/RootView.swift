import SwiftUI

enum Tab: Hashable { case calendar, groups, plans, you }

// Top-level flow: onboarding -> tabbed app, with the FAB, tab bar and toast.
struct RootView: View {
    enum Flow { case restoring, welcome, connect, app }

    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var flow: Flow = Config.isLiveBackend ? .restoring : .welcome
    @State private var tab: Tab = .calendar
    @State private var showCreate = false
    @State private var showNewPlan = false
    @State private var showNewEvent = false
    @State private var showNewGroup = false
    @State private var toast: String?

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            switch flow {
            case .restoring:
                // A stored session means we can go straight in; this beat stops
                // the sign-in screen flashing before we know.
                ProgressView().tint(.actionPrimary)
            case .welcome:
                if Config.isLiveBackend {
                    // Straight to .app would skip the calendar ask entirely —
                    // and without it there are no busy blocks, so the
                    // date-finder has nothing to work with.
                    LiveSignInView { flow = model.calendarAuthorized ? .app : .connect }
                } else {
                    WelcomeView(
                        onStart: { flow = .connect },
                        onSignIn: { flow = .app }
                    )
                }
            case .connect:
                ConnectCalendarView(
                    connect: { await model.connectCalendar(); flow = .app },
                    onSkip: { flow = .app }
                )
            case .app:
                appShell
            }
        }
        .environmentObject(model)
        // Every colour token is a literal from a light palette, so the app has
        // to say so: left to follow the system, only the *adaptive* parts
        // (materials, menus, sheets) flip dark and the result is a dark bar
        // under warm-grey icons. Remove this the day there's a dark ramp.
        .preferredColorScheme(.light)
        // Straight back in if the Keychain still has a session.
        .task {
            model.startDemoIdentity()
            PushService.shared.start()
            guard flow == .restoring else { return }
            flow = await model.restoreSession() ? .app : .welcome
            if flow == .app { await PushService.shared.syncToken() }
        }
        // A tapped notification picks the tab its subject lives on. Landing on
        // the exact group or plan needs a navigation path this app doesn't have
        // yet (ROADMAP Phase 4).
        .onReceive(PushService.shared.$destination.compactMap { $0 }) { destination in
            switch destination {
            case .group:   tab = .groups
            case .event:   tab = .plans
            case .friends: tab = .you
            }
            PushService.shared.clearDestination()
        }
        // Signing out anywhere returns to the front door.
        .onChange(of: model.signedIn) { _, signedIn in
            if !signedIn, flow == .app { flow = .welcome }
        }
        // The ＋ asks what you're making rather than guessing from the tab.
        .sheet(isPresented: $showCreate) {
            CreateSheet(group: model.openGroup,
                        offerNewGroup: tab == .groups && model.openGroup == nil) { choice in
                showCreate = false
                // Let the sheet finish dismissing before presenting the next one.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    switch choice {
                    case .findADate: showNewPlan = true
                    case .addEvent:  showNewEvent = true
                    case .newGroup:  showNewGroup = true
                    }
                }
            }
            .environmentObject(model)
        }
        .sheet(isPresented: $showNewPlan) {
            NewPlanSheet(groups: model.groups, preselected: model.openGroup) { name, group in
                showNewPlan = false
                tab = .plans
                showToast("\(name) sent to \(group) — we’ll tell you who's in")
            }
            .environmentObject(model)
        }
        .sheet(isPresented: $showNewEvent) {
            NewEventSheet(date: Date(), group: model.openGroup).environmentObject(model)
        }
        .sheet(isPresented: $showNewGroup) { NewGroupSheet().environmentObject(model) }
        .animation(Motion.base, value: flow)
    }

    private var appShell: some View {
        ZStack(alignment: .bottomTrailing) {
            tabContent
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    PlannitTabBar(selection: $tab, plansBadge: model.plansBadge)
                }

            if tab != .you {
                IconButton(icon: "plus", variant: .primary, size: 58, iconSize: 26,
                           accessibilityLabel: "New") { showCreate = true }
                    .padding(.trailing, Space.gutter)
                    .padding(.bottom, Space.tabBarH + 30)
            }

            // Either the shell's own message (a plan was sent) or one a screen
            // couldn't show itself (a write failed three sheets deep).
            if let message = toast ?? model.toast {
                Toast(text: message,
                      icon: model.toast == nil ? "circle-check" : "circle-alert",
                      tone: model.toast == nil ? .free : .neutral)
                    .padding(.horizontal, Space.gutter)
                    .padding(.bottom, Space.tabBarH + 24)
                    .frame(maxWidth: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Two shapes reach here: the Universal Link a person taps in Messages
        // (https://plannittogether.com/invite/<token>) and the custom scheme the
        // web page falls back to (plannit://invite/<token>).
        .onOpenURL { url in
            guard let token = Self.inviteToken(in: url) else { return }
            Task { await model.redeemInvite(token: token) }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL, let token = Self.inviteToken(in: url) else { return }
            Task { await model.redeemInvite(token: token) }
        }
        .animation(Motion.base, value: model.toast)
        .task {
            await model.resumeCalendarIfAuthorized()
            await model.loadData()
            await model.startRealtime()
        }
        // A full reconcile every time we come back: EventKit can't tell us about
        // edits made while we were away (sync-contract §Background refresh).
        .onChange(of: scenePhase) { _, phase in
            Task {
                // iOS suspends us shortly after backgrounding and the socket
                // dies with it, so drop it deliberately and rebuild on return.
                guard phase == .active else {
                    await model.stopRealtime()
                    return
                }
                await model.syncCalendar(pullRemote: true)
                await model.loadData()
                await model.startRealtime()
            }
        }
    }

    /// The token in an invite link, whichever shape it arrived in. Anything
    /// else — another path on the site, another scheme — is not ours.
    static func inviteToken(in url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        switch url.scheme {
        case "plannit" where url.host == "invite":
            return parts.last.flatMap { $0.isEmpty ? nil : $0 }
        case "https" where parts.first == "invite":
            return parts.count > 1 ? parts[1] : nil
        default:
            return nil
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .calendar: NavigationStack { CalendarScreen() }
        case .groups:   NavigationStack { GroupsScreen() }
        case .plans:    NavigationStack { PlansScreen() }
        case .you:      NavigationStack { YouScreen() }
        }
    }

    private func showToast(_ text: String) {
        withAnimation(Motion.pop) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(Motion.base) { toast = nil }
        }
    }
}

struct PlannitTabBar: View {
    @Binding var selection: Tab
    /// Plans waiting on you — nil hides the dot. Never a constant: an always-lit
    /// badge is worse than none.
    var plansBadge: Int? = nil

    private struct Item { let tab: Tab; let label: String; let icon: String; let badge: Int? }
    private var items: [Item] {
        [.init(tab: .calendar, label: "Calendar", icon: "calendar-days", badge: nil),
         .init(tab: .groups, label: "Groups", icon: "users", badge: nil),
         .init(tab: .plans, label: "Plans", icon: "sparkles", badge: plansBadge),
         .init(tab: .you, label: "You", icon: "user", badge: nil)]
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(items, id: \.tab) { item in
                let on = item.tab == selection
                Button { withAnimation(Motion.fast) { selection = item.tab } } label: {
                    VStack(spacing: 3) {
                        ZStack(alignment: .topTrailing) {
                            // .textMuted, not .textFaint: the faint token is ~2.8:1
                            // on paper, which fails AA for anything you're meant
                            // to read. This is a tab label, not a hint.
                            PIcon(item.icon, size: 24, color: on ? .actionPrimary : .textMuted,
                                  weight: on ? .semibold : .regular)
                            if let badge = item.badge {
                                Text("\(badge)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Color.actionPrimary)
                                    .clipShape(Capsule())
                                    .offset(x: 10, y: -6)
                            }
                        }
                        Text(item.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(on ? Color.actionPrimary : Color.textMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: Space.tabBarH)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .barSurface()
        .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }
    }
}
