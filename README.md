# Plannit

A native iOS social calendar that syncs with your phone's calendar, lets you share the right events with the right people, and — the part no competitor has nailed — **automatically finds a date that works for everyone** from a plain-language constraint like "a weekend afternoon."

## The three pillars

1. **Two-way sync** — the device (Apple) calendar is a first-class citizen. Events flow both directions and reconcile whenever either side changes.
2. **Per-group visibility** — one personal calendar; reveal specific events to specific groups (share with Soccer, hide from Family). Enforced in the database, not on client trust.
3. **Automated group date-finding (the wedge)** — create a group, give a constraint ("weekend afternoon"), and Plannit proposes a slot when everyone is free.

## The strategic bet

The shared-calendar market is crowded and **Howbout owns it** (4.8★, 75k+ reviews, free). A shared calendar alone walks straight into that wall. **No one auto-solves natural constraints** — that gap is Plannit's wedge, and it shapes the architecture from day one even though it ships last.

## Recommended stack

| Layer | Choice |
|---|---|
| Client | Swift + SwiftUI (iOS 17+), EventKit, GRDB, Sign in with Apple, APNs |
| Backend | Supabase — Postgres + Auth + Realtime + Edge Functions + Row-Level Security |
| Scheduler | Sweep-line / interval-overlap in a TypeScript Edge Function |

## Repository layout

```
Plannit/
├─ docs/            # research, proposal, cost analysis, decisions, API contract
└─ supabase/        # the backend — schema, RLS, and the scheduler Edge Function
```

Frontend/iOS is being built on a separate track against the published
[API contract](docs/backend/api-contract.md).

## Documentation

- [`docs/market-research.md`](docs/market-research.md) — competitive landscape, what to borrow, what to avoid
- [`docs/technical-proposal.md`](docs/technical-proposal.md) — architecture, sync engine, data model, scheduler, phasing
- [`docs/cost-analysis.md`](docs/cost-analysis.md) — infra cost model, prototype & beta totals
- [`docs/decisions.md`](docs/decisions.md) — the decision log (D-01 … D-15), all Accepted
- [`docs/backend/api-contract.md`](docs/backend/api-contract.md) — **stable interface for the frontend track**
- [`docs/backend/sync-contract.md`](docs/backend/sync-contract.md) — two-way calendar sync rules for iOS
- [`docs/backend/push-notifications.md`](docs/backend/push-notifications.md) — APNs push
- [`supabase/README.md`](supabase/README.md) — backend setup, local dev, security model

## Status

Backend scaffolded (2026-08-13): full Postgres schema + RLS, the scheduler (the
wedge, validated), APNs push (validated), and the two-way sync contract for iOS.
Next: stand up a Supabase project and run the migrations. Frontend/iOS proceeds
in parallel against the API + sync contracts.
