-- 0029_quiet_plan_sweep.sql — find the overlap by sweeping, not by pairing.
--
-- 0027 searched for the best overlap by pairing every window start with every
-- window end and, for each pair, counting the windows that covered it: about
-- n³ comparisons in a group's open windows (scaling.md §12). Fine at a dozen
-- windows, unpleasant at a few hundred, and the number of windows is bounded
-- only by how diligently expired ones are deleted.
--
-- This replaces it with a sweep line, the same shape `find-slots` uses for the
-- date finder. Sort the boundaries once, walk them in order carrying a running
-- count of how many windows are open, and the moments worth considering are
-- exactly the starts: at each one, the overlap runs until the first end after
-- it, shared by however many windows are open at that instant.
--
-- Sorting is n log n and the walk is n, so the search is n log n. Only the
-- handful of best candidates are then checked against the participants' own
-- minimum lengths, which is the one part that still reads rows per candidate —
-- bounded to eight, so it stays a constant rather than a second n.
--
-- The result is the same overlap as before: most people first, then longest,
-- then earliest.

create or replace function private.match_quiet_plans(p_group uuid)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare
  v_best_start timestamptz;
  v_best_end   timestamptz;
  v_ids        uuid[];
  v_users      uuid[];
  v_changed    boolean;
  v_owner      uuid;
  v_title      text;
  v_event      uuid;
begin
  -- Anything whose window has passed is gone, not merely out of the running.
  delete from public.quiet_plans
   where group_id = p_group and status <> 'matched' and window_end <= now();

  with open_plans as (
    select id, user_id, window_start, window_end, min_minutes
      from public.quiet_plans
     where group_id = p_group and status = 'open' and window_end > now()
  ),
  -- One row per boundary: +1 where a window opens, -1 where it closes.
  boundaries as (
    select window_start as at, 1 as delta, false as is_end from open_plans
    union all
    select window_end,         -1,          true          from open_plans
  ),
  -- The sweep. Ends are applied before starts at the same instant, so a window
  -- that finishes exactly as another begins is not counted as an overlap.
  swept as (
    select at, is_end,
           sum(delta) over (order by at, is_end desc
                            rows between unbounded preceding and current row) as open_now,
           -- The first end at or after this boundary, carried backwards through
           -- the same ordering: where the overlap starting here must stop.
           min(case when is_end then at end) over (order by at desc, is_end asc
                                                   rows between unbounded preceding and current row) as next_end
      from boundaries
  ),
  -- A candidate overlap begins at a start boundary and runs to that next end.
  candidates as (
    select at as start_at, next_end as end_at, open_now as people
      from swept
     where not is_end and open_now >= 2 and next_end > at
  ),
  -- Only the strongest few are worth pricing against everyone's minimum length.
  ranked as (
    select * from candidates
     order by people desc, (end_at - start_at) desc, start_at asc
     limit 8
  )
  select r.start_at, r.end_at
    into v_best_start, v_best_end
    from ranked r
    cross join lateral (
      select count(*) as covering, coalesce(max(q.min_minutes), 0) as needs
        from open_plans q
       where q.window_start <= r.start_at and q.window_end >= r.end_at
    ) c
   -- The sweep's count and the covering set agree unless a window ends exactly
   -- where another starts; trusting the count alone would name an overlap
   -- nobody shares.
   where c.covering = r.people
     and extract(epoch from (r.end_at - r.start_at)) / 60 >= c.needs
   order by r.people desc, (r.end_at - r.start_at) desc, r.start_at asc
   limit 1;

  if v_best_start is null then
    return null;
  end if;

  select array_agg(id), array_agg(user_id)
    into v_ids, v_users
    from public.quiet_plans
   where group_id = p_group and status = 'open'
     and window_start <= v_best_start and window_end >= v_best_end;

  -- Everyone's own rule, applied until the set stops changing: dropping
  -- somebody can put another person below their own minimum.
  loop
    v_changed := false;
    declare
      v_keep_ids   uuid[] := '{}';
      v_keep_users uuid[] := '{}';
      v_rule       public.quiet_plan_rules;
      v_others     uuid[];
      i            int;
    begin
      for i in 1 .. coalesce(array_length(v_users, 1), 0) loop
        v_rule := private.quiet_plan_rule(v_users[i], p_group);
        v_others := array(select u from unnest(v_users) u where u <> v_users[i]);
        if array_length(v_users, 1) >= v_rule.min_people
           and (cardinality(v_rule.only_with) = 0
                or v_others <@ v_rule.only_with) then
          v_keep_ids := v_keep_ids || v_ids[i];
          v_keep_users := v_keep_users || v_users[i];
        else
          v_changed := true;
        end if;
      end loop;
      v_ids := v_keep_ids;
      v_users := v_keep_users;
    end;
    exit when not v_changed or coalesce(array_length(v_users, 1), 0) < 2;
  end loop;

  if coalesce(array_length(v_users, 1), 0) < 2 then
    return null;
  end if;

  -- Whoever asked first owns the plan, and their words name it.
  select user_id, coalesce(nullif(title, ''), 'Something together')
    into v_owner, v_title
    from public.quiet_plans
   where id = any(v_ids)
   order by created_at asc
   limit 1;

  insert into public.events (owner_id, title, start_at, end_at, timezone, source)
  values (v_owner, v_title, v_best_start, v_best_end, 'UTC', 'plannit')
  returning id into v_event;

  insert into public.event_shares (event_id, group_id) values (v_event, p_group);

  update public.quiet_plans
     set status = 'matched', matched_event_id = v_event
   where id = any(v_ids);

  perform private.notify_push(
    v_users,
    'A quiet plan came together',
    v_title || ' — ' || to_char(v_best_start at time zone 'UTC', 'Dy DD Mon HH24:MI'),
    jsonb_build_object('eventId', v_event, 'groupId', p_group),
    'quiet-' || v_event,
    'date_found');

  return v_event;
end;
$$;

-- The index the sweep reads: the boundaries for one group's open windows, in
-- order, without touching the table.
create index if not exists idx_quiet_plans_sweep
  on public.quiet_plans (group_id, status, window_start, window_end, min_minutes);
