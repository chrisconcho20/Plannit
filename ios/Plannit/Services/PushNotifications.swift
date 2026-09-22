import Foundation
import UIKit
import UserNotifications

// PushNotifications — the device half of APNs.
//
// The server half already exists (`send-push`, the 0004 triggers, the APNs
// signer). This registers the device, keeps its token row current, and turns a
// tap into a screen. Nothing here runs in demo mode: without a signed-in user
// there is no row to write.
//
// What the device tells the server is a token, an environment, and two
// booleans — which categories this device wants. Preferences live on the token
// row rather than on the profile because they describe a *device*: a push
// muted on the phone shouldn't be muted on an iPad that the same person adds
// later.

/// Which pushes this device wants, and whether this phone shares availability
/// at all. Stored per device: a push muted here shouldn't be muted on another
/// phone the same person signs in on. The two notification flags are mirrored
/// to `device_tokens` so the sender skips the device, rather than delivering a
/// push the app then silently drops.
///
/// `object(forKey:)` rather than `bool(forKey:)` throughout: an unset default
/// has to read as on, and `bool(forKey:)` cannot tell unset from false.
enum PushPreference {
    static let dateFoundKey = "plannit.push.dateFound"
    static let invitesKey = "plannit.push.invites"

    /// "A date was found" — the scheduler landed on a time for a group.
    static var dateFound: Bool {
        (UserDefaults.standard.object(forKey: dateFoundKey) as? Bool) ?? true
    }
    /// "Invites & requests" — shared events, friend requests and their answers.
    static var invites: Bool {
        (UserDefaults.standard.object(forKey: invitesKey) as? Bool) ?? true
    }
}

/// Whether this phone uploads busy blocks. Off means the date finder reports
/// "couldn't check" for you rather than treating you as free — see D-19.
enum AvailabilitySharing {
    static let key = "plannit.shareAvailability"

    static var isOn: Bool {
        (UserDefaults.standard.object(forKey: key) as? Bool) ?? true
    }
}

/// Where a tapped notification should land.
enum PushDestination: Equatable {
    case group(String)
    case event(String)
    case friends
}

@MainActor
final class PushService: NSObject, ObservableObject {
    static let shared = PushService()

    /// Set when a notification is tapped, cleared once the app has navigated.
    @Published private(set) var destination: PushDestination?

    private var deviceToken: String?
    private static let tokenKey = "plannit.apnsToken"

    /// Sandbox for a development build, production for TestFlight and the App
    /// Store. APNs treats them as separate servers with separate tokens, so the
    /// row has to say which one this token belongs to.
    private var environment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    /// Call once at launch. Registering without asking is deliberate: iOS only
    /// shows the permission prompt when we ask for authorization, and a device
    /// already granted it should reconnect silently after a reinstall.
    func start() {
        UNUserNotificationCenter.current().delegate = self
        deviceToken = UserDefaults.standard.string(forKey: Self.tokenKey)
        Task {
            guard await isAuthorized else { return }
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    var isAuthorized: Bool {
        get async {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
        }
    }

    /// Ask, then register if allowed. Returns what the person chose, so the
    /// caller can say something useful when they decline.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        if granted { UIApplication.shared.registerForRemoteNotifications() }
        Log.push("authorization granted: \(granted)")
        return granted
    }

    func didRegister(deviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        UserDefaults.standard.set(token, forKey: Self.tokenKey)
        Log.push("registered a device token")
        Task { await syncToken() }
    }

    func didFailToRegister(_ error: Error) {
        Log.push("registration failed")
    }

    /// Write this device's row. Safe to call whenever the session or the
    /// preferences change: the token is unique, so this is an upsert.
    func syncToken() async {
        guard SupabaseClient.shared.isConfigured, SupabaseClient.shared.isSignedIn,
              let userId = SupabaseClient.shared.userId, let token = deviceToken else { return }
        do {
            try await SupabaseClient.shared.upsert(
                "device_tokens",
                values: DeviceTokenUpsert(
                    user_id: userId, token: token, environment: environment,
                    notify_date_found: PushPreference.dateFound,
                    notify_invites: PushPreference.invites),
                onConflict: "token")
            Log.push("token row is current")
        } catch {
            // Best-effort: the next launch or preference change tries again.
            Log.push("token upsert failed")
        }
    }

    /// Sign-out drops the row, so the next person to use this phone doesn't
    /// receive the last one's notifications.
    func forgetDevice() async {
        guard let token = deviceToken, SupabaseClient.shared.isConfigured else { return }
        try? await SupabaseClient.shared.delete("device_tokens", match: ["token": "eq.\(token)"])
        Log.push("token row removed")
    }

    func clearDestination() { destination = nil }

    /// A payload names one of the things the catalog can point at
    /// (docs/backend/push-notifications.md). Anything else is ignored rather
    /// than guessed at.
    private func destination(from userInfo: [AnyHashable: Any]) -> PushDestination? {
        if let id = userInfo["eventId"] as? String { return .event(id) }
        if let id = userInfo["groupId"] as? String { return .group(id) }
        if userInfo["friends"] != nil { return .friends }
        return nil
    }
}

extension PushService: UNUserNotificationCenterDelegate {
    /// Foreground: show it. The app is a calendar, and a date being found while
    /// you're looking at the group it's for is worth a banner.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            destination = destination(from: userInfo)
        }
    }
}
