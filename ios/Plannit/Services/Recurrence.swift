import EventKit
import Foundation

// Recurrence — the repeat rule behind `events.recurrence_rule` (RFC 5545).
//
// Deliberately a five-option closed set rather than a full RRULE engine. The
// column stores real RRULE strings so the data stays portable — EventKit,
// Google and every other calendar read them — but Plannit only ever *writes*
// the handful of rules the picker offers, and reads anything richer back as
// .never. A picker that can't show what's stored would silently rewrite a
// user's rule the next time they tapped Save, which is worse than admitting we
// don't support it. Widening the set later means adding a case here, not
// rewriting the callers.
//
// Pure Foundation + EventKit: no app state, no networking, so the date maths is
// testable on its own (PlannitTests/RecurrenceTests.swift).

/// How often an event repeats.
enum RepeatRule: String, CaseIterable, Identifiable {
    case never, daily, weekly, fortnightly, monthly

    var id: String { rawValue }

    /// What the picker shows.
    var label: String {
        switch self {
        case .never:       return "Never"
        case .daily:       return "Every day"
        case .weekly:      return "Every week"
        case .fortnightly: return "Every 2 weeks"
        case .monthly:     return "Every month"
        }
    }
}

enum Recurrence {
    // MARK: - RRULE

    /// The RFC 5545 RRULE body to store, e.g. `"FREQ=WEEKLY;INTERVAL=2"`.
    /// `nil` for `.never` — a one-off event has no rule, not an empty one.
    static func rrule(for rule: RepeatRule) -> String? {
        switch rule {
        case .never:       return nil
        case .daily:       return "FREQ=DAILY"
        case .weekly:      return "FREQ=WEEKLY"
        // INTERVAL=1 is the RFC default, so it's only spelled out where it isn't 1.
        case .fortnightly: return "FREQ=WEEKLY;INTERVAL=2"
        case .monthly:     return "FREQ=MONTHLY"
        }
    }

