# Live updates — research & recommendation

_2026-08-14. Written to decide how Plannit's clients learn that something
changed: a vote landing, a plan being sent, an event shared. Today nothing is
live — everything appears on the next load, and `postgres_changes` is specced in
[`backend/api-contract.md`](backend/api-contract.md) but unused._

**Recommendation: Supabase Broadcast from Database, consumed through the
official `Realtime` SPM module.** Reasoning below; the local-first option is
covered seriously because it's where the industry has moved, and it's the better
answer if offline becomes a priority.

---

## 1. Supabase changed its own recommendation

The API contract was written against **Postgres Changes** (subscribe to a table,
filter by column). Supabase now documents that as the simpler option that
"does not scale as well", and recommends **Broadcast from Database** instead.

The mechanics of why matter more than the headline number:

- Postgres Changes processes changes **on a single thread to preserve order**,
  and re-checks **RLS once per subscriber per change**. One write to a table with
  100 listeners is 100 authorization checks — throughput scales with the number
  of subscribers, not the write rate. The documented cliff is ~3,000 concurrent
  subscribers on the same changes.
- Broadcast from Database is a trigger calling `realtime.broadcast_changes()`,
  which inserts into `realtime.messages`; Realtime tails that via a replication
  slot and fans out. Quoted as scaling to "tens of thousands of connected users".

**Plannit will never hit 3,000 subscribers on one table**, so scale is not the
argument. Two other properties are:

1. **We choose the topic.** Broadcast publishes to a topic we name — e.g.
   `group:<uuid>` — instead of a table. Our data is already group-scoped, so this
   maps exactly onto the product.
2. **We choose the payload.** Broadcast sends the columns we pick, not the whole
   row. Given per-group visibility is a product pillar, *not* shipping full rows
   over a socket is a meaningful privacy property. With Postgres Changes the
   protection is RLS re-evaluation per client; with Broadcast we simply never put
   the sensitive field on the wire.

### What it would take here

A migration (0006) adding, per table we care about, a trigger that broadcasts to
the right topic, plus one RLS policy on `realtime.messages`:

```sql
-- receive on a group topic if you're in that group
create policy "members read group topics"
on realtime.messages for select to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and public.is_group_member(
        (regexp_replace(realtime.topic(), '^group:', ''))::uuid, auth.uid())
);
```

`is_group_member` already exists from 0002, which is a good sign the topic shape
matches the domain. Tables worth broadcasting: `proposals`, `votes`,
`proposal_slots`, `event_shares`, `group_memberships`.

Gotchas the docs call out: the client must set `private: true` or policies aren't
enforced at all; policies are evaluated **at connection time** and cached per
connection; complex policies show up as connection latency.

## 2. The Swift client: don't hand-roll it

I assumed the choice was "hand-roll Phoenix channels on `URLSessionWebSocketTask`
or nothing", because our client is deliberately dependency-free. That was wrong
in a useful way: the official `supabase-swift` SDK ships **modular SPM products**,
so we can take **only `Realtime`** and leave our hand-rolled REST/auth layer
untouched. Requirements: iOS 16+ (we target 17), Xcode 16.4+ / Swift 6.1+.

Hand-rolling is genuinely possible — join, heartbeat, `postgres_changes` /
`broadcast` payloads, reconnect with backoff — but it means owning a protocol
client, including the part that bites everyone:

> A new JWT must be pushed onto the socket via an `access_token` message
> (`setAuth`) after every refresh, or **the client is disconnected when the JWT
> expires**.

We only just built token refresh (Keychain + refresh-before-expiry + 401 retry).
Wiring that into a hand-rolled socket is exactly the kind of subtle,
hard-to-test-without-two-live-sessions work that the maintained module already
does. This is the "strong reason" [`AGENTS.md`](../AGENTS.md) reserves for taking
a dependency.

## 3. iOS reality check: realtime is a foreground feature

Worth stating plainly, because it caps the value of any option:

- iOS **suspends the app shortly after it backgrounds**, and the socket dies with
  it. The correct pattern is connect on `scenePhase == .active`, tear down on
  background, and **always full-reconcile on foreground** — which we already do.
- **Silent pushes are "a gentle nudge, not a guarantee"** — the system decides
  whether to deliver them. They're not a substitute for a socket, and they need
  the paid Apple account anyway.

