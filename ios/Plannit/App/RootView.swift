import SwiftUI

enum Tab: Hashable { case calendar, groups, plans, you }

// Top-level flow: onboarding -> tabbed app, with the FAB, tab bar and toast.
struct RootView: View {
    enum Flow { case welcome, connect, app }

    @StateObject private var model = AppModel()
    @State private var flow: Flow = .welcome
    @State private var tab: Tab = .calendar
    @State private var showNewPlan = false
    @State private var showNewGroup = false
    @State private var toast: String?

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            switch flow {
            case .welcome:
                WelcomeView(
                    onStart: {
                        if Config.isLiveBackend {
                            Task { @MainActor in if await model.signInWithApple() { flow = .connect } }
                        } else {
                            flow = .connect
                        }
                    },
                    onSignIn: { flow = .app }
                )
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
        .sheet(isPresented: $showNewPlan) {
            NewPlanSheet(groups: model.groups) { name, group in
                showNewPlan = false
                tab = .plans
                showToast("\(name) sent to \(group) — 4 have voted already")
            }
        }
        .sheet(isPresented: $showNewGroup) { NewGroupSheet() }
        .animation(Motion.base, value: flow)
    }

    private var appShell: some View {
        ZStack(alignment: .bottomTrailing) {
            tabContent
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    PlannitTabBar(selection: $tab)
                }

            if tab != .you {
                IconButton(icon: "plus", variant: .primary, size: 58, iconSize: 26,
                           accessibilityLabel: "New plan") {
                    showNewPlan = tab != .groups
                    showNewGroup = tab == .groups
                }
                .padding(.trailing, Space.gutter)
                .padding(.bottom, Space.tabBarH + 30)
            }

            if let toast {
                Toast(text: toast)
                    .padding(.horizontal, Space.gutter)
                    .padding(.bottom, Space.tabBarH + 24)
                    .frame(maxWidth: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task { await model.loadData() }
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

    private struct Item { let tab: Tab; let label: String; let icon: String; let badge: Int? }
    private let items: [Item] = [
        .init(tab: .calendar, label: "Calendar", icon: "calendar-days", badge: nil),
        .init(tab: .groups, label: "Groups", icon: "users", badge: nil),
        .init(tab: .plans, label: "Plans", icon: "sparkles", badge: 2),
        .init(tab: .you, label: "You", icon: "user", badge: nil),
    ]

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(items, id: \.tab) { item in
                let on = item.tab == selection
                Button { withAnimation(Motion.fast) { selection = item.tab } } label: {
                    VStack(spacing: 3) {
                        ZStack(alignment: .topTrailing) {
                            PIcon(item.icon, size: 24, color: on ? .actionPrimary : .textFaint, weight: on ? .semibold : .regular)
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
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(on ? Color.actionPrimary : .textFaint)
                    }
                    .frame(maxWidth: .infinity, minHeight: Space.tabBarH)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }
    }
}
