import Foundation

// SlotFinder — the client half of the wedge. Turns the date-finder UI's
// plain-language choices ("a weekend afternoon, 2h") into the `find-slots`
// constraint object, and maps the ranked slots back into display models.
// Kept out of the view so the constraint math stays readable.
// Contract: docs/backend/api-contract.md.

enum TimeOfDay: String {
    case morning = "Morning", afternoon = "Afternoon", evening = "Evening"

    /// Local minutes from midnight the whole slot must fit inside.
    var window: (start: Int, end: Int) {
        switch self {
        case .morning:   return (8 * 60, 12 * 60)
        case .afternoon: return (12 * 60, 17 * 60)
        case .evening:   return (17 * 60, 22 * 60)
        }
    }
}

enum SlotFinder {
    /// How far ahead we look for candidate dates.
    static let searchWeeks = 4
    /// Slots to show — enough to choose from without burying the best one.
    static let maxResults = 5
    static let stepMinutes = 30

    static func constraints(days: Set<Int>, timeOfDay: String, duration: String,
                            memberCount: Int, now: Date = Date()) -> SlotConstraintsDTO {
        let tz = TimeZone.current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        // Start at the next whole hour so candidates land on :00/:30, not :47.
        let start = cal.nextDate(after: now, matching: DateComponents(minute: 0, second: 0),
                                 matchingPolicy: .nextTime) ?? now
        let end = cal.date(byAdding: .day, value: searchWeeks * 7, to: start) ?? start
        let window = (TimeOfDay(rawValue: timeOfDay) ?? .afternoon).window

        return SlotConstraintsDTO(
            windowStart: epochMs(start),
            windowEnd: epochMs(end),
            allowedWeekdays: days.sorted(),
            dayStartMinutes: window.start,
            dayEndMinutes: window.end,
            durationMinutes: minutes(from: duration),
            stepMinutes: stepMinutes,
            timezone: tz.identifier,
            quorum: quorum(memberCount: memberCount))
    }

    /// Ask for a majority rather than everyone: a group of six rarely has a slot
    /// where all six are free, and each card still shows "4 of 6 free" so the
    /// trade-off is visible. `nil` means the scheduler's default (everyone).
    static func quorum(memberCount: Int) -> Int? {
        guard memberCount > 1 else { return nil }
        return max(1, Int((Double(memberCount) / 2).rounded(.up)))
    }

    /// "2h" → 120.
    static func minutes(from duration: String) -> Int {
        (Int(duration.filter(\.isNumber)) ?? 2) * 60
    }

    static func slot(from dto: FoundSlotDTO, best: Bool = false) -> PSlot {
        let start = date(dto.start), end = date(dto.end)
        let weekday = DateFormatter()
        weekday.dateFormat = "EEE"
        return PSlot(day: weekday.string(from: start).uppercased(),
                     date: Calendar.current.component(.day, from: start),
                     time: timeRange(start, end),
                     free: dto.score,
                     best: best)
    }

    /// "2:00 – 4:00 PM" — the meridiem is only repeated when it changes.
    private static func timeRange(_ start: Date, _ end: Date) -> String {
        let full = DateFormatter(); full.dateFormat = "h:mm a"
        let short = DateFormatter(); short.dateFormat = "h:mm"
        let cal = Calendar.current
        let sameHalf = (cal.component(.hour, from: start) < 12) == (cal.component(.hour, from: end) < 12)
        return "\(sameHalf ? short.string(from: start) : full.string(from: start)) – \(full.string(from: end))"
    }

    private static func epochMs(_ d: Date) -> Int64 { Int64(d.timeIntervalSince1970 * 1000) }
    private static func date(_ epochMs: Int64) -> Date {
        Date(timeIntervalSince1970: Double(epochMs) / 1000)
    }
}
