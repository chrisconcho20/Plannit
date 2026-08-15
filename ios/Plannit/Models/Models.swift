import SwiftUI

// UI-facing models. These mirror the design-system sample shapes and map onto
// the backend contract (docs/backend/api-contract.md) for the wiring phase.

enum EventSource: String, Codable { case plannit, device }

/// Someone you can put in a group. Carries the profile id, not just a name, so
/// members can actually be added and removed.
struct PMember: Identifiable, Hashable {
    let id: String
    let name: String

    /// For sample data, where the name is the only identity there is.
    static func named(_ names: [String]) -> [PMember] { names.map { PMember(id: $0, name: $0) } }
}

/// A friend request you've sent or received.
struct PFriendRequest: Identifiable, Hashable {
    let id: String            // the friendships row
    let person: PMember
    let incoming: Bool        // true = they asked you
}

struct PGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let hue: GroupHue
    let members: [PMember]
    let note: String
    /// nil in demo mode, where there's nobody to check against.
    var ownerId: String? = nil

    var memberNames: [String] { members.map(\.name) }
    func isOwned(by userId: String?) -> Bool {
        guard let ownerId, let userId else { return true }   // demo: you own everything
        return ownerId == userId
    }
}

struct PEvent: Identifiable, Hashable {
    let id: String
    /// The real instant the event starts — the calendar keys off this, not a
    /// bare day-of-month, so events land on the right day of the right month.
    let start: Date
    /// Known for anything that came from the backend; nil for sample rows.
    var end: Date? = nil
    let title: String
    let time: String
    var location: String? = nil
    var group: String? = nil
    var hue: GroupHue = .coral
    var icon: String = "calendar"
    var people: [String] = []
    var badge: String? = nil
    var badgeTone: BadgeTone = .neutral
    var source: EventSource = .plannit
    /// An all-day event has no meaningful clock time — real calendars are full
    /// of them (birthdays, trips) and they don't make you busy.
    var isAllDay: Bool = false
    /// nil in demo mode; otherwise the profile that owns the event — only they
    /// may share it (RLS on `event_shares`).
    var ownerId: String? = nil
    /// Groups this event is visible to. Empty = private to the owner.
    var sharedGroupIds: [String] = []
    /// People it's shared with directly, by profile id.
    var sharedUserIds: [String] = []

    var isPrivate: Bool { sharedGroupIds.isEmpty && sharedUserIds.isEmpty }
    func isOwned(by userId: String?) -> Bool {
        guard let ownerId, let userId else { return true }   // demo: everything is yours
        return ownerId == userId
    }

    var day: Int { Calendar.current.component(.day, from: start) }
    func isOn(_ date: Date) -> Bool { Calendar.current.isDate(start, inSameDayAs: date) }
}

/// One thing that happened, from `my_activity()`. The *wording* deliberately
/// lives here rather than in SQL — copy changes shouldn't need a migration.
struct PActivity: Identifiable, Hashable {
    enum Kind: String {
        case planCreated = "plan_created"
        case vote
        case planLocked = "plan_locked"
        case eventShared = "event_shared"
        case friendRequest = "friend_request"
        case joinedGroup = "joined_group"
    }

    let id: String
    let kind: Kind
    let happenedAt: Date
    let actor: String
    let title: String
    let subtitle: String?

    var icon: String {
        switch kind {
        case .planCreated:   return "wand-sparkles"
        case .vote:          return "thumbs-up"
        case .planLocked:    return "calendar-check"
        case .eventShared:   return "share-2"
        case .friendRequest: return "user-plus"
        case .joinedGroup:   return "users"
        }
    }

    var hue: GroupHue {
        switch kind {
        case .planCreated, .planLocked: return .teal
        case .vote:                     return .indigo
        case .eventShared:              return .coral
        case .friendRequest:            return .rose
        case .joinedGroup:              return .sky
        }
    }

    var sentence: String {
        switch kind {
        case .planCreated:   return "\(actor) started \(title)"
        case .vote:          return "\(actor) voted on \(title)"
        case .planLocked:    return "\(title) is locked in"
        case .eventShared:   return "\(actor) shared \(title)"
        case .friendRequest: return "\(actor) wants to be friends"
        case .joinedGroup:   return "\(actor) joined \(title)"
        }
    }

    /// "just now" · "2h ago" · "3 Sept"
    var when: String {
        let seconds = Date().timeIntervalSince(happenedAt)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h ago" }
        if seconds < 604_800 { return "\(Int(seconds / 86_400))d ago" }
        let f = DateFormatter(); f.dateFormat = "d MMM"
        return f.string(from: happenedAt)
    }
}

struct PSlot: Identifiable, Hashable {
    /// The `proposal_slots` row id once a proposal exists; a throwaway uuid
    /// while the slot is still just a search result.
    var id: String = UUID().uuidString
    let day: String
    let date: Int
    let time: String
    let free: Int
    var best: Bool = false
    /// Profile ids of the members free then — lets the card show real faces.
    var availableIds: [String] = []
    /// The real instants, when we have them: `day`/`time` are display strings.
    var startsAt: Date? = nil
    var endsAt: Date? = nil

    var isToday: Bool {
        guard let startsAt else { return false }
        return Calendar.current.isDateInToday(startsAt)
    }
}

struct PAvailability: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let blocks: [BusyRange]
}

struct PProposal: Identifiable, Hashable {
    let id: String
    let title: String
    let group: PGroup
    let constraint: String
    let status: String       // "voting" | "found"
    var votes: Int = 0
    let slots: [PSlot]
    var availability: [PAvailability] = []
    /// Votes cast per slot id, and which slot you picked.
    var voteCounts: [String: Int] = [:]
    var myVoteSlotId: String? = nil
    /// Set once someone locks a time in.
    var finalizedSlotId: String? = nil
    /// Who created it — only they (or the group's owner) may lock a time in.
    var createdBy: String? = nil

    var total: Int { group.members.count }
    var isFinalized: Bool { finalizedSlotId != nil }
    var finalizedSlot: PSlot? { slots.first { $0.id == finalizedSlotId } }

    /// Why this plan wants your attention — nil when it doesn't.
    /// Drives the Plans tab badge, so it counts real reasons only.
    enum Nudge { case needsYourVote, happeningToday }
    func nudge(for userId: String?) -> Nudge? {
        if isFinalized {
            return finalizedSlot?.isToday == true ? .happeningToday : nil
        }
        // Someone put a plan in front of you and you haven't answered it.
        return myVoteSlotId == nil ? .needsYourVote : nil
    }
    func canFinalize(_ userId: String?) -> Bool {
        guard let userId else { return true }              // demo
        return createdBy == nil || createdBy == userId || group.ownerId == userId
    }
    /// The names of the members free for a slot, for the avatar row.
    func people(for slot: PSlot) -> [String] {
        guard !slot.availableIds.isEmpty else {
            return Array(group.memberNames.prefix(slot.free))   // demo fallback
        }
        return group.members.filter { slot.availableIds.contains($0.id) }.map(\.name)
    }

    static func == (a: PProposal, b: PProposal) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

extension BusyRange: Hashable {
    static func == (a: BusyRange, b: BusyRange) -> Bool { a.start == b.start && a.end == b.end }
    func hash(into h: inout Hasher) { h.combine(start); h.combine(end) }
}
