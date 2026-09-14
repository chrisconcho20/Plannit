import Foundation

// PlanPreferences — personal rules for the date finder, set in You → Date finder.
//
// Both are stored on this phone and apply to every group. A per-group version of
// MinimumAttendance (a five-a-side needing ten, a family dinner needing all) is a
// likely next step; it would live on the group rather than here.

// MARK: - Hours you're never free

/// Times your calendar doesn't show but you'd never say yes to: before a set
/// hour, after another, and whole days of the week.
///
/// The rule becomes ordinary busy blocks on the phone, merged into the
/// availability upload (`CalendarService.read`). The server and the scheduler
/// don't know it exists, and nothing about *why* you're busy leaves the phone —
/// the group just sees you as busy then, like any other busy time.
struct NeverFreeHours: Equatable, Codable {
    static let key = "plannit.neverFreeHours"
    static let dayMinutes = 24 * 60
    static let step = 30

    var enabled = false
    /// Local minutes from midnight you're free from. 0 means "any time after midnight".
    var earliestMinutes = 9 * 60
    /// Local minutes from midnight you're free until. 1440 means "until midnight".
    var latestMinutes = 22 * 60
    /// Days you're never free, 0=Sun…6=Sat — the scheduler's numbering.
    var blockedWeekdays: Set<Int> = []

    static var current: NeverFreeHours {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let rule = try? JSONDecoder().decode(NeverFreeHours.self, from: data)
            else { return NeverFreeHours() }
            return rule
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: key)
        }
    }

    /// Does the rule rule anything out? An "on" rule of midnight-to-midnight
    /// with no days blocked is the same as off.
    var isActive: Bool {
        enabled && (earliestMinutes > 0 || latestMinutes < Self.dayMinutes || !blockedWeekdays.isEmpty)
    }

    /// The busy time this rule adds between `from` and `to`, day by day in
    /// `calendar`'s time zone. Local clock times are resolved per day, so a DST
    /// change doesn't shift "before 9" to 8 or 10. Unmerged and unclipped: the
    /// caller does both along with the calendar's own blocks.
    func blocks(from: Date, to: Date, calendar: Calendar = .current) -> [BusyInterval] {
        guard isActive, from < to, latestMinutes > earliestMinutes else { return [] }
        var out: [BusyInterval] = []
        var day = calendar.startOfDay(for: from)
        while day < to, let next = calendar.date(byAdding: .day, value: 1, to: day) {
            let weekday = calendar.component(.weekday, from: day) - 1
            if blockedWeekdays.contains(weekday) {
                out.append(BusyInterval(start: day, end: next))
            } else {
                if earliestMinutes > 0, let free = Self.time(earliestMinutes, on: day, calendar) {
                    out.append(BusyInterval(start: day, end: free))
                }
                if latestMinutes < Self.dayMinutes, let done = Self.time(latestMinutes, on: day, calendar) {
                    out.append(BusyInterval(start: done, end: next))
                }
            }
            day = next
        }
        return out
    }

    private static func time(_ minutes: Int, on day: Date, _ calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day)
    }

    // MARK: Copy

    /// "9:00 AM", or "Midnight" at either end of the day.
    static func label(_ minutes: Int) -> String {
        if minutes == 0 || minutes == dayMinutes { return "Midnight" }
        var parts = DateComponents()
        parts.hour = minutes / 60
        parts.minute = minutes % 60
        let date = Calendar.current.date(from: parts) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// "Not before 9:00 AM or after 10:00 PM · never on Sun" — or "Off".
    var summary: String {
        guard isActive else { return "Off" }
        var parts: [String] = []
        switch (earliestMinutes > 0, latestMinutes < Self.dayMinutes) {
        case (true, true):
            parts.append("Not before \(Self.label(earliestMinutes)) or after \(Self.label(latestMinutes))")
        case (true, false):  parts.append("Not before \(Self.label(earliestMinutes))")
        case (false, true):  parts.append("Not after \(Self.label(latestMinutes))")
        case (false, false): break
        }
        if !blockedWeekdays.isEmpty {
            let names = Calendar.current.shortWeekdaySymbols
            let days = blockedWeekdays.sorted().map { names[$0] }.joined(separator: ", ")
            parts.append("never on \(days)")
        }
        let text = parts.joined(separator: " · ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}

// MARK: - How many people a date has to work for

/// The smallest turnout the date finder will offer. A time the whole group can
/// make always comes first; this decides what's acceptable when there isn't one.
enum MinimumAttendance: String, CaseIterable {
    case one = "1", two = "2", five = "5", ten = "10", half, all

    static let key = "plannit.minimumAttendance"
    static let defaultValue: MinimumAttendance = .all

    /// Sent as the quorum for `.all`. `findBestSlots` caps the quorum at the
    /// group's size as the server counts it (scheduler.ts, covered by
    /// "quorum above the group size can't make a slot unreachable"), so someone
    /// who joined since the app last loaded the group still has to be free.
    static let everyone = 1_000_000

    var label: String {
        switch self {
        case .half: return "Half"
        case .all:  return "All"
        default:    return rawValue
        }
    }

    /// The floor for a group of this size: never above the group, never below 1.
    func floor(groupSize: Int) -> Int {
        let size = max(groupSize, 1)
        let wanted: Int
        switch self {
        case .one:  wanted = 1
        case .two:  wanted = 2
        case .five: wanted = 5
        case .ten:  wanted = 10
        case .half: wanted = Int((Double(size) / 2).rounded(.up))
        case .all:  wanted = size
        }
        return min(max(wanted, 1), size)
    }

    /// What `find-slots` is sent as `quorum`.
    func quorum(groupSize: Int) -> Int {
        self == .all ? Self.everyone : floor(groupSize: groupSize)
    }

    /// "all 6" · "at least 3 of 6".
    func phrase(groupSize: Int) -> String {
        let floor = floor(groupSize: groupSize)
        return floor >= groupSize ? "all \(groupSize)" : "at least \(floor) of \(groupSize)"
    }
}
