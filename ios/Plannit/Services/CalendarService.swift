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

struct DeviceEvent: Identifiable, Hashable {
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

    var hasAccess: Bool {
        if #available(iOS 17.0, *) {
            return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        }
        return EKEventStore.authorizationStatus(for: .event) == .authorized
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
            DeviceEvent(id: $0.eventIdentifier ?? UUID().uuidString,
                        externalId: $0.calendarItemExternalIdentifier,
                        title: $0.title ?? "Event",
                        start: $0.startDate,
                        end: $0.endDate,
                        location: $0.location,
                        isAllDay: $0.isAllDay)
        }
    }

    /// Privacy-safe availability: merged busy ranges as absolute times.
    ///
    /// Every event in the horizon counts — a cap here would quietly tell the
    /// scheduler you're free when you aren't. Skipped: all-day events (a
    /// birthday shouldn't block the day), events you've marked Free, and
    /// cancelled ones.
    func busyIntervals(daysAhead: Int = 56) -> [BusyInterval] {
        let now = Date()
        let horizon = Calendar.current.date(byAdding: .day, value: daysAhead, to: now) ?? now
        let raw = matching(from: now, to: horizon)
            .filter { !$0.isAllDay && $0.availability != .free && $0.status != .canceled }
            .map { BusyInterval(start: $0.startDate, end: $0.endDate) }
        return Availability.prepare(raw, from: now, to: horizon)
    }

    /// EventKit refuses predicates longer than four years; ours are far shorter.
    private func matching(from: Date, to: Date, includingPlannit: Bool = true) -> [EKEvent] {
        guard hasAccess else { return [] }
        var calendars: [EKCalendar]? = nil
        if !includingPlannit {
            let all = store.calendars(for: .event)
            let others = all.filter { $0.title != Self.plannitCalendarTitle }
            // `nil` means "every calendar"; only narrow it if we'd actually
            // exclude something, since an empty array matches nothing.
            calendars = others.count == all.count ? nil : others
            if others.isEmpty { return [] }
        }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: calendars)
        return store.events(matching: predicate)
    }

    // MARK: - Write (export)

    /// Find or create the dedicated "Plannit" calendar. Returns nil when we
    /// can't write — mirroring is best-effort and must never block the app.
    func plannitCalendar() -> EKCalendar? {
        guard hasAccess else { return nil }
        if let existing = store.calendars(for: .event).first(where: {
            $0.title == Self.plannitCalendarTitle && $0.allowsContentModifications
        }) {
            return existing
        }

        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = Self.plannitCalendarTitle
        calendar.cgColor = UIColor(Palette.coral500).cgColor
        // Prefer the source the user's default calendar lives in; fall back to
        // a local source so this works on a device with no accounts.
        calendar.source = store.defaultCalendarForNewEvents?.source
            ?? store.sources.first { $0.sourceType == .local }
            ?? store.sources.first
        guard calendar.source != nil else { return nil }
        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            return nil
        }
    }

    /// Mirror Plannit-origin events into the Plannit calendar: create what's
    /// new, update what moved, and remove what's gone. Device-origin events are
    /// never written back — the device already owns those.
    @discardableResult
    func mirror(_ events: [PEvent]) -> Int {
        guard hasAccess, let calendar = plannitCalendar() else { return 0 }
        var map = Self.mirrorMap
        var written = 0

        let wanted = events.filter { $0.source == .plannit }
        for event in wanted {
            let start = event.start
            // Sample rows have no end; an hour is a sane mirror default.
            let end = event.end ?? start.addingTimeInterval(3600)
            let existing = map[event.id].flatMap { store.event(withIdentifier: $0) }
            let ekEvent = existing ?? EKEvent(eventStore: store)

            // Skip the save when nothing actually changed — writing on every
            // load would churn the user's calendar database.
            if let existing, existing.title == event.title,
               existing.startDate == start, existing.endDate == end,
               existing.isAllDay == event.isAllDay,
               existing.location == event.location {
                continue
            }

            ekEvent.calendar = calendar
            ekEvent.title = event.title
            ekEvent.startDate = start
            ekEvent.endDate = end
            ekEvent.isAllDay = event.isAllDay
            ekEvent.location = event.location
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
        Self.mirrorMap = map
        return written
    }

    private static var mirrorMap: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: mirrorKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: mirrorKey) }
    }
}
