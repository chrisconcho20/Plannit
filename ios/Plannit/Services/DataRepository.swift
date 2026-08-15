import Foundation

// Screens read their data from AppModel, which is fed by one of these
// repositories: sample data in demo mode, Supabase in live mode. This keeps the
// UI identical while the source swaps behind Config.isLiveBackend.

@MainActor
protocol DataRepository {
    func fetchGroups() async throws -> [PGroup]
    /// `groups` resolves an event's shares to a group name for display.
    func fetchEvents(groups: [PGroup]) async throws -> [PEvent]
    func fetchProposals() async throws -> [PProposal]
    func fetchPeople() async throws -> [PMember]
    func fetchFriends() async throws -> [PMember]
    func fetchFriendRequests() async throws -> [PFriendRequest]
    func fetchActivity(limit: Int) async throws -> [PActivity]
}

struct SampleRepository: DataRepository {
    func fetchGroups() async -> [PGroup] { Sample.groups }
    func fetchEvents(groups: [PGroup]) async -> [PEvent] { Sample.events }
    func fetchProposals() async -> [PProposal] { Sample.proposals }
    func fetchPeople() async -> [PMember] { Sample.people }
    func fetchFriends() async -> [PMember] { Sample.people }
    func fetchFriendRequests() async -> [PFriendRequest] {
        // One pretend request so the demo shows the accept/decline UI.
        [PFriendRequest(id: "req-1", person: PMember(id: "kit", name: "Kit Halloran"),
                        incoming: true)]
    }
    func fetchActivity(limit: Int) async -> [PActivity] { Sample.activity }
}

@MainActor
struct SupabaseRepository: DataRepository {
    private let client = SupabaseClient.shared

    func fetchGroups() async throws -> [PGroup] {
        // Embed memberships → profiles so we get real member names in one query.
        let dtos: [GroupDTO] = try await client.select(
            "groups", columns: "*,group_memberships(user_id,profiles(id,display_name))")
        return dtos.map { dto in
            // A member with no display name still counts — dropping them made
            // groups look empty ("1 of 0 free"). Name them rather than lose them.
            let members = (dto.group_memberships ?? []).compactMap { membership -> PMember? in
                guard let id = membership.user_id ?? membership.profiles?.id else { return nil }
                let name = membership.profiles?.display_name ?? ""
                return PMember(id: id, name: name.isEmpty ? "Member" : name)
            }
            return PGroup(id: dto.id, name: dto.name,
                          hue: GroupHue.forGroup(id: dto.id, name: dto.name),
                          members: members, note: "", ownerId: dto.owner_id)
        }
    }

    /// Is the beta's auto-friend switch on? The Friends screen says so out
    /// loud, and it should stop saying it the moment the flag flips.
    func fetchAutoFriendFlag() async -> Bool {
        let rows: [ConfigRowDTO]? = try? await client.select(
            "app_config", columns: "key,value", query: ["key": "eq.auto_friend_everyone"])
        return rows?.first?.value ?? false
    }

    /// Everything that happened in your groups and friendships, newest first.
    /// One definer function rather than six queries: RLS on `profiles` would
    /// hide some actors' names, and six round trips would disagree with each
    /// other about "now".
    func fetchActivity(limit: Int = 50) async throws -> [PActivity] {
        let rows: [ActivityDTO] = try await client.rpc("my_activity",
                                                       args: ActivityArgs(p_limit: limit))
        return rows.compactMap { row in
            guard let kind = PActivity.Kind(rawValue: row.kind),
                  let when = parseISO(row.happened_at) else { return nil }
            return PActivity(
                id: "\(row.kind)-\(row.happened_at)-\(row.title ?? "")-\(row.actor_name ?? "")",
                kind: kind,
                happenedAt: when,
                actor: (row.actor_name?.isEmpty == false ? row.actor_name! : "Someone"),
                title: row.title ?? "a plan",
                subtitle: row.subtitle)
        }
    }

    /// Your accepted friends, via `my_friends()` — `friendships` has two foreign
    /// keys to `profiles`, so an embed would be ambiguous.
    func fetchFriends() async throws -> [PMember] {
        let rows: [FriendDTO] = try await client.rpc("my_friends", args: EmptyArgs())
        return rows.map { PMember(id: $0.id, name: $0.display_name.isEmpty ? "Member" : $0.display_name) }
    }

    /// Requests in both directions. Also a function: someone who has only
    /// requested you isn't a friend yet, so RLS hides their name from a join.
    func fetchFriendRequests() async throws -> [PFriendRequest] {
        let rows: [FriendRequestDTO] = try await client.rpc("my_friend_requests", args: EmptyArgs())
        return rows.map {
            PFriendRequest(id: $0.id,
                           person: PMember(id: $0.other_id,
                                           name: $0.display_name.isEmpty ? "Member" : $0.display_name),
                           incoming: $0.incoming)
        }
    }

