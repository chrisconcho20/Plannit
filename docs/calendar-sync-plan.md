# Device calendar → Plannit: research and plan

_Written 2026-08-21. Scope: everything between the phone's calendar and Plannit.
Read [`backend/sync-contract.md`](backend/sync-contract.md) for the contract this
either implements or amends, and D-05 / D-17 in [`decisions.md`](decisions.md)._

---

## 0. The one thing to decide first

"Sync my phone's events to Plannit" has two readings, and they build different
products:

| | **A — local merge** (what D-17 chose) | **B — server upload** |
|---|---|---|
| Where device events live | On the phone only | Rows in `events`, `source='device'` |
| What leaves the phone | Merged free/busy ranges, no titles | Titles, locations, times, notes |
| Cross-device | Each phone reads its own calendar | Your events follow your account |
| Permission prompt promise | Kept | **Broken** — the prompt says details stay local |
| Work | Contained, all client-side | Deltas, tombstones, conflict resolution, a privacy review |

**Recommendation: stay with A.** The deciding factor isn't effort, it's that
`NSCalendarsFullAccessUsageDescription` currently reads *"Event details stay on
your device — only free/busy is shared."* That sentence is shown at a system
permission dialog, which is the most load-bearing promise the app makes. B is a
product decision that needs a new prompt, a new privacy policy line, and an App
Store privacy label change — not a sync feature.

Everything below assumes A. §7 says what changes if you ever want B.

The honest framing for A: **the device calendar is not a source we import, it's
a source we _read_.** "Sync" here means the app's calendar screen shows one
merged truth, availability is always current, and Plannit's own plans land back
on the phone. Two of those three are half-built today.

---

## 1. What exists

| Piece | Where | State |
|---|---|---|
| Access request (iOS 17 full access) | `CalendarService.requestAccess()` | Works |
| Read device events for display | `fetchDeviceEvents(daysBack:1, daysAhead:60)` | Works, windowed |
| Derive busy ranges | `busyIntervals(daysAhead:56)` + `Availability.prepare` | Works, tested |
| Upload availability | `AvailabilityUploader.upload` | Works, fragile (F2) |
| Mirror Plannit plans → "Plannit" EKCalendar | `CalendarService.mirror` | Works, dedupes, handles recurrence |
| React to calendar edits while open | `EKEventStoreChanged` → `syncCalendar()` | Works, unthrottled |
| Catch up when closed | `BGAppRefreshTask` every ≥2h + foreground reconcile | Works |
| Show device events | Calendar tab, *"Also on your calendar"* section | Works, second-class |

The bones are good. What follows are the gaps, in the order they hurt.

---

## 2. Findings

### F1 — Availability covers 8 weeks; the finder searches 6 months 🔴

`busyIntervals(daysAhead: 56)` (`CalendarService.swift:93`) uploads eight weeks.
`SearchWindow.defaultMonths` is **6**, and the finder offers 12.

`find-slots` treats "no busy block" as free. So **every date past week 8 comes
back "6 of 6 free" whether or not anyone is**, and the scheduler prefers the
earliest all-free date — which is exactly where the fabricated ones start. The
wedge's headline answer is unearned beyond two months.

This is the most important thing on this page. It is also invisible in testing:
an empty simulator has no events past week 8 either.

**Fix:** the busy horizon must be ≥ the largest search window the user can pick.
Six months of merged blocks is small (a busy calendar merges to a few hundred
rows), but the upload should then be incremental rather than a full replace —
see F2.

### F2 — The availability upload deletes before it inserts 🔴

`BackgroundRefresh.swift:56-60`: delete every future block, then insert the new
set. Two ways that ends badly — the insert fails (offline, 401, payload too
large), or the app is killed between the two calls. Either leaves the user with
**zero busy blocks**, i.e. "free at all times", until the next successful sync.
The failure is silent, and it fails *toward* being offered times you can't make.

**Fix:** one `replace_busy_blocks(p_blocks jsonb)` RPC that deletes and inserts
in a single transaction. Cheap, and it also halves the round trips.

### F3 — Every occurrence of a repeating device event has the same id 🟠

`DeviceEvent.id = eventIdentifier` (`CalendarService.swift:77`). EventKit gives
[every occurrence of a recurring event the same `eventIdentifier`][apeth], and
`store.events(matching:)` returns occurrences. `ForEach(deviceEvents)`
(`CalendarScreen.swift:188`) is therefore iterating duplicate ids: SwiftUI logs
*"ID occurs multiple times"* and renders the wrong rows.

Anyone with a weekly standup hits this on the first launch on a real phone. It
cannot happen on an empty simulator.

**Fix:** `id = "\(eventIdentifier)#\(startDate.timeIntervalSince1970)"`, exactly
the pattern `PEvent.occurrences` already uses for Plannit series.

