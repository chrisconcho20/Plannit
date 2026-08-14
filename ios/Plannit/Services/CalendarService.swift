import EventKit
import Foundation

// Real EventKit access — works in the iOS Simulator (add events in the
// Simulator's Calendar app to see them here). See docs/backend/sync-contract.md.

struct DeviceEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let isAllDay: Bool
}

final class CalendarService {
    let store = EKEventStore()

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

    /// Events in a window around today, mapped to a lightweight model.
    func fetchDeviceEvents(daysBack: Int = 1, daysAhead: Int = 60) -> [DeviceEvent] {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .day, value: -daysBack, to: now) ?? now
        let end = cal.date(byAdding: .day, value: daysAhead, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(50)
            .map { ek in
                DeviceEvent(id: ek.eventIdentifier ?? UUID().uuidString,
                            title: ek.title ?? "Event",
                            start: ek.startDate,
                            end: ek.endDate,
                            location: ek.location,
                            isAllDay: ek.isAllDay)
            }
    }

    /// Privacy-safe availability: merged busy intervals as absolute times.
    /// This is what would be uploaded to `busy_blocks` (no titles) in the wiring phase.
    func busyIntervals(daysAhead: Int = 56) -> [(start: Date, end: Date)] {
        fetchDeviceEvents(daysBack: 0, daysAhead: daysAhead)
            .filter { !$0.isAllDay }
            .map { ($0.start, $0.end) }
    }
}
