import EventKit
import Foundation
import SwiftUI
import UIKit

// Real EventKit access — works in the iOS Simulator (add events in the
// Simulator's Calendar app to see them here). See docs/backend/sync-contract.md.
//
// Two directions:
//   • read  — device events for the calendar list, and opaque busy ranges for
//             the scheduler (no titles ever leave the phone)
//   • write — Plannit-origin events mirrored into a dedicated "Plannit"
//             calendar, so a locked-in plan really is on your calendar

/// What one sweep of the calendar found: the merged busy ranges, and how many
/// events were in the window at all.
struct BusyReading: Sendable {
    let blocks: [BusyInterval]
    let eventCount: Int
}

struct DeviceEvent: Identifiable, Hashable, Sendable {
    let id: String
    /// The stable cross-device id (`calendarItemExternalIdentifier`) — the
    /// dedupe key the sync contract keys imports on. `id` above is the local
    /// `eventIdentifier`, which can change.
    let externalId: String?
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let isAllDay: Bool
}

final class CalendarService {
    let store = EKEventStore()

    /// The calendar we own. We never write into the user's own calendars.
    static let plannitCalendarTitle = "Plannit"
    /// events.id → EKEvent.eventIdentifier, so a mirrored event is updated
    /// rather than duplicated. UserDefaults until there's a local store (D-02).
    private static let mirrorKey = "plannit.mirroredEvents"

