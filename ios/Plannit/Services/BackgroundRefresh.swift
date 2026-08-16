import BackgroundTasks
import Foundation

// BackgroundRefresh — keep availability from going stale while the app is shut.
//
// The problem the sync contract calls out: EKEventStoreChanged only fires while
// we're running, so anything you add to your calendar with Plannit closed is
// invisible to the scheduler until you next open it. Someone could be offered a
// time they've since filled.
//
// iOS decides if and when this runs — it's a request, not a schedule. The
// foreground reconcile stays the mechanism we rely on; this just narrows the
// window.

enum BackgroundRefresh {
    /// Must also appear in Info.plist under BGTaskSchedulerPermittedIdentifiers.
    static let identifier = "com.plannit.app.refresh"

    /// Ask for another run. Cheap and idempotent — call it whenever we background.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        // No sooner than a couple of hours; the system will do as it pleases.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Recompute availability from the device calendar and push it. Deliberately
    /// the *only* thing that happens here: it's the one piece of state that goes
    /// stale without us, it needs no UI, and it's a single round trip.
    static func run() async {
        Log.sync("background refresh fired")
        await MainActor.run { _ = SupabaseClient.shared.restoreSession() }
        await AvailabilityUploader.upload(calendar: CalendarService())
        schedule()   // one run only ever earns the next
    }
}

/// Shared by the app and the background task, so the rules about what leaves the
/// phone live in exactly one place.
enum AvailabilityUploader {
    @MainActor
    static func upload(calendar: CalendarService) async {
        guard SupabaseClient.shared.isConfigured, SupabaseClient.shared.isSignedIn,
              let uid = SupabaseClient.shared.userId else { return }

        let iso = ISO8601DateFormatter()
        let now = Date()
        let blocks = calendar.busyIntervals().map {
            BusyBlockInsert(user_id: uid,
                            start_at: iso.string(from: $0.start),
                            end_at: iso.string(from: $0.end))
        }
        do {
            // Replace the future window rather than appending to it — a plain
            // insert stacked a fresh copy of the calendar every time.
            try await SupabaseClient.shared.delete("busy_blocks", match: [
                "user_id": "eq.\(uid)", "end_at": "gte.\(iso.string(from: now))",
            ])
            guard !blocks.isEmpty else { return }
            try await SupabaseClient.shared.insert("busy_blocks", values: blocks)
        } catch {
            // Best-effort: the next foreground sync tries again.
        }
    }
}
