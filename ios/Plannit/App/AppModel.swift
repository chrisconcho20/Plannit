import SwiftUI

// App-wide state. In demo mode (no Supabase config) the app runs entirely on
// sample data. In live mode it signs in with Apple and uploads privacy-safe
// busy blocks so the date-finder can run over real availability.

@MainActor
final class AppModel: ObservableObject {
    @Published var signedIn = false
    @Published var userId: String?
    @Published var calendarConnected = false
    @Published var calendarDenied = false
    @Published var deviceEvents: [DeviceEvent] = []

    private let calendar = CalendarService()
    private var appleCoordinator: AppleSignInCoordinator?

    var isLiveBackend: Bool { Config.isLiveBackend }

    // MARK: Auth
    /// Real Sign in with Apple → Supabase session. Returns false on cancel/failure.
    func signInWithApple() async -> Bool {
        let coordinator = AppleSignInCoordinator()
        appleCoordinator = coordinator  // retain for the duration of the flow
        do {
            let result = try await coordinator.signIn()
            let uid = try await SupabaseClient.shared.signInWithApple(idToken: result.idToken, nonce: result.nonce)
            userId = uid
            signedIn = true
            return true
        } catch {
            return false
        }
    }

    // MARK: Calendar
    func connectCalendar() async {
        let granted = await calendar.requestAccess()
        calendarConnected = granted
        calendarDenied = !granted
        if granted {
            deviceEvents = calendar.fetchDeviceEvents()
            await uploadBusyBlocksIfLive()
        }
    }

    func refreshCalendar() {
        guard calendarConnected else { return }
        deviceEvents = calendar.fetchDeviceEvents()
    }

    /// Upload merged busy intervals (no titles) so group availability can be computed.
    private func uploadBusyBlocksIfLive() async {
        guard SupabaseClient.shared.isConfigured, SupabaseClient.shared.isSignedIn,
              let uid = userId else { return }
        let iso = ISO8601DateFormatter()
        let blocks = calendar.busyIntervals().map {
            BusyBlockInsert(user_id: uid,
                            start_at: iso.string(from: $0.start),
                            end_at: iso.string(from: $0.end))
        }
        guard !blocks.isEmpty else { return }
        try? await SupabaseClient.shared.insert("busy_blocks", values: blocks)
    }
}
