# Decision Log

_Last updated 2026-08-13._

Status key: **Accepted** = decided · **Proposed** = recommended default, awaiting confirmation.

## Settled direction

| # | Decision | Choice | Status |
|---|---|---|---|
| Strategy | What are we building? | The **auto date-finder is the wedge** — not another shared calendar. Architecture supports it from Phase 1 even though it ships in Phase 3. | **Accepted** |
| Stack | Client | Swift + SwiftUI (iOS 17+), EventKit, GRDB, Sign in with Apple, APNs | **Accepted** |
| Cost | Prototype budget | **$0/mo** — Supabase Free + simulator/own-device runs | **Accepted** |
| Cost | Beta (<20 users) budget | Start **Supabase Free + $99/yr Apple** (~$99 first year); flip to Supabase Pro ($25/mo) when backups/reliability are needed | **Accepted** |

## Decision ledger (D-01 … D-15)

Each has a recommendation marked ★. Statuses reflect the discussion to date; ★ items not yet explicitly confirmed are **Proposed**.

### Foundation

| ID | Decision | Options | Recommendation ★ | Status |
|---|---|---|---|---|
| D-01 | Backend approach | Supabase / Firebase / Custom Node·Go | **Supabase** (Postgres + RLS fits per-group visibility; predictable cost; open-source escape hatch) | **Accepted** |
| D-02 | Local persistence | GRDB / Core Data / SwiftData | **GRDB** (battle-tested SQLite) | Proposed |
| D-03 | Auth methods | Apple first / Apple+email / Apple+phone | **Apple first**, add email later | Proposed |
| D-04 | Cross-platform timing | iOS-first / iOS+Android now | **iOS-first**, keep backend platform-agnostic | Proposed |

### Sync & privacy

| ID | Decision | Options | Recommendation ★ | Status |
|---|---|---|---|---|
| D-05 | Calendar permission scope | Write-only default / Full access upfront | **Write-only default**, full access only for availability | Proposed |
| D-06 | Where app events live | Dedicated Plannit calendar / User's existing calendars | **Dedicated Plannit calendar** | Proposed |
| D-07 | Sync conflict strategy | Last-write-wins / Per-field merge / CRDT | **Last-write-wins (v1)** | Proposed |
| D-08 | Availability privacy model | On-device busy blocks / Server-side from shared events | **On-device busy blocks** (opaque, no titles leave phone) | Proposed |
| D-09 | Group event visibility default | Private by default / Open feed | **Private by default** (opt-in to share) | Proposed |

### The scheduler

| ID | Decision | Options | Recommendation ★ | Status |
|---|---|---|---|---|
| D-10 | Where the scheduler runs | Server Edge Function / On-device | **Server Edge Function** (single source of truth) | Proposed |
| D-11 | Constraint richness for v1 | Basic (day+time+duration+quorum) / Advanced | **Basic set** for v1 | Proposed |
| D-12 | Outcome of a proposal | Propose then vote / Auto-lock best | **Propose then vote** (social) | Proposed |

### Realtime & product

| ID | Decision | Options | Recommendation ★ | Status |
|---|---|---|---|---|
| D-13 | Realtime transport | Realtime + APNs / APNs only / Polling | **Realtime + APNs** | Proposed |
| D-14 | Non-user participation | Web link in Phase 2 / App-only | **Web link in Phase 2** (beats Howbout's invite wall) | Proposed |
| D-15 | First TestFlight scope | Through the scheduler / Phases 1–2 only | **Through the scheduler** (ship the wedge) | Proposed |

## Open questions (product / go-to-market)

- **Who are the first ~20 beta users?** A named friend group de-risks cold-start and gives real calendars to sync.
- **Target date for a working TestFlight?** Sets how aggressively Phase 2/3 scope is cut.
- **Budget for paid infra / Apple Developer account?** $99/yr Apple is required; Supabase free tier covers a beta.
- **How important is Android at launch?** Network effects reward it; iOS-first is faster. Backend stays platform-agnostic regardless.
- **Long-term monetization?** Free vs freemium (e.g. advanced scheduling as premium) affects what's flagged from the start.

## Next steps

1. Confirm the **Proposed** decisions above (or override any).
2. Scaffold the repo — Xcode SwiftUI project, Supabase schema with RLS policies, sync-engine skeleton.
3. Prove the wedge early — a small on-device sweep-line prototype that finds a slot from fake busy-blocks.
