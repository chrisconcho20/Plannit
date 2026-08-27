-- 0016_scale_indexes.sql — indexes for the queries that grow with users.
--
-- Purely additive: no policy, function or column changes, nothing to roll back
-- but the indexes themselves. The riskier half of the scaling work (the RLS
-- rewrite, and bounding `my_activity` in time) is written up in
-- docs/scaling.md rather than done here, because it changes behaviour and
-- wants a run of the test scripts behind it.
--
-- Every index below corresponds to a query the app runs on a timer, so they
-- earn their write cost.

-- The events load is now windowed by start_at across *all* events you can see,
-- not just ones you own (`idx_events_owner_start` only helps the latter).
-- Partial on the tombstone, because every read filters `deleted_at is null` and
-- deleted rows are dead weight in the index.
create index if not exists idx_events_start_live
  on public.events(start_at)
  where deleted_at is null;

-- Repeating events are kept regardless of their start date, so they're read on
-- every load however old they are. Tiny index, and it keeps that arm of the
-- `or` from degrading into a scan as history accumulates.
create index if not exists idx_events_recurring
  on public.events(start_at)
  where recurrence_rule is not null and deleted_at is null;

-- `my_activity()` asks "what am I going to?" via an EXISTS on event_rsvps keyed
-- by user. The primary key is (event_id, user_id), which can't answer that —
-- the leading column is the wrong one.
create index if not exists idx_rsvps_user
  on public.event_rsvps(user_id);

-- find-slots filters busy blocks by `user_id IN (...) AND end_at > windowStart`.
-- `idx_busy_user_start` covers the start side; this covers the other, which
-- matters as the horizon grew from 8 weeks to 6 months (D-19) and each user's
-- block count grew with it.
create index if not exists idx_busy_user_end
  on public.busy_blocks(user_id, end_at);

-- Shares are read per event through the PostgREST embed on every events load.
-- `uq_share_group` and `uq_share_user` are both partial (`where ... is not
-- null`), so neither can serve a plain lookup by event_id.
create index if not exists idx_share_event
  on public.event_shares(event_id);
