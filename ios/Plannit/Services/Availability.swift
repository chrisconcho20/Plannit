import Foundation

// Availability — turning a calendar into the opaque busy ranges the scheduler
// runs on. This is the only calendar data that ever leaves the phone: start and
// end, no titles, no locations, no notes (docs/backend/sync-contract.md).
//
// Kept pure and separate from EventKit so the merging rules are testable.

struct BusyInterval: Equatable, Sendable {
    var start: Date
    var end: Date
}

enum Availability {
    /// How far ahead availability is uploaded.
    ///
    /// This **must** cover the furthest the date-finder can search. `find-slots`
    /// reads "no busy block" as free, so any date past the horizon comes back
    /// "everyone's free" whether or not they are — and the scheduler prefers the
    /// earliest all-free date, which is exactly where the fabricated ones start.
    /// An answer about time we have no data for is worse than no answer.
    ///
    /// The fortnight of slack absorbs the gap between syncs: someone who opens
    /// the app today and searches 6 months next week is still covered.
    static func horizon(months: Int = SearchWindow.months, from now: Date = Date()) -> Date {
        let cal = Calendar.current
        let capped = min(max(months, 1), SearchWindow.options.max() ?? 12)
        let end = cal.date(byAdding: .month, value: capped, to: now) ?? now
        return cal.date(byAdding: .day, value: 14, to: end) ?? end
    }

    /// Merge overlapping and touching intervals into the fewest ranges that
    /// cover the same time. Two meetings 2–3 and 2:30–4 are one busy block
    /// 2–4; uploading them separately would say the same thing at twice the
    /// size, and back-to-back 2–3 and 3–4 is really one 2–4 gap-free stretch.
    static func merge(_ intervals: [BusyInterval]) -> [BusyInterval] {
        let sorted = intervals
            .filter { $0.end > $0.start }          // drop zero-length and inverted
            .sorted { $0.start < $1.start }
        guard var current = sorted.first else { return [] }

        var out: [BusyInterval] = []
        for next in sorted.dropFirst() {
            if next.start <= current.end {
                current.end = max(current.end, next.end)   // overlapping or touching
            } else {
                out.append(current)
                current = next
            }
        }
        out.append(current)
        return out
    }

    /// Clip to the scheduling horizon and drop anything already over — the
    /// scheduler only ever asks about the future, so past blocks are dead weight.
    static func clip(_ intervals: [BusyInterval], from: Date, to: Date) -> [BusyInterval] {
        intervals.compactMap { interval in
            let start = max(interval.start, from)
            let end = min(interval.end, to)
            return end > start ? BusyInterval(start: start, end: end) : nil
        }
    }

    /// What actually gets uploaded: clipped to the horizon, then merged.
    static func prepare(_ intervals: [BusyInterval], from: Date, to: Date) -> [BusyInterval] {
        merge(clip(intervals, from: from, to: to))
    }
}
