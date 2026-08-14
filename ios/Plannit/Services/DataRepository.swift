import Foundation

// Screens read their data from AppModel, which is fed by one of these
// repositories: sample data in demo mode, Supabase in live mode. This keeps the
// UI identical while the source swaps behind Config.isLiveBackend.

protocol DataRepository {
    func fetchGroups() async throws -> [PGroup]
    func fetchEvents() async throws -> [PEvent]
    func fetchProposals() async throws -> [PProposal]
}

struct SampleRepository: DataRepository {
    func fetchGroups() async -> [PGroup] { Sample.groups }
    func fetchEvents() async -> [PEvent] { Sample.events }
    func fetchProposals() async -> [PProposal] { Sample.proposals }
}

struct SupabaseRepository: DataRepository {
    private let client = SupabaseClient.shared

    func fetchGroups() async throws -> [PGroup] {
        // Embed memberships → profiles so we get real member names in one query.
        let dtos: [GroupDTO] = try await client.select(
            "groups", columns: "*,group_memberships(user_id,profiles(id,display_name))")
        return dtos.map { dto in
            // A member with no display name still counts — dropping them made
            // groups look empty ("1 of 0 free"). Name them rather than lose them.
            let members = (dto.group_memberships ?? []).map { membership -> String in
                let name = membership.profiles?.display_name ?? ""
                return name.isEmpty ? "Member" : name
            }
            return PGroup(id: dto.id, name: dto.name, hue: GroupHue.forName(dto.name),
                          members: members, note: "")
        }
    }

    func fetchEvents() async throws -> [PEvent] {
        let dtos: [EventDTO] = try await client.select(
            "events", query: ["deleted_at": "is.null", "order": "start_at.asc"])
        return dtos.map(Self.map)
    }

    func fetchProposals() async throws -> [PProposal] {
        // Proposals join groups + slots + availability; wire once live mode is
        // exercised on a real device. Empty for now so live mode degrades cleanly.
        []
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
    private static func parseDate(_ s: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFractional.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }
}
