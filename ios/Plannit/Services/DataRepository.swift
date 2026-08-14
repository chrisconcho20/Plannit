import Foundation

// Screens read their data from AppModel, which is fed by one of these
// repositories: sample data in demo mode, Supabase in live mode. This keeps the
// UI identical while the source swaps behind Config.isLiveBackend.

@MainActor
protocol DataRepository {
    func fetchGroups() async throws -> [PGroup]
    func fetchEvents() async throws -> [PEvent]
    func fetchProposals() async throws -> [PProposal]
    func fetchPeople() async throws -> [PMember]
}

struct SampleRepository: DataRepository {
    func fetchGroups() async -> [PGroup] { Sample.groups }
    func fetchEvents() async -> [PEvent] { Sample.events }
    func fetchProposals() async -> [PProposal] { Sample.proposals }
    func fetchPeople() async -> [PMember] { Sample.people }
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
            return PGroup(id: dto.id, name: dto.name, hue: GroupHue.forName(dto.name),
                          members: members, note: "", ownerId: dto.owner_id)
        }
    }

    /// Everyone you're allowed to see: RLS returns your own profile, your
    /// friends', and anyone you already share a group with. Until friend
    /// requests exist (roadmap phase 3) that co-member set *is* the directory.
    func fetchPeople() async throws -> [PMember] {
        let rows: [ProfileDTO] = try await client.select(
            "profiles", columns: "id,display_name,timezone",
            query: ["order": "display_name.asc"])
        let me = client.userId
        return rows
            .filter { $0.id != me }
            .map { PMember(id: $0.id, name: $0.display_name.isEmpty ? "Member" : $0.display_name) }
    }

    func fetchEvents() async throws -> [PEvent] {
        let dtos: [EventDTO] = try await client.select(
            "events", query: ["deleted_at": "is.null", "order": "start_at.asc"])
        return dtos.map(Self.map)
    }

    /// One embedded query for the whole Plans tab: the proposal, its group (with
    /// members, so scores have a denominator and faces), its slots, and every
    /// vote. RLS scopes all of it to groups you belong to.
    func fetchProposals() async throws -> [PProposal] {
        let rows: [ProposalRowDTO] = try await client.select(
            "proposals",
            columns: """
                     id,group_id,created_by,title,status,finalized_slot_id,created_at,constraints,\
                     groups(id,name,owner_id,avatar_url,group_memberships(user_id,profiles(id,display_name))),\
                     proposal_slots(id,start_at,end_at,score,available_user_ids),\
                     votes(slot_id,user_id,response)
                     """,
            query: ["order": "created_at.desc"])

        let me = client.userId
        return rows.map { row in
            let group = Self.mapGroup(row.groups, fallbackId: row.group_id)
            // Best turnout first, ties broken by the earliest date — the same
            // ranking the scheduler used when it wrote them.
            let slots = (row.proposal_slots ?? []).sorted { a, b in
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

    private static func mapGroup(_ dto: GroupDTO?, fallbackId: String) -> PGroup {
        guard let dto else {
            return PGroup(id: fallbackId, name: "Group", hue: .coral, members: [], note: "")
        }
        let members = (dto.group_memberships ?? []).compactMap { m -> PMember? in
            guard let id = m.user_id ?? m.profiles?.id else { return nil }
            let name = m.profiles?.display_name ?? ""
            return PMember(id: id, name: name.isEmpty ? "Member" : name)
        }
        return PGroup(id: dto.id, name: dto.name, hue: GroupHue.forName(dto.name),
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
                     availableIds: dto.available_user_ids ?? [])
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

    private static func map(_ d: EventDTO) -> PEvent {
        let start = parseDate(d.start_at) ?? Date()
        let end = parseDate(d.end_at)
        let isDevice = d.source == "device"
        return PEvent(
            id: d.id, start: start, title: d.title, time: timeLabel(start, end),
            location: d.location,
            // Device events stay coral (they read as "yours, private"); Plannit
            // events take a stable hue from their title so the calendar dots and
            // the card agree, and the same event keeps its colour across loads.
            hue: isDevice ? .coral : GroupHue.forName(d.title),
            icon: "calendar",
            badge: isDevice ? "Private" : nil,
            badgeTone: .neutral,
            source: isDevice ? .device : .plannit
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
