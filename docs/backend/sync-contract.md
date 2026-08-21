# Two-Way Sync Contract (iOS ↔ Backend)

_For the frontend/iOS track. This defines the reconciliation rules the app must
implement so the device calendar and Plannit stay consistent both directions._

## Sources of truth

| Data | Authoritative side |
|---|---|
| Device-origin events (`source = 'device'`) | **The device calendar** (EventKit) |
| Plannit-origin events (`source = 'plannit'`) | **Plannit** (mirrored into a dedicated device calendar) |
| `busy_blocks` (availability) | **The device**, computed on-device, opaque |

Rule of thumb: whoever created an event owns it. Plannit never edits a user's
pre-existing device events; the device never owns Plannit-created ones.

## Identity mapping (the linchpin)

Map each device event to its Plannit row by
**`EKEvent.calendarItemExternalIdentifier`**, stored as `events.external_cal_id`.

- Use `calendarItemExternalIdentifier`, **not** `eventIdentifier` — the latter
  can change (e.g. after some edits or account changes) and is not stable across
  devices. The DB enforces `unique(owner_id, external_cal_id)`.
- Plannit-origin events carry the Plannit `events.id`; when mirrored into the
  device calendar, keep a local map of `events.id → EKEvent.eventIdentifier`.

## A dedicated "Plannit" calendar

Create one `EKCalendar` named "Plannit" and write **only** Plannit-origin events
into it. Never write into the user's existing calendars. This keeps our writes
cleanly separable, reversible, and non-destructive.

## Permissions (iOS 17+)

- Request **write-only** access when the app only needs to add events.
- Request **full access** only when reading device events for import/availability.
  Explain why at the prompt; expect some users to grant write-only.

**Write-only is a real state, not a failure.** `CalendarService.canRead` and
`canWrite` are separate: with write-only, the mirror still runs (plans land on
your calendar) and the app says plainly that availability and the date-finder
can't work. Treating anything short of full access as "no access" meant someone
who granted exactly what the mirror needs got no mirror.

Reads run on `CalendarReader`, an actor with **its own** `EKEventStore`, so a
read never shares a store with the main actor's mirror writes and never blocks
the UI. `EKEventStoreChanged` is coalesced with a 1s trailing debounce, and
`refreshSourcesIfNecessary()` runs on foreground so remote accounts (Exchange,
Google, CalDAV) are pulled before a reconcile.

## Import — device → Plannit

> **Amended 2026-08-14 by decision D-17.** Steps 1–2 below are **not
> implemented, and deliberately so.** Uploading device events would contradict
> what the app promises at the permission prompt — *"Event details stay on your
> device — only free/busy is shared"*. The import is a **local merge**: device
> events are read for display and for deriving `busy_blocks`, and never written
> to `events`. The rest of this section is kept as the design we'd follow if
> that product decision were ever reversed.

1. ~~On first full-access grant, enumerate `EKEvent`s in the sync window
   (e.g. −1 month … +6 months).~~ We enumerate, but only to display and to
   compute availability.
2. ~~For each, upsert an `events` row: `source='device'`,
   `external_cal_id = calendarItemExternalIdentifier`, mapping fields below.~~
   Not done. `source` and `external_cal_id` remain in the schema, unused.
3. While the app runs, observe `EKEventStoreChanged` and re-reconcile the window.
   **Implemented.**
4. On foreground/launch, always run a full reconcile. **Implemented.**

Because nothing is uploaded, the device→server half needs no deltas, tombstones
or `last_synced_at`. Those rules still govern the **export** direction and the
Plannit-origin rows.

## Export — Plannit → device

1. When a Plannit event is created/updated (including a **finalized proposal
   slot**), write/update the matching `EKEvent` in the Plannit calendar.
2. Persist the `events.id → eventIdentifier` mapping locally.
3. On delete (`deleted_at` set), remove the corresponding `EKEvent`.

## Deltas & conflict resolution

- The app keeps a `last_synced_at` high-water mark.
- **Pull:** fetch `events` where `updated_at > last_synced_at` (include rows with
  `deleted_at` set — these are tombstones; apply as deletes).
- **Push:** send locally-changed rows; set `deleted_at` for local deletes rather
  than hard-deleting, so the tombstone propagates.
- **Conflict:** last-write-wins at event granularity, decided by the **server
  `updated_at`** (decision D-07). Practically, collisions are rare because the
  two sides own disjoint event sets.

## Availability — `busy_blocks`

- Derive busy intervals **on-device** from the calendar (merge overlapping
  events into opaque start/end ranges). **No titles, locations, or notes.**
- This is the only availability data that leaves the phone. The `find-slots`
  function reads these (never raw events) to compute group availability.

### The horizon must cover the search window

`find-slots` reads "no busy block" as **free**. A horizon shorter than the
furthest the date-finder can look therefore doesn't make it cautious past the
end — it makes it *confident and wrong*, and the scheduler prefers the earliest
all-free date, which is exactly where the fabricated ones begin.

`Availability.horizon()` follows `SearchWindow.months` (the user's own
preference, 1–12) plus a fortnight of slack for the gap between syncs. It was a
fixed 8 weeks until 2026-08-21, against a 6-month default search.

### Replacing, not appending

Upload through **`replace_busy_blocks(p_blocks jsonb)`** (migration 0012), which
deletes the future window and inserts the new set in one transaction, taking
`user_id` from `auth.uid()` rather than the payload.

The client used to delete and then insert as two calls. Anything happening in
between — a failed insert, a killed app — left the user with **no blocks at
all**, which reads as *free at all times*. Every failure in this path has to
land on "we couldn't check", never on "everyone's free". The client also:

- refuses to upload an empty set when the calendar had events in the window
  (an empty merge means our read broke, not that you're free all year);
- skips the upload entirely when a SHA-256 of the blocks matches the last one.

### What counts as busy

Skipped: events marked **Free**, **cancelled** ones, invitations **you
declined**, and **single-day all-day** events (a birthday shouldn't block a
day). Counted: everything else, including **multi-day all-day** events — five
all-day days called "Portugal" is exactly the week nobody should be offered.

Users can exclude whole calendars (You → Which calendars). Exclusions apply to
display *and* availability: a subscribed fixtures feed shouldn't be able to mark
you busy. The set is stored as the calendars switched **off**, so one added
later is included by default.

## Background refresh

- `EKEventStoreChanged` only fires while the app is running.
- The app **cannot** be notified of local calendar edits when terminated.
  Mitigate with `BGAppRefreshTask` (periodic) + a full reconcile every
  foreground. Remote changes (group events, proposals) arrive via Realtime/APNs.

## Field mapping

| EKEvent | `events` column | Notes |
|---|---|---|
| `calendarItemExternalIdentifier` | `external_cal_id` | stable id, dedupe key |
| `title` | `title` | |
| `notes` | `notes` | not uploaded to `busy_blocks` |
| `location` | `location` | |
| `startDate` | `start_at` | store UTC |
| `endDate` | `end_at` | store UTC |
| `isAllDay` | `all_day` | |
| `timeZone` | `timezone` | IANA; default the user's tz |
| `hasRecurrenceRules` → RRULE | `recurrence_rule` | RFC 5545 string |
| (n/a) | `source` | `'device'` on import, `'plannit'` on create |
| (n/a) | `deleted_at` | tombstone |

## Edge cases to budget for

- **Recurring events & detached occurrences** — expand within the window;
  treat exception occurrences as their own rows keyed by their own external id.
- **All-day events across timezones** — store as all-day, don't shift by tz.
- **DST** — compute busy blocks from absolute instants; the scheduler already
  evaluates "afternoon" in local time separately.
