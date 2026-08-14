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
            "groups", columns: "*,group_memberships(profiles(display_name))")
        return dtos.map { dto in
            let members = (dto.group_memberships ?? [])
                .compactMap { $0.profiles?.display_name }
                .filter { !$0.isEmpty }
            return PGroup(id: dto.id, name: dto.name, hue: GroupHue.forName(dto.name),
                          members: members, note: "")
        }
    }

    func fetchEvents() async throws -> [PEvent] {
        let dtos: [EventDTO] = try await client.select("events")
        return dtos.map(Self.map)
    }

    func fetchProposals() async throws -> [PProposal] {
        // Proposals join groups + slots + availability; wire once live mode is
        // exercised on a real device. Empty for now so live mode degrades cleanly.
        []
    }

    private static func map(_ d: EventDTO) -> PEvent {
        let start = parseDate(d.start_at) ?? Date()
        let day = Calendar.current.component(.day, from: start)
        let tf = DateFormatter(); tf.dateFormat = "h:mm a"
        return PEvent(
            id: d.id, day: day, title: d.title, time: tf.string(from: start),
            location: d.location,
            hue: .coral, icon: "calendar",
            badge: d.source == "device" ? "Private" : nil,
            badgeTone: .neutral,
            source: d.source == "device" ? .device : .plannit
        )
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