    /// Look someone up to befriend them. Exact email only — the function
    /// deliberately won't do prefix search, so the directory isn't enumerable.
    func findPerson(email: String) async throws -> PMember? {
        let rows: [FriendDTO] = try await client.rpc("find_profile_by_email",
                                                     args: EmailLookup(p_email: email))
        return rows.first.map {
            PMember(id: $0.id, name: $0.display_name.isEmpty ? "Member" : $0.display_name)
        }
    }

    /// Everyone you can put in a group: your friends, plus anyone you already
    /// share a group with (RLS shows you those profiles anyway).
    func fetchPeople() async throws -> [PMember] {
        let rows: [ProfileDTO] = try await client.select(
            "profiles", columns: "id,display_name,timezone",
            query: ["order": "display_name.asc"])
        let me = client.userId
        return rows
            .filter { $0.id != me }
            .map { PMember(id: $0.id, name: $0.display_name.isEmpty ? "Member" : $0.display_name) }
    }

    func fetchEvents(groups: [PGroup]) async throws -> [PEvent] {
        // Embedding the shares tells us, in the same round trip, which groups
        // can see each event — that's what makes an event "shared" in the UI.
        let dtos: [EventDTO] = try await client.select(
            "events", columns: "*,event_shares(group_id,shared_user_id)",
            query: ["deleted_at": "is.null", "order": "start_at.asc"])
        let names = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
        let me = client.userId
        return dtos.map { Self.map($0, groups: names, me: me) }
    }

    /// The Plans tab in two queries: proposals (with their group's members, so
    /// scores have a denominator and faces, plus every vote), then the slots.
    ///
    /// The slots are fetched separately on purpose. `proposals` and
    /// `proposal_slots` reference each other — `proposal_slots.proposal_id` one
    /// way, `proposals.finalized_slot_id` the other — so a PostgREST embed is
    /// ambiguous and needs a hint that depends on generated constraint names.
    /// A second query is cheaper than that fragility. RLS scopes both to the
    /// groups you belong to.
    func fetchProposals() async throws -> [PProposal] {
        let rows: [ProposalRowDTO] = try await client.select(
            "proposals",
            columns: """
                     id,group_id,created_by,title,status,finalized_slot_id,created_at,constraints,\
                     groups(id,name,owner_id,avatar_url,group_memberships(user_id,profiles(id,display_name))),\
                     votes(slot_id,user_id,response)
                     """,
            query: ["order": "created_at.desc"])
        guard !rows.isEmpty else { return [] }

        let slotsByProposal = try await fetchSlots(for: rows.map(\.id))
        let me = client.userId

        return rows.map { row in
            let group = Self.mapGroup(row.groups, fallbackId: row.group_id)
            // Best turnout first, ties broken by the earliest date — the same
            // ranking the scheduler used when it wrote them.
            let slots = (slotsByProposal[row.id] ?? []).sorted { a, b in
                a.score != b.score ? a.score > b.score : a.start_at < b.start_at
            }
            let best = slots.first?.id

            var counts: [String: Int] = [:]
            for vote in row.votes ?? [] where vote.response == "yes" {
                counts[vote.slot_id, default: 0] += 1
            }

            return PProposal(
                id: row.id,
                title: row.title.isEmpty ? "Untitled plan" : row.title,
                group: group,
                constraint: Self.describe(row.constraints),
                status: row.finalized_slot_id == nil ? "voting" : "found",
                votes: (row.votes ?? []).filter { $0.response == "yes" }.count,
                slots: slots.map { Self.mapSlot($0, best: $0.id == best) },
                voteCounts: counts,
                myVoteSlotId: (row.votes ?? []).first { $0.user_id == me && $0.response == "yes" }?.slot_id,
                finalizedSlotId: row.finalized_slot_id,
                createdBy: row.created_by)
        }
    }

    private func parseISO(_ s: String) -> Date? { Self.parseISO(s) }

    private func fetchSlots(for proposalIds: [String]) async throws -> [String: [ProposalSlotDTO]] {
        let rows: [ProposalSlotDTO] = try await client.select(
            "proposal_slots", columns: "id,proposal_id,start_at,end_at,score,available_user_ids",
            query: ["proposal_id": "in.(\(proposalIds.joined(separator: ",")))"])
        return Dictionary(grouping: rows.filter { $0.proposal_id != nil }, by: { $0.proposal_id! })
    }

