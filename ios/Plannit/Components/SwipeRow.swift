import SwiftUI

// SwipeRow — a card with one destructive action hidden behind it, revealed by
// swiping the row across. The lists in Plannit are LazyVStacks of design-system
// cards rather than a UIKit `List`, so `.swipeActions` isn't available to us;
// this keeps the same gesture and feel.

struct SwipeRow<Content: View>: View {
    let title: String
    var icon: String = "trash-2"
    var tint: Color = .statusDanger
    let action: () -> Void
    @ViewBuilder var content: Content

    @State private var offset: CGFloat = 0
    @State private var open = false

    private let width: CGFloat = 104
    private let trigger: CGFloat = 52

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: {
                close()
                action()
            }) {
                VStack(spacing: 4) {
                    PIcon(icon, size: 18, color: .white, weight: .semibold)
                    Text(title).textStyle(.caption, color: .white)
                }
                .frame(width: width)
                .frame(maxHeight: .infinity)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }
            .buttonStyle(.plain)
            .opacity(offset < -6 ? 1 : 0)

            content
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 14, coordinateSpace: .local)
                        .onChanged { value in
                            // Horizontal drags only, so the scroll view keeps
                            // vertical movement.
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            let base = open ? -width : 0
                            offset = min(0, max(-width - 24, base + value.translation.width))
                        }
                        .onEnded { _ in
                            withAnimation(Motion.base) {
                                open = offset < -trigger
                                offset = open ? -width : 0
                            }
                        }
                )
        }
        .animation(Motion.fast, value: offset)
    }

    private func close() {
        withAnimation(Motion.base) { offset = 0; open = false }
    }
}
