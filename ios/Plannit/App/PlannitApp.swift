import SwiftUI

@main
struct PlannitApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.actionPrimary)
        }
        // Availability goes stale while the app is shut: EKEventStoreChanged
        // only fires when we're running. iOS grants these at its own discretion,
        // so this narrows the window rather than closing it.
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await BackgroundRefresh.run()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { BackgroundRefresh.schedule() }
        }
    }
}
