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

## Import — device → Plannit

1. On first full-access grant, enumerate `EKEvent`s in the sync window
   (e.g. −1 month … +6 months).
2. For each, upsert an `events` row: `source='device'`,
   `external_cal_id = calendarItemExternalIdentifier`, mapping fields below.
3. While the app runs, observe `EKEventStoreChanged` and re-reconcile the window.
4. On foreground/launch, always run a full reconcile (see Deltas).

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
- Upsert them into `busy_blocks` covering the scheduling horizon (e.g. next
  8 weeks); refresh on calendar change and on a periodic background task.
- This is the only availability data that leaves the phone. The `find-slots`
  function reads these (never raw events) to compute group availability.

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
