import SwiftUI

// ActivityScreen — what everyone else has been doing. Invitations, answers to
// your plans, shares, friend requests and joins, in one list.
//
// Built from `my_activity()`, which derives the feed from rows we already have
// rather than writing an events table.
//
// Rows go somewhere now (`event_id`, migration 0015) — but only when there's
// something to open. A row whose event has since been deleted, or which the
// feed has no target for, renders as plain text rather than a link that shrugs:
// a row that looks tappable and isn't is worse than one that never pretended.

struct ActivityScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if model.firstLoad(of: model.activity) {
                    SkeletonList(count: 4).padding(.horizontal, Space.gutter)
                } else if model.activity.isEmpty {
                    EmptyState(icon: "bell", title: "All quiet",
                               message: "Invitations, answers to your plans and shared events land here as your groups get going.")
                } else {
                    VStack(spacing: Space.gapInline) {
                        ForEach(model.activity) { item in
                            switch target(for: item) {
                            case .event(let event):
                                NavigationLink(value: event) { row(item, tappable: true) }
                                    .buttonStyle(.plain)
                            case .group(let group):
                                NavigationLink(value: group) { row(item, tappable: true) }
                                    .buttonStyle(.plain)
                            case .friends:
                                NavigationLink(value: YouRoute.friends) {
                                    row(item, tappable: true)
                                }
                                .buttonStyle(.plain)
                            case .none:
                                row(item)
                            }
                        }
                    }
                    .padding(.horizontal, Space.gutter)
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
                Text("Activity").textStyle(.title3, color: .textStrong)
                Spacer()
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 6)
            .barSurface()
        }
        // The Plans stack already resolves PEvent; these two are ours.
        .navigationDestination(for: PGroup.self) { GroupDetailView(group: $0) }
        .navigationDestination(for: YouRoute.self) { _ in FriendsScreen() }
        .refreshable { await model.refreshActivity() }
        .liveRefresh(every: model.pollSeconds) { await model.refreshActivity() }
        // Opening the screen is what "seen" means — no separate dismiss button.
        .onAppear { model.markActivitySeen() }
    }

    /// Where a row goes. Resolved against what's loaded, so a plan that's been
    /// deleted — or one shared into a group you've since left — degrades to
    /// plain text instead of a dead end.
    private enum Target { case event(PEvent), group(PGroup), friends }

    private func target(for item: PActivity) -> Target? {
        if let id = item.eventId, let event = model.events.first(where: { $0.id == id }) {
            return .event(event)
        }
        if item.kind == .friendRequest { return .friends }
        if let id = item.groupId, let group = model.groups.first(where: { $0.id == id }) {
            return .group(group)
        }
        return nil
    }

    private func row(_ item: PActivity, tappable: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(item.hue.soft).frame(width: 36, height: 36)
                .overlay(PIcon(item.icon, size: 17, color: item.hue.color, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.sentence).textStyle(.body, color: .textStrong)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle).textStyle(.caption, color: .textMuted)
                        Text("·").foregroundStyle(Color.textFaint)
                    }
                    Text(item.when).textStyle(.caption, color: .textFaint)
                }
            }
            Spacer(minLength: 0)
            if tappable {
                PIcon("chevron-right", size: 16, color: .textFaint).padding(.top, 10)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([item.sentence, item.subtitle, item.when]
                                .compactMap { $0 }.filter { !$0.isEmpty }
                                .joined(separator: ", "))
        .accessibilityAddTraits(tappable ? .isButton : [])
    }
}