    /// Read back whatever is in the database. Tolerant by design: rows can
    /// arrive from an import, an older build or a hand-written SQL fix, and a
    /// malformed rule must degrade to "doesn't repeat" rather than throw.
    static func rule(from rrule: String?) -> RepeatRule {
        guard let rrule else { return .never }
        var body = rrule.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        // Some producers include the property name; the value is what we parse.
        if body.hasPrefix("RRULE:") { body = String(body.dropFirst("RRULE:".count)) }
        guard !body.isEmpty else { return .never }

        var freq = ""
        var interval = 1
        for pair in body.split(separator: ";") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return .never }
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            switch parts[0].trimmingCharacters(in: .whitespaces) {
            case "FREQ":
                freq = value
            case "INTERVAL":
                guard let n = Int(value) else { return .never }
                interval = n
            default:
                // COUNT, UNTIL, BYDAY and friends each say something the five
                // options can't express. Keeping the FREQ and dropping the rest
                // would turn a rule that was meant to stop into one that never
                // does, so the whole rule is refused instead.
                return .never
            }
        }

        switch (freq, interval) {
        case ("DAILY", 1):   return .daily
        case ("WEEKLY", 1):  return .weekly
        case ("WEEKLY", 2):  return .fortnightly
        case ("MONTHLY", 1): return .monthly
        default:             return .never
        }
    }

    // MARK: - Expansion

    /// Every occurrence start inside `range`, for an event starting at `start`.
    /// Bounds are inclusive, and `start` itself is included when it falls in
    /// range. Occurrences before the range are skipped, not returned.
    ///
    /// Results are capped at `limit` so a wide range can never hang the UI; the
    /// caller asks for a window it can actually draw. Local wall-clock time is
    /// preserved across daylight-saving changes — a 2pm event stays at 2pm.
    ///
    /// Uses `Calendar.current`: "every month" means what the phone's calendar
    /// and timezone say it means.
    static func occurrences(start: Date, rule: RepeatRule,
                            in range: ClosedRange<Date>, limit: Int = 400) -> [Date] {
        guard limit > 0 else { return [] }
        guard rule != .never else { return range.contains(start) ? [start] : [] }
        guard start <= range.upperBound else { return [] }

        let cal = Calendar.current
        var step = firstStep(from: start, to: range.lowerBound, rule: rule, calendar: cal)
        // Bound the *work*, not just the output: a skipped month (see below)
        // costs a step without producing an occurrence, and the 31st is missing
        // from 5 months in 12, so the budget is comfortably over `limit`.
        let lastStep = step + limit * 2 + 12

        var out: [Date] = []
        while step <= lastStep, out.count < limit {
            let candidate = occurrence(of: start, step: step, calendar: cal, rule: rule)
            step += 1
            guard let date = candidate else { continue }
            if date > range.upperBound { break }
            if date >= range.lowerBound { out.append(date) }
        }
        return out
    }

    /// The `step`-th occurrence counted from `start` (step 0 is `start`), or nil
    /// where that step has no occurrence.
    ///
    /// Always measured from `start` rather than from the previous occurrence:
    /// stepping off the last result would compound every clamp and DST nudge.
    private static func occurrence(of start: Date, step: Int,
                                   calendar cal: Calendar, rule: RepeatRule) -> Date? {
        switch rule {
        case .never:
            return step == 0 ? start : nil
        case .daily, .weekly, .fortnightly:
            // Adding whole days is the whole trick: Calendar re-resolves the
            // wall time in the new UTC offset, so 2pm stays 2pm. Adding
            // 7 × 86400 seconds would land the event at 1pm or 3pm for half
            // the year.
            return cal.date(byAdding: .day, value: step * (dayStride(rule) ?? 1), to: start)
        case .monthly:
            guard let candidate = cal.date(byAdding: .month, value: step, to: start) else {
                return nil
            }
            // Calendar clamps: 31 January plus one month is 28 February. An
            // event that repeats on the 31st simply has no February occurrence,
            // so the clamped date is dropped rather than kept. That matches
            // Apple's Calendar, and a plan that quietly appears on a day nobody
            // agreed to is worse than one that doesn't appear at all.
            return cal.component(.day, from: candidate) == cal.component(.day, from: start)
                ? candidate : nil
        }
    }

    /// Whole days between occurrences, or nil for the rules that step in months.
    private static func dayStride(_ rule: RepeatRule) -> Int? {
        switch rule {
        case .daily:       return 1
        case .weekly:      return 7
        case .fortnightly: return 14
        case .monthly, .never: return nil
        }
    }

    /// Jump most of the way to `target` instead of walking an event that began
    /// years ago one occurrence at a time — otherwise `limit` would be spent
    /// before the loop even reached the range the caller asked about.
    ///
    /// Deliberately lands a step short of `target`, so it can never skip the
    /// first in-range occurrence; the loop finds the exact one.
    private static func firstStep(from start: Date, to target: Date,
                                  rule: RepeatRule, calendar cal: Calendar) -> Int {
        guard rule != .never, start < target else { return 0 }
        let elapsed: Int
        if let stride = dayStride(rule) {
            elapsed = (cal.dateComponents([.day], from: start, to: target).day ?? 0) / stride
        } else {
            elapsed = cal.dateComponents([.month], from: start, to: target).month ?? 0
        }
        return max(0, elapsed - 1)
    }

    // MARK: - EventKit

    /// The same rule for the mirrored copy in the device calendar, so a
    /// repeating Plannit event is one repeating EKEvent rather than 400 of them.
    /// No end: Plannit rules run until the event is deleted.
    static func ekRule(for rule: RepeatRule) -> EKRecurrenceRule? {
        switch rule {
        case .never:       return nil
        case .daily:       return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekly:      return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .fortnightly: return EKRecurrenceRule(recurrenceWith: .weekly, interval: 2, end: nil)
        case .monthly:     return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        }
    }
}
