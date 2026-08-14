import SwiftUI

// UI-facing models. These mirror the design-system sample shapes and map onto
// the backend contract (docs/backend/api-contract.md) for the wiring phase.

enum EventSource: String, Codable { case plannit, device }

struct PGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let hue: GroupHue
    let members: [String]
    let note: String
}

struct PEvent: Identifiable, Hashable {
    let id: String
    /// The real instant the event starts — the calendar keys off this, not a
    /// bare day-of-month, so events land on the right day of the right month.
    let start: Date
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

    var day: Int { Calendar.current.component(.day, from: start) }
    func isOn(_ date: Date) -> Bool { Calendar.current.isDate(start, inSameDayAs: date) }
}

struct PSlot: Identifiable, Hashable {
    let id = UUID()
    let day: String
    let date: Int
    let time: String
    let free: Int
    var best: Bool = false
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
    var total: Int { group.members.count }

    static func == (a: PProposal, b: PProposal) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

extension BusyRange: Hashable {
    static func == (a: BusyRange, b: BusyRange) -> Bool { a.start == b.start && a.end == b.end }
    func hash(into h: inout Hasher) { h.combine(start); h.combine(end) }
}