### F4 — The read window is fixed at +60 days 🟠

`fetchDeviceEvents(daysAhead: 60)`. Scroll the month grid to November and your
own events silently stop existing — no rows, and no dots on the grid, because
`marks` is built from the same array. The app looks like it lost your calendar.

**Fix:** fetch for the window being *looked at*. Keep a rolling cache keyed by
month, extend on scroll, and stop pretending one fixed array serves both the
grid and the list.

### F5 — EventKit runs on the main actor 🟠

`AppModel` is `@MainActor`, and `fetchDeviceEvents` / `busyIntervals` are plain
synchronous calls into `store.events(matching:)`. On a real calendar with
several accounts that is hundreds of milliseconds of main-thread work, on
launch, on every foreground, and on every calendar change.

**Fix:** move both reads to a detached task on a background `EKEventStore`
(long-lived, one per app — the [documented pattern][ekstore]), hop back to the
main actor with the finished arrays.

### F6 — `EKEventStoreChanged` isn't debounced 🟡

`AppModel.swift:108` reconciles on every notification. Saving several events
(or a remote account syncing) fires it repeatedly, and each one currently costs
a full read + merge + network upload on the main thread.

**Fix:** coalesce with a ~1s trailing debounce.

### F7 — Remote calendar changes aren't pulled while the app is open 🟡

Nothing calls `store.refreshSourcesIfNecessary()`. For CalDAV/Exchange/Google
accounts, EventKit doesn't necessarily fetch server-side changes on its own
while we're foreground, so an event added on a laptop can be missing from our
availability for a while.

**Fix:** call it on foreground, before the reconcile.

### F8 — Deny full access and the app does nothing at all 🟡

`hasAccess` is `== .fullAccess` only, and `plannitCalendar()` guards on it. So a
user who grants **write-only** — a reasonable choice, and one iOS 17 actively
encourages — gets no mirror either, though writing is precisely what they
allowed. `NSCalendarsWriteOnlyAccessUsageDescription` is already in `Info.plist`
and unused.

Worth knowing: [`EKEventEditViewController` needs no permission at all][wwdc23]
in iOS 17+. Even a full denial leaves us a way to put a plan on someone's
calendar, via the system's own sheet.

**Fix:** split `canRead` / `canWrite`; mirror on write-only; offer the system
edit sheet as the fallback when both are denied.

### F9 — No per-calendar control 🟡

Every calendar is read: work, holidays, birthdays, a subscribed football
fixtures feed. Two consequences — the list fills with things you don't think of
as your plans, and (worse) a subscribed calendar can mark you *busy* for the
scheduler. There is no way to say "ignore Holidays".

**Fix:** a calendar picker in You → Your calendar, persisted as a set of
`calendarIdentifier`s, applied to both the display read and the busy read. This
is table stakes for anyone with a shared family calendar.

### F10 — Declined invitations count as busy 🟡

`busyIntervals` filters all-day, `.free` availability and `.canceled` status,
but not events you've **declined** (`participantStatus == .declined`). You told
your colleague you're not coming; Plannit still thinks you're in that meeting.

### F11 — Device events are a separate list, not part of the day 🟡

They render in an *"Also on your calendar"* section below Plannit's events
rather than interleaved by time. The day reads as two calendars stacked, which
is the exact thing Plannit exists to stop being.

**Fix:** merge into one time-ordered list. Keep the visual distinction (muted
colour, "Private" badge) — the *source* should be legible without the *list*
being split.

### F12 — Multi-day all-day events never block (decision)

Deliberate: a birthday shouldn't make you busy. But a five-day all-day event
called *"Portugal"* also doesn't, and that one absolutely should.

**Proposal:** all-day events spanning **≥ 2 days** count as busy for their whole
span; single-day all-day events keep being ignored. Cheap heuristic, right
almost always.

### F13 — Nothing tells the user the sync is alive 🟢

There's one line in You: *"N events read. Only free/busy is shared."* No last-
synced time, no indication that availability was uploaded, nothing when it
fails. The user cannot tell "Plannit knows my calendar" from "Plannit hasn't
looked since Tuesday".

---

## 3. The plan

Four phases. A is correctness and should land as one commit; B and C are
product; D is polish. Each item names the file it lives in.

### Phase A — make availability true (highest value, ~half a day)

1. **`0012_replace_busy_blocks.sql`** — `replace_busy_blocks(p_blocks jsonb)`,
   `security definer`, `user_id = auth.uid()` forced server-side (never trusted
   from the payload), delete-future + insert in one transaction. *(F2)*
2. **Extend the horizon to the search window.** `busyIntervals(daysAhead:)`
   driven by `SearchWindow.months` + a fortnight of slack, so the finder never
   answers about time it has no data for. *(F1)*
