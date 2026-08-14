import SwiftUI

// LiveRefresh — keep what's on screen current while you're looking at it.
//
// A stopgap with a deliberate shape: when Broadcast from Database lands
// (decision D-16), the transport changes but the call sites don't — a screen
// still just says "keep me fresh". Until then this is most of the perceived
// benefit for none of the protocol risk.
//
// Two things keep it cheap: `.task` is cancelled the moment the view leaves the
// screen, and keying it on `scenePhase` stops the loop dead when the app
// backgrounds (where iOS would suspend us anyway) and restarts it on return.

extension View {
    func liveRefresh(every seconds: Double = 10, _ action: @escaping () async -> Void) -> some View {
        modifier(LiveRefreshModifier(seconds: seconds, action: action))
    }
}

private struct LiveRefreshModifier: ViewModifier {
    let seconds: Double
    let action: () async -> Void

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await action()
            }
        }
    }
}
