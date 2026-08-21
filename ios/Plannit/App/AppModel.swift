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

    // Screen data. Demo mode starts on sample data so the app is explorable with
    // no network; live mode starts EMPTY, because showing someone else's sample
    // groups while their real ones load is a lie.
    @Published var groups: [PGroup] = Config.isLiveBackend ? [] : Sample.groups
    @Published var events: [PEvent] = Config.isLiveBackend ? [] : Sample.events
    /// People you can add to a group. Until friend requests land this is
    /// everyone RLS lets you see: your groups' co-members.
    @Published var people: [PMember] = Config.isLiveBackend ? [] : Sample.people
    /// Live-load state, so screens can say "loading" and "that failed" instead
    /// of quietly showing nothing.
    @Published var isLoading = false
    @Published var loadError: String?
    /// A one-line message for the shell to show. Writes used to fail in
    /// silence — you'd tap "remove member", nothing would happen, and there was
    /// nowhere for the reason to go.
    @Published var toast: String?

    func say(_ message: String) {
        toast = message
        let shown = message
        Task {
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            if toast == shown { toast = nil }
        }
    }

    /// Report a failed write. Returns the value it's given so call sites can
    /// stay one-liners.
    @discardableResult
    private func failed(_ ok: Bool, _ message: String) -> Bool {
        if !ok { say(message) }
        return ok
    }
    /// The group you're currently looking at, so the ＋ can act in its context
    /// instead of guessing from the tab.
    @Published var openGroup: PGroup?
    /// Accepted friends, and requests in both directions.
    @Published var friends: [PMember] = Config.isLiveBackend ? [] : Sample.people
    @Published var friendRequests: [PFriendRequest] = []
    /// Beta switch (`app_config.auto_friend_everyone`): everyone who joins is
    /// already your friend. Read from the server so the copy stops being true
    /// the moment it's switched off.
    @Published var autoFriendEveryone = false
    /// What's happened lately, and how much of it you haven't seen.
    @Published var activity: [PActivity] = Config.isLiveBackend ? [] : Sample.activity

    private static let seenKey = "plannit.activitySeenAt"

    /// True only when there's nothing on screen yet and we're fetching. A
    /// refresh over existing content must not blank it out.
    func firstLoad(of collection: [some Any]) -> Bool {
        isLoading && collection.isEmpty && loadError == nil
    }

    var unreadActivity: Int {
        let seen = UserDefaults.standard.double(forKey: Self.seenKey)
        guard seen > 0 else { return activity.count }
        let cutoff = Date(timeIntervalSince1970: seen)
        return activity.filter { $0.happenedAt > cutoff }.count
    }

    func markActivitySeen() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.seenKey)
        objectWillChange.send()
    }

    func refreshActivity() async {
        guard Config.isLiveBackend, signedIn else { return }
        if let fresh = try? await SupabaseRepository().fetchActivity(limit: 50) {
            activity = fresh
        }
    }

    private let calendar = CalendarService()
    private let realtime = RealtimeService()
    private var appleCoordinator: AppleSignInCoordinator?
    private var calendarObserver: NSObjectProtocol?

    nonisolated init() {}

    /// Demo mode has no session, but the going/not-going rules are all
    /// questions about a particular person — so demo gets a stable stand-in.
    func startDemoIdentity() {
        guard !Config.isLiveBackend else { return }
        userId = Sample.meId
    }

    /// EKEventStoreChanged only fires while we're running — the foreground
    /// reconcile in RootView covers everything we miss (sync-contract §Background).
    func startObservingCalendar() {
        guard calendarObserver == nil else { return }
        calendarObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.syncCalendar() }
        }
    }

    deinit {
        if let calendarObserver { NotificationCenter.default.removeObserver(calendarObserver) }
    }

    var isLiveBackend: Bool { Config.isLiveBackend }

    /// Load screen data. Demo mode keeps the sample seed; live mode pulls from
    /// Supabase and reports failure rather than swallowing it.
    func loadData() async {
        guard Config.isLiveBackend, signedIn else { return }
        isLoading = true
        defer { isLoading = false }
        let repo = SupabaseRepository()
        do {
            let g = try await repo.fetchGroups()
            let e = try await repo.fetchEvents(groups: g)
            let who = try await repo.fetchPeople()
            let mates = try await repo.fetchFriends()
            let requests = try await repo.fetchFriendRequests()
            let beta = await repo.fetchAutoFriendFlag()
            let recent = (try? await repo.fetchActivity(limit: 50)) ?? []
            groups = g
            events = e
            people = who
            friends = mates
            friendRequests = requests
            autoFriendEveryone = beta
            activity = recent
            loadError = nil
            mirrorToDeviceCalendar()   // keep the device copy in step
            await realtime.sync(groupIds: g.map(\.id))
            Log.sync("loaded: \(g.count) groups, \(e.count) events, \(mates.count) friends")
        } catch {
            loadError = Self.message(for: error)
            Log.sync("load failed: \(Self.message(for: error))")
        }
    }

    // MARK: Partial refreshes
    //
    // A full loadData() is seven round trips. A write only invalidates part of
    // the screen, and the polling loops below run every few seconds, so both use
    // the narrowest refresh that's still correct.

    // MARK: Live updates
    //
    // Broadcast tells us *that* something changed in a group; we then refresh
    // that slice. LiveRefresh polling stays on as the safety net, so a socket
    // that never connects only costs latency.
    func startRealtime() async {
        guard Config.isLiveBackend, signedIn else { return }
        realtime.onChange = { [weak self] change in
            Task { @MainActor in
                switch change {
                // `proposals` is the old slot-voting hint; group plans are
                // events now, so both mean "refresh the events".
                case .proposals, .events: await self?.refreshEvents()
                case .groups:    await self?.refreshGroups()
                }
            }
        }
        await realtime.sync(groupIds: groups.map(\.id))
    }

    func stopRealtime() async {
        await realtime.stop()
    }

    func refreshEvents() async {
        guard Config.isLiveBackend, signedIn else { return }
        if let fresh = try? await SupabaseRepository().fetchEvents(groups: groups) {
            events = fresh
            loadError = nil
            mirrorToDeviceCalendar()
        }
    }

    /// Groups carry their members, so this covers add/remove/rename too.
    func refreshGroups() async {
        guard Config.isLiveBackend, signedIn else { return }
        let repo = SupabaseRepository()
        if let fresh = try? await repo.fetchGroups() {
            groups = fresh
            loadError = nil
        }
        if let who = try? await repo.fetchPeople() { people = who }
    }

    func refreshFriends() async {
        guard Config.isLiveBackend, signedIn else { return }
        let repo = SupabaseRepository()
        if let mates = try? await repo.fetchFriends() { friends = mates }
        if let requests = try? await repo.fetchFriendRequests() { friendRequests = requests }
    }

    static func message(for error: Error) -> String {
        guard let e = error as? SupabaseError else {
            return "Couldn't reach Plannit. Check your connection."
        }
        switch e {
        case .notConfigured: return "You're signed out — sign in and try again."
        case .decoding:      return "Plannit sent something we couldn't read."
        case .http(let code, _):
            switch code {
            case 401: return "Your session expired — sign in again."
            case 403: return "You don't have access to that."
            default:  return "Plannit is having trouble (\(code))."
            }
        }
    }

    /// Pick a signed-in session back up from the Keychain on launch.
    func restoreSession() async -> Bool {
        guard Config.isLiveBackend, SupabaseClient.shared.restoreSession() else { return false }
        userId = SupabaseClient.shared.userId
        userEmail = SupabaseClient.shared.userEmail
        signedIn = true
        await loadProfile()
        await loadData()
        return true
    }

    /// Sign out: forget the session and drop every trace of the account's data.
    func signOut() {
        Task { await stopRealtime() }
        SupabaseClient.shared.signOut()
        signedIn = false
        userId = nil
        userEmail = nil
        displayName = Sample.me
        openGroup = nil
        groups = Config.isLiveBackend ? [] : Sample.groups
        events = Config.isLiveBackend ? [] : Sample.events
        people = Config.isLiveBackend ? [] : Sample.people
        friends = Config.isLiveBackend ? [] : Sample.people
        friendRequests = []
        activity = Config.isLiveBackend ? [] : Sample.activity
        loadError = nil
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
            await refreshGroups()   // group member lists carry the name
            return true
        } catch {
            return false
        }
    }

    /// Group plans you've been invited to and haven't answered. Nil when
    /// there's nothing to answer — a badge that's always lit teaches people to
    /// ignore it.
    var invitations: [PEvent] {
        events.filter { $0.needsAnswer(from: userId) }
            .sorted { $0.start < $1.start }
    }

    /// Group plans you said yes to, still ahead of you.
    var upcomingPlans: [PEvent] {
        let now = Date()
        return events.filter {
            $0.isGroupEvent && $0.myRsvp(userId) == true && ($0.end ?? $0.start) >= now
        }
        .sorted { $0.start < $1.start }
    }

    var plansBadge: Int? {
        let count = invitations.count
        return count > 0 ? count : nil
    }

    // MARK: Invites

    /// A link that puts someone in this group — and makes you two friends,
    /// since sending an invite is about as clear a signal as it gets.
    /// Returns nil if we couldn't make one.
    func inviteLink(for group: PGroup) async -> URL? {
        guard Config.isLiveBackend else {
            return URL(string: "https://plannit.app/i/demo")   // nothing real to share in demo
        }
        do {
            let rows: [InviteDTO] = try await SupabaseClient.shared.rpc(
                "create_group_invite", args: CreateInviteArgs(p_group: group.id))
            guard let token = rows.first?.token else { return nil }
            return Self.inviteURL(token: token)
        } catch {
            say("Couldn't make an invite link.")
            return nil
        }
    }

    /// The public landing page. An https link so it previews in a message and
    /// works for someone who hasn't installed the app; that page deep-links
    /// back into plannit://invite/<token>.
    static func inviteURL(token: String) -> URL? {
        URL(string: Config.supabaseURL)?
            .appendingPathComponent("functions/v1/invite")
            .appending(queryItems: [URLQueryItem(name: "t", value: token)])
    }

    /// Handle plannit://invite/<token>, however we were opened.
    func redeemInvite(token: String) async {
        guard Config.isLiveBackend else { return }
        guard signedIn else {
            say("Sign in first, then open the invite again.")
            return
        }
        do {
            let rows: [RedeemedInviteDTO] = try await SupabaseClient.shared.rpc(
                "redeem_invite", args: RedeemInviteArgs(p_token: token))
            await loadData()
            guard let row = rows.first else {
                say("That invite has expired.")
                return
            }
            if let name = row.group_name {
                say(row.already_member == true ? "You're already in \(name)." : "You're in \(name).")
            } else {
                say("You're now friends.")
            }
        } catch {
            say("That invite has expired or been used up.")
        }
    }

    // MARK: Friends

    var incomingRequests: [PFriendRequest] { friendRequests.filter(\.incoming) }

    /// Who you can put in a group: your friends first, then anyone else RLS
    /// already shows you (a co-member you haven't befriended). Friends are the
    /// real answer; the co-member fallback stops a group you're already in from
    /// becoming un-editable if auto-friending is switched off later.
    var addablePeople: [PMember] {
        var seen = Set(friends.map(\.id))
        return friends + people.filter { seen.insert($0.id).inserted }
    }

    /// Find someone by their exact email, so you can send them a request.
    /// Returns nil when there's no such account — deliberately indistinguishable
    /// from "exists but hidden", because the lookup can't be used to fish.
    func findPerson(email: String) async -> PMember? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard Config.isLiveBackend else {
            return Sample.people.first { $0.name.lowercased().hasPrefix(trimmed.lowercased().prefix(3)) }
        }
        return try? await SupabaseRepository().findPerson(email: trimmed)
    }

    @discardableResult
    func sendFriendRequest(to person: PMember) async -> Bool {
        guard Config.isLiveBackend, let uid = userId else {
            friendRequests.append(PFriendRequest(id: UUID().uuidString, person: person,
                                                 incoming: false))
            return true
        }
        do {
            try await SupabaseClient.shared.insert("friendships", values: FriendshipInsert(
                requester_id: uid, addressee_id: person.id, status: "pending"))
            await refreshFriends()
            return true
        } catch {
            return failed(false, "Couldn't send that request.")
        }
    }

    /// Accept: the addressee flips the row to accepted (RLS lets either party
    /// update, and only the addressee is ever shown the button).
    @discardableResult
    func respond(to request: PFriendRequest, accept: Bool) async -> Bool {
        guard Config.isLiveBackend else {
            friendRequests.removeAll { $0.id == request.id }
            if accept { friends.append(request.person) }
            return true
        }
        do {
            if accept {
                try await SupabaseClient.shared.update(
                    "friendships", values: FriendshipStatusUpdate(status: "accepted"),
                    match: ["id": "eq.\(request.id)"])
            } else {
                try await SupabaseClient.shared.delete("friendships",
                                                       match: ["id": "eq.\(request.id)"])
            }
            await refreshFriends()
            return true
        } catch {
            return failed(false, "Couldn't answer that request.")
        }
    }

    /// Unfriend. The row is deleted rather than blocked — blocking is a
    /// different thing we haven't designed.
    @discardableResult
    func removeFriend(_ person: PMember) async -> Bool {
        guard Config.isLiveBackend, let uid = userId else {
            friends.removeAll { $0.id == person.id }
            return true
        }
        do {
            // The pair can be stored in either direction.
            try await SupabaseClient.shared.delete("friendships", match: [
                "requester_id": "eq.\(uid)", "addressee_id": "eq.\(person.id)",
            ])
            try await SupabaseClient.shared.delete("friendships", match: [
                "requester_id": "eq.\(person.id)", "addressee_id": "eq.\(uid)",
            ])
            await refreshFriends()
            return true
        } catch {
            return failed(false, "Couldn't remove that friend.")
        }
    }

    // MARK: Events

    /// An all-day event covers midnight to midnight whatever times were picked.
    /// Otherwise the pair is taken as given, with a floor of 15 minutes so a
    /// mis-drag can't store an event that ends before it starts.
    static func span(start: Date, end: Date, allDay: Bool) -> (Date, Date) {
        guard allDay else {
            return (start, max(end, start.addingTimeInterval(15 * 60)))
        }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: start)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        return (dayStart, dayEnd)
    }

    /// Change an event you own.
    @discardableResult
    func updateEvent(_ event: PEvent, title: String, start: Date, end: Date,
                     location: String, allDay: Bool = false,
                     repeats: RepeatRule = .never) async -> Bool {
        let place = location.isEmpty ? nil : location
        let (start, end) = Self.span(start: start, end: end, allDay: allDay)

        guard Config.isLiveBackend else {
            if let i = events.firstIndex(where: { $0.id == event.rowId }) {
                let tf = DateFormatter(); tf.dateFormat = "h:mm a"
                var e = events[i]
                e = PEvent(id: e.id, start: start, end: end, title: title,
                           time: allDay ? "All day" : tf.string(from: start),
                           location: place, group: e.group,
                           hue: e.hue, icon: e.icon, people: e.people, badge: e.badge,
                           badgeTone: e.badgeTone, source: e.source, isAllDay: allDay,
                           ownerId: e.ownerId, recurrence: repeats,
                           sharedGroupIds: e.sharedGroupIds, sharedUserIds: e.sharedUserIds)
                events[i] = e
            }
            return true
        }

        let iso = ISO8601DateFormatter()
        do {
            try await SupabaseClient.shared.update("events", values: EventUpdate(
                title: title, location: place,
                start_at: iso.string(from: start), end_at: iso.string(from: end),
                all_day: allDay, recurrence_rule: Recurrence.rrule(for: repeats)),
                match: ["id": "eq.\(event.rowId)"])
            await refreshEvents()
            return true
        } catch {
            return false
        }
    }

    /// Delete an event you own. Soft-deleted server-side so the tombstone can
    /// propagate to other devices (sync-contract §Deltas); the mirror drops it
    /// from the device calendar on the next pass.
    @discardableResult
    func deleteEvent(_ event: PEvent) async -> Bool {
        guard Config.isLiveBackend else {
            events.removeAll { $0.id == event.rowId }
            return true
        }
        do {
            let iso = ISO8601DateFormatter()
            try await SupabaseClient.shared.update(
                "events", values: EventTombstone(deleted_at: iso.string(from: Date())),
                match: ["id": "eq.\(event.rowId)"])
            await refreshEvents()
            return true
        } catch {
            return failed(false, "Couldn't delete that event.")
        }
    }

    /// Rename a group (owner only, per RLS) and remember its colour.
    @discardableResult
    func renameGroup(_ group: PGroup, to name: String, hue: GroupHue? = nil) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if let hue { GroupHue.pick(hue, for: group.id) }

        guard Config.isLiveBackend else {
            replaceGroup(group.id) {
                PGroup(id: $0.id, name: trimmed, hue: hue ?? $0.hue, members: $0.members,
                       note: $0.note, ownerId: $0.ownerId)
            }
            return true
        }
        do {
            try await SupabaseClient.shared.update("groups", values: GroupRename(name: trimmed),
                                                   match: ["id": "eq.\(group.id)"])
            await refreshGroups()
            return true
        } catch {
            return failed(false, "Couldn't rename that group.")
        }
    }

    // MARK: Group plans

    /// Answer an invitation. Saying yes is what puts it on your calendar — the
    /// database grants you a personal share, and your calendar reads shares.
    /// Applied locally first so the tap lands immediately.
    @discardableResult
    func rsvp(to event: PEvent, going: Bool) async -> Bool {
        guard let uid = userId else { return false }
        let rollback = events
        applyRsvp(going, to: event.rowId, by: uid)

        guard Config.isLiveBackend else { return true }
        do {
            let _: [EmptyRow] = try await SupabaseClient.shared.rpc(
                "rsvp_to_event", args: RsvpArgs(p_event: event.rowId, p_going: going))
            await refreshEvents()
            return true
        } catch {
            events = rollback
            return failed(false, "Couldn't save your answer. Try again.")
        }
    }

    private func applyRsvp(_ going: Bool, to eventId: String, by uid: String) {
        guard let i = events.firstIndex(where: { $0.id == eventId }) else { return }
        var e = events[i]
        e.rsvps[uid] = going
        if going {
            if !e.sharedUserIds.contains(uid) { e.sharedUserIds.append(uid) }
        } else {
            e.sharedUserIds.removeAll { $0 == uid }
        }
        events[i] = e
    }

    /// Send a time the finder suggested to a group. The event is yours; sharing
    /// it with the group is what makes it an invitation rather than a private
    /// plan, and everyone else answers going or not.
    @discardableResult
    func proposeGroupEvent(title: String, start: Date, end: Date,
                           to group: PGroup) async -> Bool {
        guard Config.isLiveBackend, let uid = userId else {
            events.append(PEvent(id: UUID().uuidString, start: start, end: end,
                                 title: title, time: "", group: group.name,
                                 hue: group.hue, icon: "calendar",
                                 ownerId: userId, rsvps: [userId ?? "me": true],
                                 sharedGroupIds: [group.id]))
            return true
        }
        let iso = ISO8601DateFormatter()
        do {
            let created: [EventRefDTO] = try await SupabaseClient.shared.insertReturning(
                "events", values: EventInsert(
                    owner_id: uid, title: title, location: nil,
                    start_at: iso.string(from: start), end_at: iso.string(from: end),
                    all_day: false, timezone: TimeZone.current.identifier,
                    source: "plannit", recurrence_rule: nil))
            guard let event = created.first else {
                return failed(false, "Couldn't send that to the group.")
            }
            try await SupabaseClient.shared.insert("event_shares", values: EventShareInsert(
                event_id: event.id, group_id: group.id))
            // Whoever picked the time is going — that's what picking it meant.
            let _: [EmptyRow] = try await SupabaseClient.shared.rpc(
                "rsvp_to_event", args: RsvpArgs(p_event: event.id, p_going: true))
            await refreshEvents()
            return true
        } catch {
            return failed(false, "Couldn't send that to the group.")
        }
    }

    /// Set exactly which groups can see an event: adds the shares you ticked,
    /// removes the ones you unticked. Sharing is the *only* way an event leaves
    /// your own calendar, so this is the whole per-group visibility pillar.
    /// RLS: only the event's owner may write shares.
    @discardableResult
    func shareEvent(_ event: PEvent, with groupIds: Set<String>,
                    people personIds: Set<String> = []) async -> Bool {
        let currentGroups = Set(event.sharedGroupIds)
        let currentPeople = Set(event.sharedUserIds)
        let addedGroups = groupIds.subtracting(currentGroups)
        let removedGroups = currentGroups.subtracting(groupIds)
        let addedPeople = personIds.subtracting(currentPeople)
        let removedPeople = currentPeople.subtracting(personIds)
        guard !addedGroups.isEmpty || !removedGroups.isEmpty
                || !addedPeople.isEmpty || !removedPeople.isEmpty else { return true }

        guard Config.isLiveBackend else {
            if let i = events.firstIndex(where: { $0.id == event.rowId }) {
                var e = events[i]
                e.sharedGroupIds = Array(groupIds)
                e.sharedUserIds = Array(personIds)
                e.group = groups.first { groupIds.contains($0.id) }?.name
                e.badge = e.isPrivate ? "Private" : nil
                events[i] = e
            }
            return true
        }

        do {
            if !removedGroups.isEmpty {
                try await SupabaseClient.shared.delete("event_shares", match: [
                    "event_id": "eq.\(event.rowId)",
                    "group_id": "in.(\(removedGroups.joined(separator: ",")))",
                ])
            }
            if !removedPeople.isEmpty {
                try await SupabaseClient.shared.delete("event_shares", match: [
                    "event_id": "eq.\(event.rowId)",
                    "shared_user_id": "in.(\(removedPeople.joined(separator: ",")))",
                ])
            }
            if !addedGroups.isEmpty {
                try await SupabaseClient.shared.insert("event_shares", values: addedGroups.map {
                    EventShareInsert(event_id: event.rowId, group_id: $0)
                })
            }
            if !addedPeople.isEmpty {
                try await SupabaseClient.shared.insert("event_shares", values: addedPeople.map {
                    EventUserShareInsert(event_id: event.rowId, shared_user_id: $0)
                })
            }
            await refreshEvents()
            return true
        } catch {
            return failed(false, "Couldn't update sharing.")
        }
    }

    /// Create an event on your own calendar. Private unless `shareWith` is set,
    /// which is how an event made from inside a group reaches that group.
    @discardableResult
    func createEvent(title: String, start: Date, end: Date, location: String,
                     allDay: Bool = false, repeats: RepeatRule = .never,
                     shareWith group: PGroup? = nil) async -> Bool {
        let place = location.isEmpty ? nil : location
        let (start, end) = Self.span(start: start, end: end, allDay: allDay)

        guard Config.isLiveBackend, let uid = userId else {
            let tf = DateFormatter(); tf.dateFormat = "h:mm a"
            events.append(PEvent(id: UUID().uuidString, start: start, end: end, title: title,
                                 time: allDay ? "All day" : tf.string(from: start),
                                 location: place,
                                 group: group?.name,
                                 hue: group?.hue ?? GroupHue.forName(title), icon: "calendar",
                                 badge: group == nil ? "Private" : nil,
                                 isAllDay: allDay,
                                 recurrence: repeats,
                                 sharedGroupIds: group.map { [$0.id] } ?? []))
            return true
        }

        let iso = ISO8601DateFormatter()
        do {
            // Read the row back so the share can name it.
            let created: [EventRefDTO] = try await SupabaseClient.shared.insertReturning(
                "events", values: EventInsert(
                    owner_id: uid, title: title, location: place,
                    start_at: iso.string(from: start), end_at: iso.string(from: end),
                    all_day: allDay,
                    timezone: TimeZone.current.identifier, source: "plannit",
                    recurrence_rule: Recurrence.rrule(for: repeats)))
            if let group, let event = created.first {
                try await SupabaseClient.shared.insert("event_shares", values: EventShareInsert(
                    event_id: event.id, group_id: group.id))
            }
            await refreshEvents()
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

    /// Create an account. Returns nil on success, or a message to show.
    ///
    /// The profile is created by the DB trigger from the metadata we send, so a
    /// new account is named and auto-friended before it ever reaches a screen.
    func signUp(email: String, password: String, name: String) async -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return "Tell us your name first." }
        guard password.count >= 6 else { return "Use at least 6 characters for the password." }

        do {
            let result = try await SupabaseClient.shared.signUp(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password, displayName: trimmedName)
            switch result {
            case .signedIn:
                userId = SupabaseClient.shared.userId
                userEmail = SupabaseClient.shared.userEmail
                displayName = trimmedName
                signedIn = true
                await loadProfile()
                await loadData()
                await startRealtime()
                return nil
            case .needsEmailConfirmation:
                return "Check \(email) for a confirmation link, then sign in."
            }
        } catch let SupabaseError.http(_, body) {
            // GoTrue's messages are decent; surface the useful ones plainly.
            if body.localizedCaseInsensitiveContains("already registered")
                || body.localizedCaseInsensitiveContains("already been registered") {
                return "That email already has an account — sign in instead."
            }
            if body.localizedCaseInsensitiveContains("invalid email") {
                return "That doesn't look like an email address."
            }
            if body.localizedCaseInsensitiveContains("password") {
                return "That password is too weak — try a longer one."
            }
            return "Couldn't create that account. Try again."
        } catch {
            return "Couldn't reach Plannit. Check your connection."
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
    func createGroup(name: String, members: [PMember] = [], hue: GroupHue? = nil) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        guard Config.isLiveBackend, let uid = userId else {
            let id = UUID().uuidString
            if let hue { GroupHue.pick(hue, for: id) }
            groups.append(PGroup(id: id, name: trimmed,
                                 hue: hue ?? GroupHue.forName(trimmed), members: members, note: ""))
            return true
        }

        do {
            // Read the row back for its generated id — the memberships need it.
            let created: [GroupRefDTO] = try await SupabaseClient.shared.insertReturning(
                "groups", values: NewGroupInsert(name: trimmed, owner_id: uid))
            if let group = created.first, let hue { GroupHue.pick(hue, for: group.id) }
            if let group = created.first, !members.isEmpty {
                try await SupabaseClient.shared.insert("group_memberships", values: members.map {
                    MembershipInsert(group_id: group.id, user_id: $0.id, role: "member")
                })
            }
            await refreshGroups()   // the owner membership is added by a DB trigger
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
            await refreshGroups()
            return true
        } catch {
            return failed(false, "Couldn't add them — only the group's owner can.")
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
            await refreshGroups()
            return true
        } catch {
            return failed(false, "Couldn't remove them. Try again.")
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
            await refreshGroups()
            return true
        } catch {
            return failed(false, "Couldn't delete that group.")
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
        Log.cal("access request → \(granted ? "granted" : "denied")")
        calendarConnected = granted
        calendarDenied = !granted
        if granted {
            startObservingCalendar()
            await syncCalendar()
        }
    }

    /// Has the system already granted calendar access? Distinct from
    /// `calendarConnected`, which is our session state.
    var calendarAuthorized: Bool { calendar.hasAccess }

    /// Send someone to Settings — iOS only ever prompts once, so a denial can
    /// only be undone there.
    var calendarNeedsSettings: Bool { calendarDenied && !calendar.hasAccess }

    /// Pick the connection back up on launch when access was already granted,
    /// so returning users don't have to reconnect to stay in sync.
    func resumeCalendarIfAuthorized() async {
        guard !calendarConnected, calendar.hasAccess else { return }
        calendarConnected = true
        startObservingCalendar()
        await syncCalendar()
    }

    func refreshCalendar() {
        guard calendarConnected else { return }
        // No cap: the screen filters to one day, and a 50-event ceiling meant a
        // real calendar's later events simply vanished from the UI.
        deviceEvents = calendar.fetchDeviceEvents(limit: nil)
    }

    /// Re-read the device calendar and push availability again. Called when the
    /// app comes back to the foreground and when EventKit reports a change —
    /// availability that's only uploaded once is stale by the next morning.
    func syncCalendar() async {
        guard calendarConnected else { return }
        deviceEvents = calendar.fetchDeviceEvents(limit: nil)
        await uploadBusyBlocksIfLive()
        mirrorToDeviceCalendar()
    }

    /// Write Plannit-origin events into the dedicated "Plannit" calendar, so a
    /// locked-in plan really does land on your calendar. Best-effort: no access,
    /// no mirror, no complaints.
    func mirrorToDeviceCalendar() {
        guard calendarConnected else { return }
        calendar.mirror(events)
    }

    /// Upload merged busy intervals (no titles) so group availability can be
    /// computed. Shared with the background task — see AvailabilityUploader.
    private func uploadBusyBlocksIfLive() async {
        await AvailabilityUploader.upload(calendar: calendar)
    }
}
