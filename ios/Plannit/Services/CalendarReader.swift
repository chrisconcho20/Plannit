import EventKit
import Foundation

// CalendarReader — every read of the device calendar, off the main thread.
//
// Reading was previously a plain call from `AppModel`, which is `@MainActor`:
// `store.events(matching:)` over a real calendar with three accounts is hundreds
// of milliseconds of work, and it ran on launch, on every foreground, and on
// every calendar change. On an empty simulator that's free; on a full phone it's
// a visible stall at exactly the moments the app should feel quickest.
//
// An actor rather than a bare `Task.detached` because EventKit is not documented
// as thread-safe: this serialises every read through one executor. It also keeps
// its **own** `EKEventStore`, separate from the one the main actor uses for
// mirroring, so a read and a write can never touch the same store concurrently.
// Nothing crosses the boundary but value types — no `EKEvent` ever escapes.

actor CalendarReader {
    /// One reader for the app, shared with the background refresh task. Apple's
    /// guidance is to keep an event store long-lived rather than making one per
    /// call.
    static let shared = CalendarReader()

    private let service = CalendarService()

    /// Merged busy ranges plus the event count they came from.
    func read(until horizon: Date = Availability.horizon()) -> BusyReading {
        service.read(until: horizon)
    }

    /// Device events for display, for a window that follows what's on screen.
    func deviceEvents(daysAhead: Int) -> [DeviceEvent] {
        service.fetchDeviceEvents(daysAhead: daysAhead, limit: nil)
    }

    /// Pull remote accounts (CalDAV, Exchange, Google) before a reconcile.
    ///
    /// EventKit doesn't necessarily fetch server-side changes on its own while
    /// we're in the foreground, so an event added on a laptop can be missing
    /// from availability for a while. This is the documented nudge, and it's
    /// cheap enough to do on every foreground.
    func refreshSources() {
        service.store.refreshSourcesIfNecessary()
    }
}
