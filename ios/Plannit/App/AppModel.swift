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
            let e = try await repo.fetchEvents(groups: g)
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

    // MARK: Voting

    /// Vote for one slot. A vote is a choice, not a tally, so this replaces any
    /// vote you'd already cast on this proposal.
    @discardableResult
    func vote(for slot: PSlot, on proposal: PProposal) async -> Bool {
        guard Config.isLiveBackend, let uid = userId else {
            replaceProposal(proposal.id) {
                var p = $0
                if let old = p.myVoteSlotId { p.voteCounts[old] = max(0, (p.voteCounts[old] ?? 1) - 1) }
                p.voteCounts[slot.id, default: 0] += 1
                p.myVoteSlotId = slot.id
                p.votes = p.voteCounts.values.reduce(0, +)
                return p
            }
            return true
        }
        do {
            try await SupabaseClient.shared.delete("votes", match: [
                "proposal_id": "eq.\(proposal.id)", "user_id": "eq.\(uid)",
            ])
            try await SupabaseClient.shared.insert("votes", values: VoteInsert(
                proposal_id: proposal.id, slot_id: slot.id, user_id: uid, response: "yes"))
            await loadData()
            return true
        } catch {
            return false
        }
    }

    /// Lock a time in: mark the proposal finalized, then put the winning slot on
    /// the calendar as a real event shared with the group.
    @discardableResult
    func lockIn(slot: PSlot, on proposal: PProposal) async -> Bool {
        guard Config.isLiveBackend, let uid = userId else {
            replaceProposal(proposal.id) {
                var p = $0
                p.finalizedSlotId = slot.id
                return p
            }
            return true
        }
        do {
            try await SupabaseClient.shared.update(
                "proposals",
                values: ProposalFinalizeUpdate(finalized_slot_id: slot.id, status: "finalized"),
                match: ["id": "eq.\(proposal.id)"])

            // The event belongs to whoever locked it in, and is shared with the
            // group so everyone can see it (events are private by default).
            if let times = try await slotTimes(slot.id, proposalId: proposal.id) {
                let iso = ISO8601DateFormatter()
                let created: [EventRefDTO] = try await SupabaseClient.shared.insertReturning(
                    "events", values: EventInsert(
                        owner_id: uid, title: proposal.title, location: nil,
                        start_at: iso.string(from: times.start), end_at: iso.string(from: times.end),
                        timezone: TimeZone.current.identifier, source: "plannit"))
                if let event = created.first {
                    try await SupabaseClient.shared.insert("event_shares", values: EventShareInsert(
                        event_id: event.id, group_id: proposal.group.id))
                }
            }
            await loadData()
            return true
        } catch {
            return false
        }
    }

    /// Read the slot's real start/end back — `PSlot` only carries display strings.
    private func slotTimes(_ slotId: String, proposalId: String) async throws -> (start: Date, end: Date)? {
        let rows: [ProposalSlotDTO] = try await SupabaseClient.shared.select(
            "proposal_slots", columns: "id,start_at,end_at,score,available_user_ids",
            query: ["id": "eq.\(slotId)"])
        guard let row = rows.first,
              let start = SupabaseRepository.parseISO(row.start_at),
              let end = SupabaseRepository.parseISO(row.end_at) else { return nil }
        return (start, end)
    }

    private func replaceProposal(_ id: String, _ transform: (PProposal) -> PProposal) {
        guard let i = proposals.firstIndex(where: { $0.id == id }) else { return }
        proposals[i] = transform(proposals[i])
    }

    // MARK: Events

    /// Set exactly which groups can see an event: adds the shares you ticked,
    /// removes the ones you unticked. Sharing is the *only* way an event leaves
    /// your own calendar, so this is the whole per-group visibility pillar.
    /// RLS: only the event's owner may write shares.
    @discardableResult
    func shareEvent(_ event: PEvent, with groupIds: Set<String>) async -> Bool {
        let current = Set(event.sharedGroupIds)
        let added = groupIds.subtracting(current)
        let removed = current.subtracting(groupIds)
        guard !added.isEmpty || !removed.isEmpty else { return true }

        guard Config.isLiveBackend else {
            if let i = events.firstIndex(where: { $0.id == event.id }) {
                var e = events[i]
                e.sharedGroupIds = Array(groupIds)
                e.group = groups.first { groupIds.contains($0.id) }?.name
                e.badge = groupIds.isEmpty ? "Private" : nil
                events[i] = e
            }
            return true
        }

        do {
            if !removed.isEmpty {
                try await SupabaseClient.shared.delete("event_shares", match: [
                    "event_id": "eq.\(event.id)",
                    "group_id": "in.(\(removed.joined(separator: ",")))",
                ])
            }
            if !added.isEmpty {
                try await SupabaseClient.shared.insert("event_shares", values: added.map {
                    EventShareInsert(event_id: event.id, group_id: $0)
                })
            }
            await loadData()
            return true
        } catch {
            return false
        }
    }

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