3. **Skip declined invitations**, and count multi-day all-day events as busy.
   Both are one-line filters in `busyIntervals`, both get a unit test in
   `AvailabilityTests`. *(F10, F12)*
4. **Guard rail:** if the merged set is empty and the calendar has ≥1 event in
   the window, don't upload — log it. An empty upload is indistinguishable from
   "I'm free all year", and we should never send that by accident.

**Verified by:** new unit tests for horizon and filters; on-device, add an event
four months out and confirm the finder stops offering that slot.

### Phase B — one calendar, not two (~a day)

5. **Fix the occurrence id** and merge device events into the day's list,
   time-ordered, keeping the muted styling and "Private" badge. *(F3, F11)*
6. **Window follows the view.** A `DeviceEventCache` keyed by month; the grid
   and the list both read from it; scrolling extends it. Dots come from the same
   source, so they stop disappearing. *(F4)*
7. **Device events open a detail view** — read-only, with an *"Edit in
   Calendar"* button that opens the system sheet. Today they aren't tappable,
   which reads as broken.

**Verified by:** on device, a weekly standup renders once per week without
duplicate-id warnings; scroll to +4 months and events are still there.

### Phase C — control and trust (~a day)

8. **Calendar picker** in You → Your calendar: every calendar with a toggle,
   defaulting to on, persisted by `calendarIdentifier`. Applied to both reads.
   *(F9)*
9. **Sync status** in the same place: "Last synced 2 minutes ago · 143 events ·
   38 busy blocks shared", plus a failure line when the last upload failed and a
   Retry. *(F13)*
10. **Write-only support.** `canRead` / `canWrite` split; mirror works on
    write-only; when reading is denied, the app says what it can't do
    (availability, the date-finder) rather than looking empty. *(F8)*

### Phase D — robustness (~half a day)

11. **Move EventKit off the main actor** — a background store, `nonisolated`
    read functions, results handed back to `@MainActor`. *(F5)*
12. **Debounce `EKEventStoreChanged`** (~1s trailing) and call
    `refreshSourcesIfNecessary()` on foreground. *(F6, F7)*
13. **Skip no-op uploads** by hashing the merged blocks and storing the digest;
    an unchanged calendar shouldn't cost a write. Pairs with the longer horizon
    from A2.

---

## 4. What this does not change

- **No device event ever reaches the server.** D-17 stands; §7 is the escape
  hatch if that's ever revisited.
- **Plannit never writes to your calendars** — only to its own "Plannit" one.
- **The mirror stays one-way.** Editing a mirrored event in Apple Calendar does
  not edit the Plannit event; the next reconcile overwrites it. Worth a note in
  the event's `notes` field so the user isn't surprised.

---

## 5. Decisions this needs

| # | Question | Recommendation |
|---|---|---|
| a | Upload device events to the server? | **No** — keep D-17 (§0) |
| b | Busy horizon | **Match the search window**, capped at 12 months |
| c | Multi-day all-day events | **Busy**; single-day all-day stays free |
| d | New calendars found later | **Included by default**, listed in the picker |
| e | Declined invitations | **Not busy** |

(b) is the only one with a cost worth naming: six months of blocks is more rows
per user and a slower `find-slots` read. Both are small at beta scale, and the
alternative is answering confidently about time we know nothing about.

---

## 6. Test coverage to add

- `AvailabilityTests` — horizon length, declined filter, multi-day all-day,
  the empty-upload guard.
- `DeviceEventTests` (new) — occurrence id uniqueness, month-window cache
  extension, calendar exclusion.
- `docs/tests/02-calendar-access.md` — extend with: a repeating event renders
  once per occurrence; a four-month-out event affects the finder; excluding a
  calendar removes it from both the list and availability; airplane mode during
  a sync leaves availability intact (F2's regression).

---

## 7. If B is ever wanted (upload device events)

Keep this short and don't half-do it. It needs, in order: a new permission
string and privacy label; `events.external_cal_id` as the dedupe key (already in
the schema, already unique per owner); a `last_synced_at` high-water mark;
tombstones for deletions the phone made while offline; and last-write-wins on
server `updated_at` per D-07. The sync contract's Import section already
specifies all of it — it was written for exactly this, then suspended by D-17.

The feature that would justify it: *"what are my friends actually doing"* —
shared visibility of real events rather than opaque busy blocks. That's a
different product from the one the permission prompt describes today.

[apeth]: https://www.apeth.com/iOSBook/ch32.html
[ekstore]: https://learn.microsoft.com/en-us/dotnet/api/eventkit.ekeventstore
[wwdc23]: https://github.com/gromb57/ios-wwdc23__AccessingCalendarUsingEventKitAndEventKitUI
