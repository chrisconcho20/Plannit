# Will this hold up? — Supabase at 100, 1,000 and 10,000 users

_2026-08-27. A read of the actual queries this app runs, not a general Supabase
guide. Numbers are per-user estimates from the schema and the code; treat them
as orders of magnitude, not forecasts._

**The short version.** Storage is a non-issue. The three things that bite are
**egress**, **write churn on `busy_blocks`**, and **per-row RLS function calls**
on the events query. Two of those are already fixed; the third is the one real
piece of work left before a launch that matters.

---

## What one user costs

| | Per user | 1,000 users | 10,000 users |
|---|---|---|---|
| `busy_blocks` rows (6-month horizon, ~4 merged blocks/day) | ~800 | 800k | 8M |
| `busy_blocks` on disk (heap + index) | ~160 KB | ~160 MB | ~1.6 GB |
| `events` rows | 50–500 | up to 500k | up to 5M |
| Realtime connections | 1 socket, N channels | 1,000 concurrent | 10,000 concurrent |

Against the [current plans](https://uibakery.io/blog/supabase-pricing): Free is
500 MB database / 5 GB egress / 200 concurrent realtime; Pro is $25/mo for 8 GB
/ 250 GB egress / 500 concurrent realtime, then usage-based.

So **disk is comfortable well past 10,000 users on Pro.** The limits you hit
first are concurrent realtime connections (500 on Pro, an add-on beyond) and
egress — which is a function of how chatty the client is, not how many rows
exist.

---

## The findings

### 1. The events query had no bound 🔴 — **fixed**

`fetchEvents` selected every event you could see, ever, with two embeds, and ran
on every load, every realtime hint, and a 20-second poll. A user with 500
visible events is roughly a quarter-megabyte per refresh; at a 20s poll that's
on the order of **1 GB per active user per day**, which eats the free tier's
5 GB with five users and is a real line item on Pro.

Now windowed to −3/+13 months, which is what the UI can display. Repeating
events are exempt from the window: one row from two years ago can still be every
Tuesday this month, and filtering it out would empty the calendar of exactly the
events people rely on most.

### 2. Polling ran at full speed alongside Realtime 🟠 — **fixed**

Polling was the update mechanism before Broadcast (D-16) and is now the backstop
for a socket that never connected. Both running flat out means every user costs
a request every 20 seconds all day, changed or not. It now drops to a 120-second
heartbeat whenever the socket is up.

At 1,000 daily users that's the difference between ~50 requests/second of pure
polling and ~8.

### 3. `events_select` calls a function per row 🔴 — **not fixed, the real work**

```sql
create policy events_select on public.events for select to authenticated
  using ( owner_id = auth.uid() or public.can_view_event(id, auth.uid()) );
```

`can_view_event` is `SECURITY DEFINER` and does two `EXISTS` subqueries, one of
which calls `is_group_member` per share. Postgres evaluates that **once per
candidate row**. At six events nobody notices; at 500 it's 500 function calls
each doing several index lookups, on every load, for every user.

The fix is the one Supabase documents for exactly this shape — and it's two
changes, not one:

- **Wrap `auth.uid()` as `(select auth.uid())`** so the planner hoists it into an
  InitPlan instead of re-evaluating per row.
- **Replace the function call with an inline `EXISTS`** over `event_shares` and
  `group_memberships`, so the planner can turn it into a hash join instead of a
  per-row call it can't see inside.

I've deliberately not done this yet. It's a rewrite of the policy that decides
who can read events, I can't test it against your database from here, and a
mistake is a data leak rather than a slow query. It wants one session with
[`tests/09-sharing.md`](tests/09-sharing.md) run immediately afterwards, ideally
with a second account. Same pattern applies to `memberships_select` and
`rsvps_select`.

### 4. `busy_blocks` churn 🟠 — mitigated, watch it

Every availability sync replaces the user's entire future window: ~800 deletes
and ~800 inserts for a change of one event. That's dead tuples for autovacuum to
clear, and it's the single largest source of write traffic in the app.

Already mitigated: uploads are skipped entirely when a SHA-256 of the blocks
matches the last one (D-19), so an idle app writes nothing, and the empty-set
guard stops a broken read from rewriting everything to nothing.

The next step, when it's needed rather than now: **diff the upload** — send only
the blocks that changed rather than the window. It needs a read-before-write or
a server-side merge, so it's real work for a problem you don't have yet. The
threshold to watch is `n_dead_tup` on `busy_blocks` and how often autovacuum
runs:

```sql
select relname, n_live_tup, n_dead_tup, last_autovacuum
  from pg_stat_user_tables where relname = 'busy_blocks';
```

### 5. `my_activity()` scans all of history 🟡 — proposed

Five branches, `UNION ALL`, `order by happened_at desc limit 50`. The limit is
applied *after* the union, so every branch produces all its rows on every call —
and the feed refreshes on a timer. Today that's a handful of rows; in a year of
use, the `invited` branch alone walks every share ever made to any of your
groups.

One-line fix per branch: `and <timestamp> > now() - interval '90 days'`. Nobody
scrolls a 50-row feed back further than that, and the limit already truncates it.
Bundled with the RLS work since it's the same file and the same test pass.

### 6. Indexes for the queries that run on a timer 🟡 — **fixed (0016)**

Four of the five were genuinely missing, and one is subtle: both existing indexes
on `event_shares` are *partial* (`where group_id is not null`, `where
shared_user_id is not null`), so neither could serve the plain `event_id` lookup
that the PostgREST embed does on every events load.

### 7. Realtime is the first hard ceiling 🟡 — plan for it

One socket per running app, so concurrent connections ≈ **concurrently active
users**: 200 on Free, 500 on Pro, an add-on above that. Messages are cheap by
comparison — a change broadcasts once per group topic, so 1,000 users at 5
changes a day in 6-person groups is well inside the included 5M/month.

Nothing to do now beyond knowing the number, and that the app already degrades
correctly: if the socket can't connect, polling takes over (see 2) and the app is
merely slower.

### 8. Push triggers use `pg_net` 🟡 — before push goes live

`0004` fires an HTTP call from a trigger per row change. Two things to do before
enabling it at any volume: the responses accumulate in `net._http_response` and
need periodic cleanup, and a trigger that does network I/O ties throughput to how
fast APNs answers. It's idle today (no APNs key), so it's a pre-launch checklist
item, not a live problem.

### 9. Cheap global backstop 🟢 — one setting

Set PostgREST's **`db-max-rows`** (Settings → API) to something like 1,000. It
caps any query — including one a future bug forgets to bound — from returning the
whole table. Costs nothing, prevents the category.

---

## Order of work

1. **Now, free:** set `db-max-rows`. Apply `0016`.
2. **Before real users:** the RLS rewrite (3) plus the activity time bound (5),
   with `09-sharing.md` and `13-live-updates.md` run afterwards.
3. **Before push:** `pg_net` cleanup job (8).
4. **When the numbers say so:** diff-based availability upload (4), and the
   realtime connection add-on (7).

## What to watch once people are on it

```sql
-- the queries actually costing you (needs pg_stat_statements)
select calls, round(mean_exec_time::numeric, 2) as avg_ms, query
  from pg_stat_statements order by total_exec_time desc limit 10;

-- table sizes and dead tuples
select relname, n_live_tup, n_dead_tup,
       pg_size_pretty(pg_total_relation_size(relid)) as size
  from pg_stat_user_tables order by pg_total_relation_size(relid) desc limit 10;
```

Supabase's dashboard covers egress and realtime concurrency directly. The number
worth a weekly glance is **egress per active user** — it's the one that grows
with a code change rather than with signups, and it's how a chatty refresh loop
turns into a bill.
