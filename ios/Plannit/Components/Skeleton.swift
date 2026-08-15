import SwiftUI

// Skeleton — the shape of what's coming, while it comes.
//
// Only ever shown on a *first* load, when there's genuinely nothing to display.
// A refresh with content already on screen keeps the content: replacing a list
// you're reading with grey boxes is worse than a half-second of stale data.
//
// Hidden from VoiceOver entirely — announcing "loading, loading, loading" five
// times is noise. The container says "Loading" once instead.

struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color.sunk)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

/// A card-shaped placeholder matching the rough proportions of EventCard and
/// GroupCard, so the layout doesn't jump when the real thing arrives.
struct SkeletonCard: View {
    var body: some View {
        PlannitCard(elevation: 1, padding: 0) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.sunk)
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBar(width: 150, height: 14)
                    SkeletonBar(width: 96)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }
}

/// `count` placeholder cards with a slow pulse.
struct SkeletonList: View {
    var count: Int = 3
    @State private var dim = false

    var body: some View {
        VStack(spacing: Space.gapList) {
            ForEach(0..<count, id: \.self) { _ in SkeletonCard() }
        }
        .opacity(dim ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: dim)
        .onAppear { dim = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }
}
