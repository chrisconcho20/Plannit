# Decision Log

_Last updated 2026-08-13._

Status key: **Accepted** = decided · **Proposed** = recommended default, awaiting confirmation.

**All decisions below were confirmed by the founder on 2026-08-13** — the full ledger is now Accepted. Any can still be revisited as build realities emerge.

## Settled direction

| # | Decision | Choice | Status |
|---|---|---|---|
| Strategy | What are we building? | The **auto date-finder is the wedge** — not another shared calendar. Architecture supports it from Phase 1 even though it ships in Phase 3. | **Accepted** |
| Stack | Client | Swift + SwiftUI (iOS 17+), EventKit, GRDB, Sign in with Apple, APNs | **Accepted** |
| Cost | Prototype budget | **$0/mo** — Supabase Free + simulator/own-device runs | **Accepted** |
| Cost | Beta (<20 users) budget | Start **Supabase Free + $99/yr Apple** (~$99 first year); flip to Supabase Pro ($25/mo) when backups/reliability are needed | **Accepted** |

## Decision ledger (D-01 … D-15)

Each has a recommendation marked ★. All are now **Accepted** as of 2026-08-13.

### Foundation

| ID | Decision | Options | Recommendation ★ | Status |
|---|---|---|---|---|
| D-01 | Backend approach | Supabase / Firebase / Custom Node·Go | **Supabase** (Postgres + RLS fits per-group visibility; predictable cost; open-source escape hatch) | **Accepted** |
| D-02 | Local persistence | GRDB / Core Data / SwiftData | **GRDB** (battle-tested SQLite) | Accepted |
| D-03 | Auth methods | Apple first / Apple+email / Apple+phone | **Apple first**, add email later | Accepted |
| D-04 | Cross-platform timing | iOS-first / iOS+Android now | **iOS-first**, keep backend platform-agnostic | Accepted |

### Sync & privacy

| ID | Decision | Options | Recommendation ★ | Status |
|---|---|---|---|---|
| D-05 | Calendar permission scope | Write-only default / Full access upfront | **Write-only default**, full access only for availability | Accepted |
| D-06 | Where app events live | Dedicated Plannit calendar / User's existing calendars | **Dedicated Plannit calendar** | Accepted |
| D-07 | Sync conflict strategy | Last-write-wins / Per-field merge / CRDT | **Last-write-wins (v1)** | Accepted |
| D-08 | Availability privacy model | On-device busy blocks / Server-side from shared events | **On-device busy blocks** (opaque, no titles leave phone) | Accepted |
| D-09 | Group event visibility default | Private by default / Open feed | **Private by default** (opt-in to share) | Accepted |

### The scheduler

| ID | Decision | Options | Recommendation ★ | Status |
|---|---|---|---|---|
| D-10 | Where the scheduler runs | Server Edge Function / On-device | **Server Edge Function** (single source of truth) | Accepted |
| D-11 | Constraint richness for v1 | Basic (day+time+duration+quorum) / Advanced | **Basic set** for v1 | Accepted |
| D-12 | Outcome of a proposal | Propose then vote / Auto-lock best | **Propose then vote** (social) | Accepted |

### Realtime & product

| ID | Decision | Options | Recommendation ★ | Status |
|---|---|---|---|---|
| D-13 | Realtime transport | Realtime + APNs / APNs only / Polling | **Realtime + APNs** | Accepted |
| D-14 | Non-user participation | Web link in Phase 2 / App-only | **Web link in Phase 2** (beats Howbout's invite wall) | Accepted |
| D-15 | First TestFlight scope | Through the scheduler / Phases 1–2 only | **Through the scheduler** (ship the wedge) | Accepted |

### Amendments

| ID | Decision | Options | Choice ★ | Status |
|---|---|---|---|---|
| D-16 | Realtime *mechanism* (refines D-13) | `postgres_changes` / **Broadcast from Database** / local-first sync engine | **Broadcast from Database**, consumed via the official `Realtime` SPM module | Accepted 2026-08-14 |

**D-16 in full.** D-13 chose "Realtime + APNs" as the transport but not the
mechanism, and the API contract assumed `postgres_changes`. Supabase now
documents that as the option that "does not scale as well" and recommends
Broadcast from Database. For Plannit the deciding factor isn't scale — six-person
groups will never approach the ~3,000-subscriber cliff — it's **shape**:
broadcast picks the topic (`group:<uuid>`, which `is_group_member` from 0002
already authorises) and the payload, so a sensitive column never goes on the wire
at all, rather than relying on per-client RLS re-evaluation to filter it. Taking
only the `Realtime` SPM product is the first dependency in the iOS app, accepted
because owning a Phoenix protocol client means owning the JWT-refresh-on-socket
behaviour that silently disconnects clients when missed. Research and sources:
[`realtime-research.md`](realtime-research.md).

**The alternative we did not take, and when to reopen it.** A local-first sync
engine — realistically **PowerSync** (full local SQLite, Swift SDK, non-invasive
Supabase integration) — would deliver realtime, offline and optimistic writes as
one architectural property instead of three features. It was rejected *for now*
as disproportionate: a service in the data path, sync rules restating what RLS
already says, and moving writes off PostgREST to an upload endpoint. It would
also **supersede D-02 (GRDB for the offline cache)** rather than sit alongside it.

Reopen D-16 if any of these show up:

- **Offline becomes a real requirement** (roadmap 5.10) — building a GRDB cache
  by hand is most of the work PowerSync already does, and doing both is waste.
- **Broadcast triggers become a maintenance drag** — if every new table needs a
  bespoke trigger + policy and they drift from RLS, the duplication argument that
  counts against PowerSync starts counting against us instead.
- **Write latency or conflict handling gets fiddly** — if we find ourselves
  hand-rolling a mutation queue with retries and rollback, that's the sync
  engine's job, done better.
- **Another platform appears** (Android, web link per D-14) — PowerSync's
  multi-platform SDKs would then amortise, where our Swift-only work doesn't.

Migrating later is not free but is bounded: the schema and RLS stay, and the
broadcast triggers are dropped rather than rewritten.

## Open questions (product / go-to-market)

- **Who are the first ~20 beta users?** A named friend group de-risks cold-start and gives real calendars to sync.
- **Target date for a working TestFlight?** Sets how aggressively Phase 2/3 scope is cut.
- **Budget for paid infra / Apple Developer account?** $99/yr Apple is required; Supabase free tier covers a beta.
- **How important is Android at launch?** Network effects reward it; iOS-first is faster. Backend stays platform-agnostic regardless.
- **Long-term monetization?** Free vs freemium (e.g. advanced scheduling as premium) affects what's flagged from the start.

## Next steps

1. ~~Confirm the recommended decisions above.~~ **Done 2026-08-13 — full ledger Accepted.**
2. Scaffold the repo — Xcode SwiftUI project, Supabase schema with RLS policies, sync-engine skeleton.
3. Prove the wedge early — a small on-device sweep-line prototype that finds a slot from fake busy-blocks.
