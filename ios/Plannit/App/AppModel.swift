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
    /// People you can add to a group. Until friend requests land this is
    /// everyone RLS lets you see: your groups' co-members.
    @Published var people: [PMember] = Sample.people

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
            let who = try await repo.fetchPeople()
            groups = g
            events = e
            proposals = p
            people = who
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
            guard let row = rows.first else {
                // No profile row (account predates the trigger) — a PATCH would
                // update nothing, so create it.
                try await SupabaseClient.shared.insert("profiles", values: ProfileInsert(
                    id: uid, display_name: fallback.capitalized,
                    timezone: TimeZone.current.identifier))
                displayName = fallback.capitalized
                return
            }
            if row.display_name.isEmpty {
                await updateDisplayName(fallback.capitalized)
            } else {
                displayName = row.display_name
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

    /// Create a group with its starting members. Persists to Supabase in live
    /// mode; appends locally in demo.
    @discardableResult
    func createGroup(name: String, members: [PMember] = []) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        guard Config.isLiveBackend, let uid = userId else {
            groups.append(PGroup(id: UUID().uuidString, name: trimmed,
                                 hue: GroupHue.forName(trimmed), members: members, note: ""))
            return true
        }

        do {
            // Read the row back for its generated id — the memberships need it.
            let created: [GroupRefDTO] = try await SupabaseClient.shared.insertReturning(
                "groups", values: NewGroupInsert(name: trimmed, owner_id: uid))
            if let group = created.first, !members.isEmpty {
                try await SupabaseClient.shared.insert("group_memberships", values: members.map {
                    MembershipInsert(group_id: group.id, user_id: $0.id, role: "member")
                })
            }
            await loadData()   // the owner membership is added by a DB trigger
            return true
        } catch {
            return false
        }
    }

    /// Add people to an existing group. RLS: owners only.
    @discardableResult
    func addMembers(to group: PGroup, members: [PMember]) async -> Bool {
        guard !members.isEmpty else { return true }
        guard Config.isLiveBackend else {
            replaceGroup(group.id) { PGroup(id: $0.id, name: $0.name, hue: $0.hue,
                                            members: $0.members + members, note: $0.note,
                                            ownerId: $0.ownerId) }
            return true
        }
        do {
            try await SupabaseClient.shared.insert("group_memberships", values: members.map {
                MembershipInsert(group_id: group.id, user_id: $0.id, role: "member")
            })
            await loadData()
            return true
        } catch {
            return false
        }
    }

    /// Remove someone from a group. RLS: the owner, or you removing yourself.
    @discardableResult
    func removeMember(_ member: PMember, from group: PGroup) async -> Bool {
        guard Config.isLiveBackend else {
            replaceGroup(group.id) { PGroup(id: $0.id, name: $0.name, hue: $0.hue,
                                            members: $0.members.filter { $0.id != member.id },
                                            note: $0.note, ownerId: $0.ownerId) }
            return true
        }
        do {
            try await SupabaseClient.shared.delete("group_memberships", match: [
                "group_id": "eq.\(group.id)", "user_id": "eq.\(member.id)",
            ])
            await loadData()
            return true
        } catch {
            return false
        }
    }

    /// Delete a group (owner) — cascades its memberships, shares and proposals.
    @discardableResult
    func deleteGroup(_ group: PGroup) async -> Bool {
        guard Config.isLiveBackend else {
            groups.removeAll { $0.id == group.id }
            return true
        }
        do {
            try await SupabaseClient.shared.delete("groups", match: ["id": "eq.\(group.id)"])
            await loadData()
            return true
        } catch {
            return false
        }
    }

    /// Leave a group you don't own.
    @discardableResult
    func leaveGroup(_ group: PGroup) async -> Bool {
        guard let uid = userId else {
            groups.removeAll { $0.id == group.id }
            return true
        }
        return await removeMember(PMember(id: uid, name: displayName), from: group)
    }

    private func replaceGroup(_ id: String, _ transform: (PGroup) -> PGroup) {
        guard let i = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[i] = transform(groups[i])
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
