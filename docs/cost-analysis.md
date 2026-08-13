# Cost Analysis

_Compiled 2026-08-13. Pricing bands are estimates — verify against live pricing before committing._

## Headline

At beta scale, **every backend option is effectively free-to-$25/mo**, so the decision is driven by _fit_ and _predictability_, not the monthly bill. The bigger cost is engineering time, not hosting.

## Fixed costs (independent of backend)

| Item | Cost | Notes |
|---|---|---|
| Apple Developer Program | **$99/yr (~$8/mo)** | Required to distribute via TestFlight / App Store. |
| APNs push notifications | **Free** | Apple charges nothing for push. |
| Sentry (crash reporting) | **$0** | Free tier covers a beta. |

## What drives Plannit's backend cost

Plannit is **relational and modest-volume**, not read-explosive: auth MAU, small event rows, realtime connections (~concurrent users), occasional function invocations (sync + scheduler), small egress. This profile favors Postgres platforms and punishes Firebase's per-read model.

## Staged cost model (rough monthly, backend only)

| Stage | Supabase | Firebase | Neon + assembled stack | Convex |
|---|---:|---:|---:|---:|
| **Beta** (≤500 users) | $0–25 | $0–5 | $0 | $0–25 |
| **Growth** (~10k MAU) | $25–75 | $25–100 | $50–120 | $25–50 |
| **Scale** (~100k MAU) | ~$150–400 | ~$300–800+ | ~$200–500 | ~$100–300 |

Firebase's range is wide because it has **no hard spending cap** — one unbounded query can turn a $12 bill into thousands.

## Option notes for our workload

- **Supabase ($25/mo Pro) — recommended.** Postgres + RLS is the exact primitive for per-group visibility (architectural win, not just cost). Predictable flat pricing. Bundles auth + realtime + functions + storage. Open-source → self-host escape hatch at scale.
- **Firebase.** Best-in-class mobile offline sync/push, but NoSQL fits our relational model poorly, cost is unpredictable, and Supabase runs ~40–60% cheaper at scale. Avoid.
- **Neon + assembled stack.** Cheapest DB (scale-to-zero, ~$0.35/GB) but only the database — you bolt on auth, realtime, storage, functions. Assembled bill often exceeds Supabase plus costs engineering time. Revisit only if the DB becomes the bottleneck.
- **Convex.** Great realtime DX and predictable pricing, but a reactive document store — loses the RLS→per-group-visibility fit and Postgres portability.

## Concrete totals for our near-term stages

### Prototype (building + testing yourself, no outside users)

| Item | Cost |
|---|---|
| Supabase (Free tier) | $0 |
| Apple Developer Program | $0 (simulator + own device run free) |
| Everything else | $0 |
| **Prototype total** | **$0/mo** |

_If you want to test real push notifications during prototyping, pull the $99/yr Apple Developer Program forward._

### Beta (fewer than 20 users)

Distributing via TestFlight makes the Apple Developer Program mandatory — the one unavoidable cost. 20 users fits inside Supabase's free tier many times over, so the real choice is Free vs Pro.

| Item | Minimum | Recommended |
|---|---|---|
| Apple Developer Program | $99/yr (~$8.25/mo) | $99/yr (~$8.25/mo) |
| Supabase | $0 (Free tier) | $25/mo (Pro) |
| APNs / Sentry / storage | $0 | $0 |
| **Monthly** | **~$8.25/mo** | **~$33.25/mo** |
| **First-year total** | **~$99** | **~$399** |

- **Free tier works** if testers open the app at least every few days (the 7-day pause only triggers after a full week of zero activity). Risk: no automatic backups, cold-start pause if the group goes quiet.
- **Pro ($25) buys reliability:** no pausing, daily backups, higher limits.

## Bottom line

- **Prototype: $0.**
- **Beta <20 users: ~$99 for the year** on Supabase Free (accept pause/backup risk), or **~$399/yr (~$33/mo)** on Supabase Pro for reliability.
- Recommendation: prototype free; at beta pay the **$99 Apple fee (required) and start on Supabase Free**, flipping to Pro the moment you want backups or hit a pause — keeping first-beta cost near **~$99 total**.

## Sources

- Supabase pricing 2026 (UI Bakery) — https://uibakery.io/blog/supabase-pricing
- Supabase true cost (MetaCTO) — https://www.metacto.com/blogs/the-true-cost-of-supabase-a-comprehensive-guide-to-pricing-integration-and-maintenance
- Firebase pricing traps 2026 (Sashido) — https://www.sashido.io/en/blog/firebase-guide-and-pricing-traps-2026
- Firestore pricing (ToolRadar) — https://toolradar.com/tools/firebase-firestore/pricing
- Convex vs Supabase vs Firebase (BuildPilot) — https://trybuildpilot.com/414-supabase-vs-convex-vs-firebase-for-startups-2026
- Neon vs Supabase 2026 (DesignRevision) — https://designrevision.com/blog/supabase-vs-neon
- Neon pricing breakdown (Vela) — https://vela.run/articles/neon-serverless-postgres-pricing-2026/
