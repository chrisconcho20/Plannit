import SwiftUI

// Bar backgrounds — the tab bar, sheet footers, and the little top bars that
// float over scrolling content.
//
// These were all `.background(.ultraThinMaterial)`. System materials adapt to
// the *device's* colour scheme, but every colour token in this app is a literal
// from a light, warm palette (`Color+Tokens.swift`). On a phone set to Dark
// Mode the material turned near-black while the icons stayed `ink400` — a warm
// mid-grey chosen for contrast against paper — and the bottom bar became
// unreadable.
//
// Two fixes, and both are needed. The app declares itself light until there's a
// real dark palette (`RootView`), and bars paint their own light surface rather
// than inheriting one. Belt and braces on purpose: the second one also fixes
// the ordinary light-mode case, where a material over dark photo-heavy content
// could still dim the bar.

extension View {
    /// A bar that floats over content: light, legible, with a whisper of the
    /// blur that made the material worth using in the first place.
    func barSurface() -> some View {
        background {
            Color.surface.opacity(0.94)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
        }
    }
}
