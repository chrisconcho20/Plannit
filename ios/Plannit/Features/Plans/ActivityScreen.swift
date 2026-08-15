import SwiftUI

// ActivityScreen — what everyone else has been doing. Votes, plans, shares,
// friend requests and joins, in one list.
//
// Built from `my_activity()`, which derives the feed from rows we already have
// rather than writing an events table. Nothing here is tappable on purpose: a
// row that looks like a link and goes nowhere is worse than a row that doesn't.
// (Deep links into the plan are the obvious next step.)

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
                               message: "Votes, new plans and shared events land here as your groups get going.")
                } else {
                    VStack(spacing: Space.gapInline) {
                        ForEach(model.activity) { item in
                            row(item)
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
            .background(.ultraThinMaterial)
        }
        .refreshable { await model.refreshActivity() }
        .liveRefresh(every: 30) { await model.refreshActivity() }
        // Opening the screen is what "seen" means — no separate dismiss button.
        .onAppear { model.markActivitySeen() }
    }

    private func row(_ item: PActivity) -> some View {
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
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([item.sentence, item.subtitle, item.when]
                                .compactMap { $0 }.filter { !$0.isEmpty }
                                .joined(separator: ", "))
    }
}
