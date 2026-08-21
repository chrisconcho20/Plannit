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
    /// How often it repeats. One database row covers the whole series.
    var recurrence: RepeatRule = .never
    /// Set on an expanded occurrence: the id of the row it came from. The
    /// occurrence needs its own `id` to be unique in a list, but every action
    /// (edit, delete, share) has to act on the underlying series.
    var seriesId: String? = nil
    /// Who has answered, and how. Only group events have these.
    var rsvps: [String: Bool] = [:]        // user id -> going
    /// Groups this event is visible to. Empty = private to the owner.
    var sharedGroupIds: [String] = []
    /// People it's shared with directly, by profile id.
    var sharedUserIds: [String] = []

    var isPrivate: Bool { sharedGroupIds.isEmpty && sharedUserIds.isEmpty }

    /// A plan someone made with a group, as opposed to something you put in your
    /// own calendar. Only these get the going/not-going treatment.
    var isGroupEvent: Bool { !sharedGroupIds.isEmpty }

    var goingCount: Int { rsvps.values.filter { $0 }.count }

    /// Your answer: true going, false not going, nil not asked yet.
    func myRsvp(_ userId: String?) -> Bool? {
        guard let userId else { return nil }
        if isOwned(by: userId) { return rsvps[userId] ?? true }   // creators are in by default
        return rsvps[userId]
    }

    /// On your calendar only once you've said yes. Before that it's an
    /// invitation, and lives in Plans and the group instead.
    func isOnCalendar(for userId: String?) -> Bool {
        guard isGroupEvent else { return true }
        guard let userId else { return true }
        if isOwned(by: userId) { return myRsvp(userId) != false }
        return sharedUserIds.contains(userId)
    }

    /// Waiting on you: offered to a group you're in, and you haven't answered.
    func needsAnswer(from userId: String?) -> Bool {
        guard isGroupEvent, let userId, !isOwned(by: userId) else { return false }
        return rsvps[userId] == nil
    }
    func isOwned(by userId: String?) -> Bool {
        guard let ownerId, let userId else { return true }   // demo: everything is yours
        return ownerId == userId
    }

    var day: Int { Calendar.current.component(.day, from: start) }
    func isOn(_ date: Date) -> Bool { Calendar.current.isDate(start, inSameDayAs: date) }

    /// The row this represents — itself, or the series an occurrence came from.
    var rowId: String { seriesId ?? id }

    /// Expand a repeating event into the occurrences that fall in `range`.
    /// A non-repeating event is just itself, so callers don't branch.
    func occurrences(in range: ClosedRange<Date>) -> [PEvent] {
        guard recurrence != .never else {
            return range.contains(start) ? [self] : []
        }
        let length = end.map { $0.timeIntervalSince(start) } ?? 3600
        return Recurrence.occurrences(start: start, rule: recurrence, in: range, limit: 120)
            .map { occurrenceStart in
                var copy = self
                copy = PEvent(
                    id: "\(id)#\(Int(occurrenceStart.timeIntervalSince1970))",
                    start: occurrenceStart,
                    end: occurrenceStart.addingTimeInterval(length),
                    title: title, time: time, location: location, group: group,
                    hue: hue, icon: icon, people: people, badge: badge,
                    badgeTone: badgeTone, source: source, isAllDay: isAllDay,
                    ownerId: ownerId,
                    recurrence: recurrence, seriesId: id, rsvps: rsvps,
                    sharedGroupIds: sharedGroupIds, sharedUserIds: sharedUserIds)
                return copy
            }
    }
}

/// One thing that happened, from `my_activity()`. The *wording* deliberately
/// lives here rather than in SQL — copy changes shouldn't need a migration.
struct PActivity: Identifiable, Hashable {
    enum Kind: String {
        /// Someone offered your group a date — the one that matters.
        case invited
        /// Someone said they're going to a plan of yours.
        case rsvp
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
        case .invited:       return "wand-sparkles"
        case .rsvp:          return "calendar-check"
        case .eventShared:   return "share-2"
        case .friendRequest: return "user-plus"
        case .joinedGroup:   return "users"
        }
    }

    var hue: GroupHue {
        switch kind {
        case .invited:       return .teal
        case .rsvp:          return .indigo
        case .eventShared:   return .coral
        case .friendRequest: return .rose
        case .joinedGroup:   return .sky
        }
    }

    var sentence: String {
        switch kind {
        case .invited:       return "\(actor) wants to plan \(title)"
        case .rsvp:          return "\(actor) is going to \(title)"
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

extension BusyRange: Hashable {
    static func == (a: BusyRange, b: BusyRange) -> Bool { a.start == b.start && a.end == b.end }
    func hash(into h: inout Hasher) { h.combine(start); h.combine(end) }
}
