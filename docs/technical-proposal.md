# Technical Proposal

_Version 0.1 — 2026-08-13._

## Architecture at a glance

```
┌─────────────── iOS App (Swift / SwiftUI) ──────────────┐
│  EventKit  ↔  Local store (GRDB/SQLite)  ↔  Sync engine │
│  Sign in with Apple · APNs receiver · SwiftUI views     │
└───────────────────────────┬────────────────────────────┘
                            │  HTTPS (REST) + WebSocket (realtime)
┌───────────────────────────▼────────────────────────────┐
│  Backend  (Supabase)                                    │
│  Postgres  ·  Auth (Apple)  ·  Row-Level Security       │
│  Realtime channels  ·  Edge Functions (scheduler, APNs) │
└───────────────────────────┬────────────────────────────┘
                            │
        APNs push  ·  Object storage (avatars)  ·  Sentry
```

The **device is the source of truth for the user's real calendar**; **Supabase is the source of truth for groups, shares, and proposed dates.** Availability is computed on-device into opaque busy/free blocks so raw private event details never leave the phone unless explicitly shared.

## 1. iOS client

- **Language/UI:** Swift + SwiftUI, target **iOS 17+**.
- **Calendar integration:** EventKit / EventKitUI.
  - iOS 17 permission model: **write-only vs full access**. Request write-only when only adding events (friendlier prompt); request full access only to read events for availability.
  - **Create a dedicated "Plannit" `EKCalendar`** so app-created events never pollute or corrupt the user's existing calendars.
- **Local persistence:** GRDB (SQLite) offline-first cache.
- **Networking:** URLSession + async/await; realtime over WebSocket (Supabase Realtime).
- **Auth:** Sign in with Apple.
- **Push:** APNs for new group events, invites, and "a date was found."

## 2. Two-way sync engine (the hard part)

- **Device → Plannit:** read `EKEvent`s; observe `EKEventStoreChanged` for live edits while running; full reconcile on every foreground/launch.
- **Plannit → Device:** write app-created events into the dedicated Plannit calendar.
- **Identity mapping:** map Plannit IDs to **`calendarItemExternalIdentifier`** (stable across devices), _not_ `eventIdentifier` (can change).
- **Deltas:** `updated_at` timestamps + tombstones for deletes; last-write-wins at event granularity for v1.

**iOS traps to budget for:**
- You **cannot** get background notifications of local calendar edits when the app is killed → use `EKEventStoreChanged` while running + `BGAppRefreshTask` + foreground reconcile. Group events from others arrive via WebSocket/APNs.
- Recurring events, detached/exception occurrences, all-day events across timezones, and DST are where calendar apps bleed time.

## 3. Backend — Supabase

- **Postgres** for relational group/membership/event/visibility data.
- **Row-Level Security (RLS)** is the exact primitive for "show event X only to group Y" — enforced server-side, not bypassable from the client.
- **Realtime** for live group feeds; **Auth** with Apple; **Edge Functions** (TypeScript/Deno) for the scheduler and APNs sender.
- Open-source, so it can be self-hosted later to control cost at scale.

## 4. Data model

```
// identity & social
User(id, apple_sub, display_name, avatar, timezone)
Friendship(user_a, user_b, status)
Group(id, name, owner_id, avatar)
GroupMembership(group_id, user_id, role)

// calendar
Event(id, owner_id, title, start, end, all_day, location, notes,
      source: plannit|device, external_cal_id, recurrence_rule, updated_at)
EventShare(event_id, group_id | user_id, visibility_level)   // ← selective display
BusyBlock(user_id, start, end)      // ← privacy-safe availability, no titles

// the scheduler
Proposal(id, group_id, constraints_json, status)
ProposalSlot(proposal_id, start, end, score, available_user_ids)
Vote(proposal_id, slot_id, user_id, response)
```

**Privacy rule:** personal events are private by default; sharing to a group is an explicit `EventShare` row. For finding dates, only opaque `BusyBlock`s (no titles) are used, enforced by RLS.

## 5. The scheduler (the wedge)

An interval-scheduling problem, not an AI problem. Dozens of members × a few weeks = trivial for a sweep-line.

1. **Collect availability** — gather each member's `BusyBlock`s across the search window.
2. **Generate candidate slots** — enumerate slots satisfying hard constraints (allowed days, time window, duration), discretised to 30-min steps.
3. **Compute who's free** — sweep-line / interval overlap per candidate; apply quorum (e.g. "≥5 of 6").
4. **Score & rank** — by count available, then earliest date and preferences.
5. **Auto-pick or vote** — lock the best slot or hand the top slots to the group; write the winning event to everyone's calendar.

**Timezones:** "weekend afternoon" is inherently local. Store everything in UTC but evaluate day-of-week and hour in each participant's (or the group's) local timezone.

## 6. Delivery phases

| Phase | Scope |
|---|---|
| **1 — Foundation** | Sign in with Apple · read device calendar · personal calendar view · two-way sync via dedicated Plannit calendar |
| **2 — Social** | Friends + groups · selective event sharing to groups · realtime group feed · push notifications |
| **3 — The wedge** | Constraint-based auto date-finder · busy-block availability model · slot proposals + voting/RSVP · write winning date to all calendars |

**Architect now:** even though the scheduler ships in Phase 3, design the busy-block and group/constraint data model in Phase 1 so the privacy-safe availability path never needs a retrofit.

## 7. Ops

APNs (push) · Supabase Storage (avatars) · Sentry (crashes) · Xcode Cloud or GitHub Actions + fastlane (CI) · TestFlight (beta) · privacy nutrition labels (calendar data is sensitive).