    private static func mapGroup(_ dto: GroupDTO?, fallbackId: String) -> PGroup {
        guard let dto else {
            return PGroup(id: fallbackId, name: "Group", hue: .coral, members: [], note: "")
        }
        let members = (dto.group_memberships ?? []).compactMap { m -> PMember? in
            guard let id = m.user_id ?? m.profiles?.id else { return nil }
            let name = m.profiles?.display_name ?? ""
            return PMember(id: id, name: name.isEmpty ? "Member" : name)
        }
        return PGroup(id: dto.id, name: dto.name,
                      hue: GroupHue.forGroup(id: dto.id, name: dto.name),
                      members: members, note: "", ownerId: dto.owner_id)
    }

    private static func mapSlot(_ dto: ProposalSlotDTO, best: Bool) -> PSlot {
        let start = parseDate(dto.start_at) ?? Date()
        let end = parseDate(dto.end_at)
        let weekday = DateFormatter(); weekday.dateFormat = "EEE"
        return PSlot(id: dto.id,
                     day: weekday.string(from: start).uppercased(),
                     date: Calendar.current.component(.day, from: start),
                     time: timeLabel(start, end),
                     free: dto.score,
                     best: best,
                     availableIds: dto.available_user_ids ?? [],
                     startsAt: start,
                     endsAt: end)
    }

    /// "Sat, Sun · afternoon · 2h" from the constraints the scheduler stored.
    private static func describe(_ c: StoredConstraintsDTO?) -> String {
        guard let c else { return "" }
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var parts: [String] = []
        if let days = c.allowedWeekdays, !days.isEmpty, days.count < 7 {
            parts.append(days.sorted().compactMap { names.indices.contains($0) ? names[$0] : nil }
                             .joined(separator: ", "))
        }
        if let from = c.dayStartMinutes, let to = c.dayEndMinutes {
            parts.append(TimeOfDay.describing(from: from, to: to))
        }
        if let minutes = c.durationMinutes {
            parts.append(minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes)m")
        }
        return parts.joined(separator: " · ")
    }

    /// "Private" is only true of your own unshared events. Something shared
    /// *with* you isn't private — labelling it that way was misleading.
    private static func badge(shares: Int, isMine: Bool) -> String? {
        if !isMine { return "Shared with you" }
        return shares == 0 ? "Private" : nil
    }

    private static func map(_ d: EventDTO, groups: [String: PGroup], me: String?) -> PEvent {
        let start = parseDate(d.start_at) ?? Date()
        let end = parseDate(d.end_at)
        let isDevice = d.source == "device"
        let sharedIds = (d.event_shares ?? []).compactMap(\.group_id)
        let sharedPeople = (d.event_shares ?? []).compactMap(\.shared_user_id)
        let firstGroup = sharedIds.compactMap { groups[$0] }.first

        return PEvent(
            id: d.id, start: start, end: end, title: d.title,
            time: d.all_day ? "All day" : timeLabel(start, end),
            location: d.location,
            group: firstGroup?.name,
            // A shared event takes its group's colour so the calendar reads at a
            // glance; private ones keep a stable hue derived from the title.
            hue: firstGroup?.hue ?? (isDevice ? .coral : GroupHue.forName(d.title)),
            icon: "calendar",
            badge: Self.badge(shares: sharedIds.count + sharedPeople.count,
                              isMine: d.owner_id == me),
            badgeTone: .neutral,
            source: isDevice ? .device : .plannit,
            isAllDay: d.all_day,
            recurrence: Recurrence.rule(from: d.recurrence_rule),
            ownerId: d.owner_id,
            sharedGroupIds: sharedIds,
            sharedUserIds: sharedPeople
        )
    }

    /// "2:00 PM" for a point in time, "2:00 – 4:00 PM" when we know the end.
    private static func timeLabel(_ start: Date, _ end: Date?) -> String {
        let full = DateFormatter(); full.dateFormat = "h:mm a"
        guard let end, end > start else { return full.string(from: start) }
        let short = DateFormatter(); short.dateFormat = "h:mm"
        let cal = Calendar.current
        let sameHalf = (cal.component(.hour, from: start) < 12) == (cal.component(.hour, from: end) < 12)
        let sameDay = cal.isDate(start, inSameDayAs: end)
        guard sameDay else { return full.string(from: start) }
        return "\(sameHalf ? short.string(from: start) : full.string(from: start)) – \(full.string(from: end))"
    }

    /// Parse a Postgres timestamptz, tolerating fractional seconds.
    static func parseISO(_ s: String) -> Date? { parseDate(s) }

    private static func parseDate(_ s: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFractional.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }
}
