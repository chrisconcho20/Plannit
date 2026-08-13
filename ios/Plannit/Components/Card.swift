import SwiftUI

// Card — from design-system/components/core/Card.jsx. Rounded surface with elevation.

struct PlannitCard<Content: View>: View {
    var elevation: Int = 1
    var padding: CGFloat = Space.card
    var cornerRadius: CGFloat = Radius.card
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.hairline, lineWidth: 1)
            )
            .elevation(elevation)
    }
}