So live updates improve the case where two people have the app open at the same
time. For a planning app, that's real but narrower than it sounds: the more
common flow is Maya votes at lunch, you look after work. **The foreground
reconcile is what makes that correct, and it already exists.** Realtime is polish
on top of it, not a correctness fix.

## 4. The local-first option (where the industry actually went)

The 2026 trend isn't sockets, it's **sync engines**: a local SQLite the UI reads
synchronously, with a background engine reconciling to Postgres. That gives
realtime, offline, and optimistic writes as one property rather than three
features.

| Engine | Fit for us |
|---|---|
| **PowerSync** | Best fit. Full local SQLite, works offline and syncs on reconnect, **has a Swift SDK**, integrates with Supabase "non-invasively — no schema changes or write permissions required", hosted or self-hosted. |
| **ElectricSQL** | Postgres↔SQLite with "shapes"; 2026 production write-ups report rough edges around shape management and reconnection. |
| **Zero (Rocicorp)** | 1.0 as of June 2026, query-based sync, fastest perceived performance — but web-first; no Swift story. |

This is the strongest *architectural* answer, and it would supersede roadmap item
5.10 and **decision D-02 (GRDB for the offline cache)** — you wouldn't write a
cache, the engine is the cache. The cost is proportionate: a third-party service
in the data path (or infrastructure to self-host), a second definition of
what-syncs-to-whom in sync rules alongside our RLS, and writes moving from
PostgREST to a developer-defined upload endpoint — i.e. rebuilding the write path
we just finished.

For six-person groups pre-launch, that's a large bet to take now. It is the right
thing to revisit **when offline becomes a real requirement**, and adopting
Broadcast first doesn't block it.

## 5. What to do regardless of transport

These matter more than the socket, and are cheap:

- **Optimistic UI on writes.** Voting should move the card instantly and roll
  back on failure, rather than waiting for a round trip and a reload. Today every
  write is followed by a full `loadData()`.
- **Reconcile on foreground** — done.
- **Refresh while a screen is visible.** A 10s poll on an open plan detail is
  most of the perceived benefit of realtime for our shapes.

## 6. Recommendation

**Broadcast from Database + the official `Realtime` SPM module**, in this order:

1. Optimistic writes + visible-screen refresh (no new tech, immediate benefit).
2. Migration 0006: triggers + `realtime.messages` policy, topics `group:<uuid>`
   and `proposal:<uuid>`.
3. Take the `Realtime` SPM product; subscribe on `.active`, drop on background,
   push the fresh JWT on every token refresh, and keep the foreground reconcile
   as the safety net.
4. Revisit **PowerSync** if/when offline moves up the roadmap — at which point it
   likely replaces D-02 rather than joining it.

The API contract's "subscribe to `postgres_changes`" line should be updated when
step 2 lands.

---

### Sources

- [Subscribing to Database Changes](https://supabase.com/docs/guides/realtime/subscribing-to-database-changes) · [Postgres Changes](https://supabase.com/docs/guides/realtime/postgres-changes) · [Broadcast](https://supabase.com/docs/guides/realtime/broadcast)
- [Realtime: Broadcast from Database](https://supabase.com/blog/realtime-broadcast-from-database) · [Realtime Authorization](https://supabase.com/docs/guides/realtime/authorization) · [Benchmarks](https://supabase.com/docs/guides/realtime/benchmarks)
- [supabase-swift](https://github.com/supabase/supabase-swift) · [Swift API reference](https://supabase.com/docs/reference/swift/introduction) · [Realtime token refresh discussion](https://github.com/orgs/supabase/discussions/37002)
- [PowerSync + Supabase](https://docs.powersync.com/integrations/supabase/guide) · [powersync-swift](https://github.com/powersync-ja/powersync-swift) · [Bringing offline-first to Supabase](https://powersync.com/blog/bringing-offline-first-to-supabase)
- [Zero 1.0 (InfoQ)](https://www.infoq.com/news/2026/06/zero-version-1/) · [ElectricSQL vs PowerSync vs Zero (2026)](https://trybuildpilot.com/648-electric-sql-vs-powersync-vs-zero-2026) · [The Architecture of Local-First Web Development](https://www.smashingmagazine.com/2026/05/architecture-local-first-web-development/)
- [Silent push notifications: opportunities, not guarantees](https://mohsinkhan845.medium.com/silent-push-notifications-in-ios-opportunities-not-guarantees-2f18f645b5d5) · [Apple Forums: WebSocket in background](https://developer.apple.com/forums/thread/716118)
