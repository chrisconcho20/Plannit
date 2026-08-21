import BackgroundTasks
import CryptoKit
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
        await CalendarReader.shared.refreshSources()
        await AvailabilityUploader.upload(reading: CalendarReader.shared.read())
        schedule()   // one run only ever earns the next
    }
}

/// Shared by the app and the background task, so the rules about what leaves the
/// phone live in exactly one place.
enum AvailabilityUploader {
    /// When the last upload succeeded, for the You screen. Nil until one has.
    @MainActor private(set) static var lastUploadedAt: Date?
    /// Set when the last attempt failed, so the UI can say so instead of
    /// looking merely quiet.
    @MainActor private(set) static var lastUploadFailed = false
    /// Digest of what we last sent. An unchanged calendar shouldn't cost a
    /// write on every foreground.
    private static let digestKey = "plannit.busyDigest"

    @MainActor
    static func upload(reading: BusyReading) async {
        guard SupabaseClient.shared.isConfigured, SupabaseClient.shared.isSignedIn,
              SupabaseClient.shared.userId != nil else { return }

        let iso = ISO8601DateFormatter()
        let blocks = reading.blocks

        // An empty upload is indistinguishable from "free all year", and it is
        // the shape every bug in this path produces. If the calendar had events
        // in the window, an empty merge means something went wrong on our side
        // — keep yesterday's blocks and say so in the log.
        if blocks.isEmpty && reading.eventCount > 0 {
            Log.cal("busy: refusing to upload an empty set — the calendar isn't empty")
            lastUploadFailed = true
            return
        }

        let payload = blocks.map {
            BusyBlockRow(start_at: iso.string(from: $0.start), end_at: iso.string(from: $0.end))
        }
        let digest = Self.digest(of: payload)
        guard digest != UserDefaults.standard.string(forKey: digestKey) else {
            Log.cal("busy: unchanged since the last upload, skipping")
            lastUploadFailed = false
            return
        }

        do {
            // One transaction, server-side. The old delete-then-insert pair left
            // a window — and a whole failure mode — where you looked free.
            try await SupabaseClient.shared.rpcVoid(
                "replace_busy_blocks", args: ReplaceBusyBlocksArgs(p_blocks: payload))
            UserDefaults.standard.set(digest, forKey: digestKey)
            lastUploadedAt = Date()
            lastUploadFailed = false
            Log.cal("busy: uploaded \(payload.count) blocks")
        } catch {
            // Best-effort: the next foreground sync tries again. The previous
            // blocks are still there, which is the right way to fail.
            lastUploadFailed = true
            Log.cal("busy: upload failed, keeping the previous blocks")
        }
    }

    /// Content hash of what we're about to send. SHA-256 rather than
    /// `Hasher`, which is seeded per process — the digest has to mean the same
    /// thing after a relaunch or it never matches and never saves a write.
    ///
    /// The list is already clipped, sorted and merged, so equal strings really
    /// do mean equal availability.
    private static func digest(of blocks: [BusyBlockRow]) -> String {
        let joined = blocks.map { "\($0.start_at)/\($0.end_at)" }.joined(separator: ",")
        return SHA256.hash(data: Data(joined.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
