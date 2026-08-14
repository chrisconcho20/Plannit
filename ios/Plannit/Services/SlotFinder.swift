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

    /// Name a stored window back — "afternoon", or "12:00–17:00" if it was
    /// hand-rolled rather than one of ours.
    static func describing(from: Int, to: Int) -> String {
        if let match = [morning, afternoon, evening].first(
            where: { $0.window.start == from && $0.window.end == to }) {
            return match.rawValue.lowercased()
        }
        func clock(_ m: Int) -> String { String(format: "%d:%02d", m / 60, m % 60) }
        return "\(clock(from))–\(clock(to))"
    }
}

/// How far ahead the date-finder looks. A date that works for *everyone* always
/// wins, so the window is really "how far out are you willing to plan" — a
/// personal call, changed in You → Date finder.
enum SearchWindow {
    static let key = "plannit.searchWindowMonths"
    static let options = [1, 3, 6, 12]
    static let defaultMonths = 6

    /// The stored preference, or the default when unset/nonsense.
    static var months: Int {
        let stored = UserDefaults.standard.integer(forKey: key)   // 0 when unset
        return options.contains(stored) ? stored : defaultMonths
    }

    /// "6 mo" · "1 year" — for the picker.
    static func label(_ months: Int) -> String {
        months == 12 ? "1 year" : "\(months) mo"
    }

    /// "the next 6 months" · "the next year" — for a sentence.
    static func phrase(_ months: Int) -> String {
        months == 12 ? "the next year" : "the next \(months) month\(months == 1 ? "" : "s")"
    }
}

enum SlotFinder {
    /// Slots to show — enough to choose from without burying the best one.
    static let maxResults = 5
    static let stepMinutes = 30

    static func constraints(days: Set<Int>, timeOfDay: String, duration: String,
                            months: Int = SearchWindow.months,
                            now: Date = Date()) -> SlotConstraintsDTO {
        let tz = TimeZone.current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        // Start at the next whole hour so candidates land on :00/:30, not :47.
        let start = cal.nextDate(after: now, matching: DateComponents(minute: 0, second: 0),
                                 matchingPolicy: .nextTime) ?? now
        let end = cal.date(byAdding: .month, value: months, to: start) ?? start
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
            // No quorum: the scheduler holds out for a date the whole group can
            // make and only drops to the best turnout if the window has none.
            quorum: nil)
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
                     best: best,
                     availableIds: dto.availableUserIds)
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
