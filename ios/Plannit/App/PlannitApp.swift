import SwiftUI
import UIKit

/// APNs hands the device token to the app delegate and nowhere else, so SwiftUI
/// needs one. It forwards to PushService and holds no state of its own.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in PushService.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in PushService.shared.didFailToRegister(error) }
    }
}

@main
struct PlannitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // First, so a crash during launch is reported too.
        CrashReporting.start()
    }

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
