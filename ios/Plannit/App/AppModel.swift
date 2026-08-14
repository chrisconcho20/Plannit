import SwiftUI

// App-wide state. In demo mode (no Supabase config) the app runs entirely on
// sample data. In live mode it signs in with Apple and uploads privacy-safe
// busy blocks so the date-finder can run over real availability.

@MainActor
final class AppModel: ObservableObject {
    @Published var signedIn = false
    @Published var userId: String?
    @Published var userEmail: String?
    @Published var displayName: String = Sample.me
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

    // MARK: Profile

    /// Read your own profile row. A blank `display_name` (the default for a user
    /// created straight in the dashboard) is filled in from the email, so you
    /// don't show up nameless to everyone else in your groups.
    func loadProfile() async {
        guard Config.isLiveBackend, let uid = userId else { return }
        userEmail = SupabaseClient.shared.userEmail
        let fallback = (userEmail?.split(separator: "@").first).map(String.init) ?? "You"
        do {
            let rows: [ProfileDTO] = try await SupabaseClient.shared.select(
                "profiles", columns: "id,display_name,timezone", query: ["id": "eq.\(uid)"])
            let name = rows.first?.display_name ?? ""
            if name.isEmpty {
                await updateDisplayName(fallback.capitalized)
            } else {
                displayName = name
            }
        } catch {
            displayName = fallback.capitalized
        }
    }

    /// Rename yourself everywhere — group members see this name.
    @discardableResult
    func updateDisplayName(_ name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard Config.isLiveBackend, let uid = userId else {
            displayName = trimmed          // demo mode: local only
            return true
        }
        do {
            try await SupabaseClient.shared.update(
                "profiles", values: DisplayNameUpdate(display_name: trimmed),
                match: ["id": "eq.\(uid)"])
            displayName = trimmed
            await loadData()               // group member lists carry the name
            return true
        } catch {
            return false
        }
    }

    // MARK: Events

    /// Create an event on your own calendar. Private until it's shared.
    @discardableResult
    func createEvent(title: String, start: Date, minutes: Int, location: String) async -> Bool {
        let place = location.isEmpty ? nil : location
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))

        guard Config.isLiveBackend, let uid = userId else {
            let tf = DateFormatter(); tf.dateFormat = "h:mm a"
            events.append(PEvent(id: UUID().uuidString, start: start, title: title,
                                 time: tf.string(from: start), location: place,
                                 hue: GroupHue.forName(title), icon: "calendar"))
            return true
        }

        let iso = ISO8601DateFormatter()
        do {
            try await SupabaseClient.shared.insert("events", values: EventInsert(
                owner_id: uid, title: title, location: place,
                start_at: iso.string(from: start), end_at: iso.string(from: end),
                timezone: TimeZone.current.identifier, source: "plannit"))
            await loadData()
            return true
        } catch {
            return false
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
            await loadProfile()
            await loadData()
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
            await loadProfile()
            await loadData()
            return true
        } catch {
            return false
        }
    }

    /// Create a group. Persists to Supabase in live mode; appends locally in demo.
    func createGroup(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if Config.isLiveBackend, let uid = userId {
            do {
                try await SupabaseClient.shared.insert(
                    "groups", values: NewGroupInsert(name: trimmed, owner_id: uid))
                await loadData()   // reload so the new group (and its owner membership) appears
            } catch {
                // leave existing groups on failure
            }
        } else {
            groups.append(PGroup(id: UUID().uuidString, name: trimmed,
                                 hue: GroupHue.forName(trimmed), members: [], note: ""))
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
