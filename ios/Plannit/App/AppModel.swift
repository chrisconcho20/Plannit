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

    // Screen data — seeded with sample data so demo mode works with no loading.
    @Published var groups: [PGroup] = Sample.groups
    @Published var events: [PEvent] = Sample.events
    @Published var proposals: [PProposal] = Sample.proposals

    private let calendar = CalendarService()
    private var appleCoordinator: AppleSignInCoordinator?

    nonisolated init() {}

    var isLiveBackend: Bool { Config.isLiveBackend }

    /// Load screen data. Demo mode keeps the sample seed; live mode pulls from Supabase.
    func loadData() async {
        guard Config.isLiveBackend, signedIn else { return }
        let repo = SupabaseRepository()
        do {
            let g = try await repo.fetchGroups()
            let e = try await repo.fetchEvents()
            let p = try await repo.fetchProposals()
            groups = g
            events = e
            proposals = p
        } catch {
            // Keep whatever we have (sample seed) on failure.
        }
    }

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

    /// Dev email/password sign-in (for browser/simulator live testing).
    func signInWithEmail(_ email: String, _ password: String) async -> Bool {
        do {
            let uid = try await SupabaseClient.shared.signInWithEmail(email, password: password)
            userId = uid
            signedIn = true
            await loadData()
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
