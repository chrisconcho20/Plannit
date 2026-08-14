# Backend API Contract (v0.1)

_For the frontend/iOS track. This is the stable interface to build against while the backend is finished in parallel. Breaking changes will be versioned and called out here._

Plannit's backend is **Supabase**, so the iOS app talks to it two ways:

1. **Direct table access** via the Supabase Swift client (PostgREST + Realtime). Row-Level Security enforces who can see what — the client just queries; the database refuses anything it shouldn't return.
2. **One Edge Function**, `find-slots`, for the scheduler (the wedge).

Base URL (local): `http://localhost:54321`. Anon key and URL come from `supabase start`.

---

## Auth

Sign in with Apple via Supabase Auth. On first sign-in a `profiles` row is created automatically (via a DB trigger) from the Apple identity. Pass `display_name` and the device `timezone` in the sign-up metadata so "weekend afternoon" evaluates in the user's local zone.

```swift
let client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
try await client.auth.signInWithIdToken(
  credentials: .init(provider: .apple, idToken: appleIdToken, nonce: nonce)
)
```

---

## Tables the client uses

All timestamps are ISO-8601 UTC (`timestamptz`). RLS rules in brackets summarize visibility.

| Table | Key columns | Client visibility (RLS) |
|---|---|---|
| `profiles` | `id, display_name, avatar_url, timezone` | self + friends + group co-members |
| `friendships` | `requester_id, addressee_id, status` | the two parties only |
| `groups` | `id, name, owner_id, avatar_url` | owner + members |
| `group_memberships` | `group_id, user_id, role` | members of that group |
| `events` | `id, owner_id, title, notes, location, start_at, end_at, all_day, timezone, source, external_cal_id, recurrence_rule, deleted_at` | owner, or anyone the event is shared to |
| `event_shares` | `event_id, group_id?, shared_user_id?` | event owner + share targets |
| `busy_blocks` | `user_id, start_at, end_at` | **owner only** (never another user) |
| `proposals` | `id, group_id, created_by, title, constraints, window_start, window_end, status, finalized_slot_id` | group members |
| `proposal_slots` | `id, proposal_id, start_at, end_at, score, available_user_ids` | group members |
| `votes` | `proposal_id, slot_id, user_id, response` | group members; you write only your own |

### Privacy model the client must honor
- **Personal events are private by default.** To reveal one to a group, insert an `event_shares` row (`event_id` + `group_id`). To share with one person, use `shared_user_id`.
- **Availability is uploaded as `busy_blocks` only** — start/end, no titles. The client computes these on-device from the calendar and pushes them. Raw events never leave the phone unless explicitly shared.

### Example queries (Supabase Swift)

```swift
// My upcoming events
let events: [Event] = try await client
  .from("events")
  .select()
  .is("deleted_at", value: nil)
  .gte("start_at", value: ISO8601DateFormatter().string(from: Date()))
  .order("start_at")
  .execute().value

// Share an event with a group
try await client.from("event_shares")
  .insert(["event_id": eventID, "group_id": groupID]).execute()

// Upload my availability for the scheduler
try await client.from("busy_blocks")
  .upsert(blocks).execute()
```

### Realtime — Broadcast, not Postgres Changes

Decision **D-16** (see [`../realtime-research.md`](../realtime-research.md)):
Supabase recommends Broadcast over `postgres_changes`, and for us the argument
is privacy and shape rather than scale.

Subscribe to the **private** channel `group:<group_id>` and listen for the event
`change`. Migration 0006 broadcasts from triggers on `proposals`, `votes`,
`proposal_slots`, `event_shares`, `group_memberships` and `groups`.

The payload is a hint, never the row:

```jsonc
{ "kind": "proposals" }   // or "events" | "groups"
```

Clients re-fetch that slice (`refreshProposals` / `refreshEvents` /
`refreshGroups`). Nothing sensitive crosses the socket, and the local copy can't
drift from the server's.

- The channel **must** be created with `private: true`, or the policy on
  `realtime.messages` isn't applied at all.
- Membership is the whole authorization rule: `is_group_member(topic_group_id(realtime.topic()), auth.uid())`.
- Push a refreshed JWT to the socket or the connection is dropped when the token
  expires. In Swift, pass an `accessToken` closure to `RealtimeClientOptions`.
- Broadcasts are best-effort by design: every trigger swallows its own errors, so
  a write never fails because Realtime is unhappy. Clients keep a polling
  fallback.

---

## Edge Function: `find-slots` (the scheduler)

`POST /functions/v1/find-slots` — Authorization: `Bearer <user JWT>`.

Finds the times a group is free that match a plain-language-derived constraint, and (by default) saves them as a proposal to vote on.