    /// Request access. Uses the iOS 17 full-access API; see D-05 in the decision log.
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await store.requestFullAccessToEvents()
            } else {
                return try await store.requestAccess(to: .event)
            }
        } catch {
            return false
        }
    }

    /// May we read the calendar? Availability and the whole date-finder depend
    /// on this one.
    var canRead: Bool {
        if #available(iOS 17.0, *) {
            return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        }
        return EKEventStore.authorizationStatus(for: .event) == .authorized
    }

    /// May we write into our own calendar? **Write-only counts.** Treating
    /// anything short of full access as "no access" meant someone who granted
    /// exactly what the mirror needs got no mirror — a permission we asked for,
    /// were given, and then ignored.
    var canWrite: Bool {
        if #available(iOS 17.0, *) {
            let status = EKEventStore.authorizationStatus(for: .event)
            return status == .fullAccess || status == .writeOnly
        }
        return EKEventStore.authorizationStatus(for: .event) == .authorized
    }

    /// Kept as the old name for callers that mean "can we do the reading half".
    var hasAccess: Bool { canRead }

    // MARK: - Which calendars

    /// Calendars the user has switched **off** for Plannit, by identifier.
    ///
    /// Not cosmetic: a subscribed fixtures feed or a shared family calendar can
    /// otherwise mark you busy for the scheduler, and you'd have no way to say
    /// so. Stored as the excluded set rather than the included one so a calendar
    /// added later (a new account, a shared invite) is included by default —
    /// silently dropping new calendars is the failure that looks like data loss.
    private static let excludedKey = "plannit.excludedCalendars"

    static var excludedCalendarIds: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: excludedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: excludedKey) }
    }

    /// Every calendar we could read, minus our own mirror — that one isn't a
    /// choice, it's ours.
    func selectableCalendars() -> [EKCalendar] {
        guard canRead else { return [] }
        return store.calendars(for: .event)
            .filter { $0.title != Self.plannitCalendarTitle }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    static func isEnabled(_ calendar: EKCalendar) -> Bool {
        !excludedCalendarIds.contains(calendar.calendarIdentifier)
    }

    static func setEnabled(_ enabled: Bool, for calendar: EKCalendar) {
        var excluded = excludedCalendarIds
        if enabled { excluded.remove(calendar.calendarIdentifier) }
        else { excluded.insert(calendar.calendarIdentifier) }
        excludedCalendarIds = excluded
    }

    // MARK: - Read

    /// Events in a window around today, mapped to a lightweight model.
    ///
    /// **Excludes our own "Plannit" calendar.** We mirror Plannit events into
    /// it, so reading them back would show every plan twice — once as a Plannit
    /// event and once as a device event. Availability deliberately still counts
    /// them: a locked-in plan does make you busy.
    ///
    /// `limit` exists for the UI list only — availability must never be capped,
    /// so `busyIntervals` doesn't use it.
    func fetchDeviceEvents(daysBack: Int = 1, daysAhead: Int = 60, limit: Int? = 50) -> [DeviceEvent] {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .day, value: -daysBack, to: now) ?? now
        let end = cal.date(byAdding: .day, value: daysAhead, to: now) ?? now
        let sorted = matching(from: start, to: end, includingPlannit: false)
            .sorted { $0.startDate < $1.startDate }
        let capped = limit.map { Array(sorted.prefix($0)) } ?? sorted
        return capped.map {
            DeviceEvent(id: Self.occurrenceId(for: $0),
                        externalId: $0.calendarItemExternalIdentifier,
                        title: $0.title ?? "Event",
                        start: $0.startDate,
                        end: $0.endDate,
                        location: $0.location,
                        isAllDay: $0.isAllDay)
        }
    }

    /// EventKit reuses one `eventIdentifier` across every occurrence of a
    /// repeating event, so a weekly standup arrives as N rows sharing an id.
    /// `ForEach` then renders the wrong rows and logs "ID occurs multiple
    /// times". The start instant is what actually distinguishes them — the same
    /// shape `PEvent.occurrences` uses for Plannit's own series.
    static func occurrenceId(for event: EKEvent) -> String {
        // Never a UUID: a random fallback would hand the same event a new id on
        // every read, and the list would churn instead of updating in place.
        let base = event.eventIdentifier
            ?? event.calendarItemExternalIdentifier
            ?? "\(event.title ?? "event")@\(event.calendar?.calendarIdentifier ?? "?")"
        return "\(base)#\(Int(event.startDate.timeIntervalSince1970))"
    }

    /// Privacy-safe availability: merged busy ranges as absolute times.
    ///
    /// Every event in the horizon counts — a cap here would quietly tell the
    /// scheduler you're free when you aren't.
    ///
    /// The horizon defaults to the date-finder's own search window rather than a
    /// fixed 8 weeks. See `Availability.horizon`: a shorter horizon doesn't make
    /// the finder cautious past its end, it makes it *confident and wrong*.
    func busyIntervals(until horizon: Date = Availability.horizon()) -> [BusyInterval] {
        read(until: horizon).blocks
    }

    /// The blocks **and** how many events they came from.
    ///
    /// The count is not diagnostics. An empty block list is the shape every bug
    /// in this path produces, and on the wire it means "free at all times" — so
    /// the uploader has to be able to tell "genuinely nothing on" from "our read
    /// came back empty". Answering that with a second EventKit sweep would cost
    /// another full pass over the calendar, so it rides along with the first.
    func read(until horizon: Date = Availability.horizon()) -> BusyReading {
        let now = Date()
        let all = matching(from: now, to: horizon)
        let busy = all.filter { Self.isBusy($0) }
        let merged = Availability.prepare(
            busy.map { BusyInterval(start: $0.startDate, end: $0.endDate) },
            from: now, to: horizon)
        let days = Calendar.current.dateComponents([.day], from: now, to: horizon).day ?? 0
        Log.cal("busy: \(busy.count) of \(all.count) events in \(days)d → \(merged.count) merged blocks")
        return BusyReading(blocks: merged, eventCount: all.count)
    }

    /// Does this event make you unavailable?
    ///
    /// Skipped: events you marked Free, cancelled ones, meetings you **declined**
    /// (you told them you're not coming — Plannit shouldn't think otherwise),
    /// and single-day all-day events, because a birthday shouldn't block a day.
    ///
    /// Multi-day all-day events *do* count: five all-day days called "Portugal"
    /// is exactly the week nobody should be offered.
    static func isBusy(_ event: EKEvent) -> Bool {
        isBusy(start: event.startDate, end: event.endDate, isAllDay: event.isAllDay,
               availability: event.availability, status: event.status,
               declined: declined(event))
    }

    /// The rule itself, in terms of facts rather than an `EKEvent`.
    ///
    /// Split out because an EKEvent can't be built honestly in a test — with no
    /// calendar attached, `availability` reads back `.notSupported` however you
    /// set it, so a test of "marked Free doesn't block you" was really testing
    /// EventKit's setter. The rule is the part worth pinning down.
    static func isBusy(start: Date, end: Date, isAllDay: Bool,
                       availability: EKEventAvailability, status: EKEventStatus,
                       declined: Bool) -> Bool {
        guard availability != .free, status != .canceled, !declined else { return false }
        if isAllDay { return spansMultipleDays(start: start, end: end) }
        return true
    }

    /// Your own answer to an invitation. `EKEvent.status` reports the *event's*
    /// state, not yours, so a meeting you declined still arrives as `.confirmed`
    /// — the answer is on the attendee record flagged `isCurrentUser`.
    private static func declined(_ event: EKEvent) -> Bool {
        event.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false
    }

    static func spansMultipleDays(start: Date, end: Date) -> Bool {
        let cal = Calendar.current
        // All-day events end at midnight on the following day, so a one-day
        // event is already a "24 hour" span — compare the last *inclusive* day.
        let lastMoment = end.addingTimeInterval(-1)
        return !cal.isDate(start, inSameDayAs: max(lastMoment, start))
    }

    /// EventKit refuses predicates longer than four years; ours are far shorter.
    private func matching(from: Date, to: Date, includingPlannit: Bool = true) -> [EKEvent] {
        guard canRead else { return [] }
        let all = store.calendars(for: .event)
        let excluded = Self.excludedCalendarIds
        let wanted = all.filter {
            // Our own mirror is excluded from *display* (it would show every
            // plan twice) but never from availability — a plan you said yes to
            // does make you busy.
            if !includingPlannit && $0.title == Self.plannitCalendarTitle { return false }
            return !excluded.contains($0.calendarIdentifier)
        }
        if wanted.isEmpty { return [] }
        // `nil` means "every calendar"; only narrow it when we'd actually
        // exclude something, since an empty array matches nothing.
        let calendars: [EKCalendar]? = wanted.count == all.count ? nil : wanted
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: calendars)
        return store.events(matching: predicate)
    }

    // MARK: - Write (export)

    /// Find or create the dedicated "Plannit" calendar. Returns nil when we
    /// can't write — mirroring is best-effort and must never block the app.
    func plannitCalendar() -> EKCalendar? {
        guard canWrite else { return nil }
        if let existing = store.calendars(for: .event).first(where: {
            $0.title == Self.plannitCalendarTitle && $0.allowsContentModifications
        }) {
            return existing
        }

        Log.cal("creating the Plannit calendar")
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = Self.plannitCalendarTitle
        calendar.cgColor = UIColor(Palette.coral500).cgColor
        // Prefer the source the user's default calendar lives in; fall back to
        // a local source so this works on a device with no accounts.
        calendar.source = store.defaultCalendarForNewEvents?.source
            ?? store.sources.first { $0.sourceType == .local }
            ?? store.sources.first
        guard calendar.source != nil else {
            Log.cal("no writable calendar source — cannot create the Plannit calendar")
            return nil
        }
        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            Log.cal("saveCalendar failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Mirror Plannit-origin events into the Plannit calendar: create what's
    /// new, update what moved, and remove what's gone. Device-origin events are
    /// never written back — the device already owns those.
    @discardableResult
    func mirror(_ events: [PEvent]) -> Int {
        guard canWrite else { Log.cal("mirror skipped: no write access"); return 0 }
        guard let calendar = plannitCalendar() else {
            Log.cal("mirror skipped: no Plannit calendar")
            return 0
        }
        var map = Self.mirrorMap
        var written = 0

        // Series only: mirroring expanded occurrences would write hundreds of
        // one-off events where EventKit can hold a single repeating one.
        let wanted = events.filter { $0.source == .plannit && $0.seriesId == nil }
        for event in wanted {
            let start = event.start
            // Sample rows have no end; an hour is a sane mirror default.
            let end = event.end ?? start.addingTimeInterval(3600)
            let existing = map[event.id].flatMap { store.event(withIdentifier: $0) }
            let ekEvent = existing ?? EKEvent(eventStore: store)

            // Skip the save when nothing actually changed — writing on every
            // load would churn the user's calendar database.
            let sameRule = (existing?.recurrenceRules?.first?.frequency)
                == Recurrence.ekRule(for: event.recurrence)?.frequency
            if let existing, existing.title == event.title,
               existing.startDate == start, existing.endDate == end,
               existing.isAllDay == event.isAllDay,
               existing.location == event.location, sameRule {
                continue
            }

            ekEvent.calendar = calendar
            ekEvent.title = event.title
            ekEvent.startDate = start
            ekEvent.endDate = end
            ekEvent.isAllDay = event.isAllDay
            ekEvent.location = event.location
            // One repeating EKEvent, not 400 copies.
            ekEvent.recurrenceRules = Recurrence.ekRule(for: event.recurrence).map { [$0] }
            ekEvent.notes = "Planned with Plannit"
            do {
                try store.save(ekEvent, span: .thisEvent, commit: false)
                map[event.id] = ekEvent.eventIdentifier
                written += 1
            } catch {
                continue
            }
        }

        // Anything we mirrored before that isn't in the set any more.
        let liveIds = Set(wanted.map(\.id))
        for (eventId, ekId) in map where !liveIds.contains(eventId) {
            if let stale = store.event(withIdentifier: ekId) {
                try? store.remove(stale, span: .thisEvent, commit: false)
            }
            map[eventId] = nil
        }

        try? store.commit()
        Log.cal("mirror: \(wanted.count) plannit events, \(written) written")
        Self.mirrorMap = map
        return written
    }

    private static var mirrorMap: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: mirrorKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: mirrorKey) }
    }
}
