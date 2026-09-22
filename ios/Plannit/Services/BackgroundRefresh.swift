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

    /// Two things go stale while the app is shut: your availability, and the
    /// Plannit calendar on the phone — a plan its owner deleted would otherwise
    /// stay there until you next opened Plannit.
    static func run() async {
        Log.sync("background refresh fired")
        await MainActor.run { _ = SupabaseClient.shared.restoreSession() }
        await CalendarReader.shared.refreshSources()
        await AvailabilityUploader.upload(reading: CalendarReader.shared.read())
        await refreshPlannitCalendar()
        schedule()   // one run only ever earns the next
    }

    /// Re-read the plans and bring the Plannit calendar into line. A failed
    /// fetch changes nothing: mirroring an empty list would remove every copy.
    @MainActor
    static func refreshPlannitCalendar() async {
        guard SupabaseClient.shared.isSignedIn, let uid = SupabaseClient.shared.userId,
              let events = try? await SupabaseRepository().fetchEvents(groups: [])
        else { return }
        CalendarService().mirror(AppModel.calendarCopies(of: events, for: uid))
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
        guard AvailabilitySharing.isOn else {
            Log.cal("busy: sharing is off, nothing uploaded")
            return
        }

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

    /// Turning sharing off has to remove what was already uploaded — leaving
    /// yesterday's blocks behind would keep answering for you. The digest goes
    /// too, so turning sharing back on uploads afresh rather than deciding
    /// nothing has changed.
    @MainActor
    static func clearUploaded() async {
        guard SupabaseClient.shared.isConfigured, SupabaseClient.shared.isSignedIn else { return }
        do {
            try await SupabaseClient.shared.rpcVoid(
                "replace_busy_blocks", args: ReplaceBusyBlocksArgs(p_blocks: []))
            UserDefaults.standard.removeObject(forKey: digestKey)
            lastUploadedAt = nil
            lastUploadFailed = false
            Log.cal("busy: cleared the uploaded blocks")
        } catch {
            lastUploadFailed = true
            Log.cal("busy: couldn't clear the uploaded blocks")
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