**A date the whole group can make always wins.** The scheduler scans the window in
time order and returns the earliest slots where *everyone* is free, however far
out they are. Only when the window contains no such date does it fall back to the
best turnout it found (at least `quorum` members), so the group gets an option
rather than nothing. `everyoneFree` in the response says which happened — show it,
because "4 of 6 can make it" is a different answer than "here's a date".

### Request body
```jsonc
{
  "groupId": "aaaaaaaa-…",
  "title": "Weekend hang",
  "maxResults": 10,
  "persist": true,               // false = preview without saving
  "constraints": {
    "windowStart": 1786838400000, // epoch ms, earliest a slot may start
    "windowEnd":   1787443200000, // epoch ms, how far ahead to look (the iOS
                                  // app defaults to 6 months; You → Date finder)
    "allowedWeekdays": [0, 6],     // 0=Sun … 6=Sat, evaluated in `timezone`
    "dayStartMinutes": 720,        // 12:00 (minutes from local midnight)
    "dayEndMinutes":   1020,       // 17:00
    "durationMinutes": 180,        // slot length
    "stepMinutes": 30,             // candidate granularity
    "timezone": "America/Los_Angeles",
    "quorum": 5                    // fallback floor only — min members free when
                                   // no all-free date exists; omit = a majority
  }
}
```

"A weekend afternoon" maps to `allowedWeekdays:[0,6]`, `dayStartMinutes:720`, `dayEndMinutes:1020`. The app builds this object from the user's natural-language choice.

### Response `200`
```jsonc
{
  "proposal": { "id": "…", "group_id": "…", "status": "open", … }, // omitted when persist:false
  "slots": [
    {
      "start": 1786986000000,
      "end":   1786996800000,
      "score": 6,
      "availableUserIds": ["…", "…"]   // aggregate only — never event detail
    }
  ],
  "everyoneFree": true,  // every slot works for the whole group
  "memberCount": 6,      // the denominator behind each score
  "quorum": 6            // availability floor the returned slots met
}
```
When `everyoneFree` is true the slots are the **earliest** dates that work for
everyone. Otherwise they're the fallback: ranked by `score` (members free) desc,
then earliest start.

### Errors
`400 invalid_json | missing_fields` · `401 unauthorized` · `403 forbidden` (not a group member) · `500 *_failed` (with `detail`).

### Swift models (suggested)
```swift
struct SlotConstraints: Codable {
  let windowStart, windowEnd: Int64
  let allowedWeekdays: [Int]
  let dayStartMinutes, dayEndMinutes, durationMinutes, stepMinutes: Int
  let timezone: String
  let quorum: Int?
}
struct ProposalSlot: Codable {
  let start, end: Int64
  let score: Int
  let availableUserIds: [String]
}
```
Implemented in `ios/Plannit/Services/SlotFinder.swift`.

---

## Friends

`friendships` holds one row per pair (`uq_friendship_pair` makes direction
irrelevant), and RLS shows a row only to the two people in it. Three functions
exist because RLS deliberately hides what the client would otherwise need:

| Function | Why it isn't a plain query |
|---|---|
| `my_friends()` | `friendships` has two FKs to `profiles`, so an embed is ambiguous |
| `my_friend_requests()` | a *pending* requester isn't a friend yet, so `profiles` RLS hides their name — you'd be judging a request from "Member" |
| `find_profile_by_email(p_email)` | you can't see a stranger's profile at all. Exact, case-insensitive match, returns `id` + `display_name` only, so the directory can't be enumerated |

Writes are plain table operations: insert a `pending` row to ask (RLS enforces
`requester_id = auth.uid()`), update it to `accepted` to agree, delete to
decline or unfriend.

### Beta: everyone is a friend

`app_config.auto_friend_everyone` is `true` while testing. A trigger on
`profiles` makes each new account accepted-friends with every existing one, and
0005 backfilled the accounts that already existed. To turn it off:

```sql
update public.app_config set value = 'false' where key = 'auto_friend_everyone';
```

Existing friendships survive; only new accounts stop being auto-added. The app
reads the flag and drops the "everyone is your friend" line when it's off.

## Push notifications
Register the device's APNs token into `device_tokens` after sign-in (RLS lets a
user write only their own). Sending is server-side only. Full details:
[`push-notifications.md`](push-notifications.md).

## Two-way calendar sync
The device ↔ backend reconciliation rules (identity mapping, import/export,
deltas, `busy_blocks` derivation, background refresh) are specified in
[`sync-contract.md`](sync-contract.md) — implement the client against that.

## What's stubbed / coming next
- **Additional push triggers** (event shared, friend request, proposal finalized) — webhook additions; only "date found" is wired today.
- **Non-user web participation link** (Phase 2, decision D-14) — not yet specified.
