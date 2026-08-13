# Plannit Backend (Supabase)

Postgres + Auth + Realtime + Edge Functions, with Row-Level Security enforcing
the per-group visibility pillar. See [`../docs/technical-proposal.md`](../docs/technical-proposal.md)
for the architecture and [`../docs/backend/api-contract.md`](../docs/backend/api-contract.md)
for the client-facing contract.

## Layout

```
supabase/
├─ config.toml                      # local dev + Apple auth config
├─ seed.sql                         # local demo data (3 users, 1 group, busy blocks)
├─ migrations/
│  ├─ 0001_init.sql                 # schema: profiles, groups, events, shares, busy_blocks, proposals…
│  ├─ 0002_rls.sql                  # SECURITY DEFINER auth helpers + RLS policies
│  └─ 0003_device_tokens.sql        # APNs device tokens (+ RLS)
└─ functions/
   ├─ _shared/
   │  ├─ scheduler.ts               # the wedge — pure, testable slot finder
   │  ├─ scheduler.test.ts          # Deno unit tests
   │  └─ apns.ts                    # token-based APNs signer + sender
   ├─ find-slots/
   │  └─ index.ts                   # scheduler Edge Function (+ best-effort "date found" push)
   └─ send-push/
      └─ index.ts                   # internal-only APNs sender
```

Push notifications: [`../docs/backend/push-notifications.md`](../docs/backend/push-notifications.md).
Two-way calendar sync contract: [`../docs/backend/sync-contract.md`](../docs/backend/sync-contract.md).

## Prerequisites

- [Supabase CLI](https://supabase.com/docs/guides/cli) and Docker Desktop
- [Deno](https://deno.land/) (for the Edge Function + tests)

## Run locally

```bash
supabase start                 # boots Postgres, Auth, Studio, etc.
supabase db reset              # applies migrations/ then seed.sql
supabase functions serve find-slots   # serves the scheduler function
```

Studio: http://localhost:54323 · API: http://localhost:54321

## Test the scheduler

```bash
deno test supabase/functions/_shared/
```

The algorithm is also validated to be correct independent of Deno (see the
commit that added it). Core invariants covered: weekend/afternoon constraint,
busy-overlap exclusion, and quorum enforcement.

## Security model (why RLS + SECURITY DEFINER)

Authorization helpers (`is_group_member`, `can_view_event`, …) are
`SECURITY DEFINER` so they can check membership **without** triggering RLS on
the same table — a policy on `group_memberships` that queried
`group_memberships` directly would recurse. This is the standard Supabase
pattern and is why those functions exist.

The `find-slots` function authenticates the caller under their own JWT (RLS
applies), then switches to the **service role** only to read every member's
`busy_blocks` and compute combined availability. The single value that leaves
the function is the aggregate `available_user_ids` — never anyone's event
details.

## Secrets (never committed)

Set via `supabase secrets set` or the dashboard:
`APPLE_CLIENT_ID`, `APPLE_SECRET` (Sign in with Apple), and the function runtime
provides `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.
