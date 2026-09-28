-- 0028_expire_quiet_plans.sql — a window that has passed stops existing.
--
-- 0027 marked a passed window 'expired' and only did so when that group was
-- next matched, so a quiet plan could sit in the table for weeks after it could
-- possibly matter, and the person who posted it would still see it listed.
--
-- A quiet plan is a statement about a time. Once that time is behind us the
-- statement is spent, and keeping it is keeping a record of when somebody was
-- free for no reason anyone benefits from. So it is deleted, not archived.
--
-- Matched plans are the exception: they point at the event they produced, which
-- is a real thing on real calendars, and the row is what explains where that
-- event came from.

-- ---------------------------------------------------------------------------
-- The purge
-- ---------------------------------------------------------------------------
create or replace function private.purge_expired_quiet_plans()
returns integer language plpgsql volatile security definer set search_path = public as $$
declare
  v_deleted integer;
begin
  delete from public.quiet_plans
   where status <> 'matched'
     and window_end <= now();
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function private.purge_expired_quiet_plans() from public, anon, authenticated;

-- The matcher no longer marks anything expired; it deletes, at the one moment
-- it is already holding the group's rows. Everything else is unchanged from
-- 0027.
create or replace function private.match_quiet_plans(p_group uuid)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare
  v_best_start timestamptz;
  v_best_end   timestamptz;
  v_best_count int := 0;
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
    select * from public.quiet_plans
     where group_id = p_group and status = 'open' and window_end > now()
  )
  select b.start_at, b.end_at, b.people
    into v_best_start, v_best_end, v_best_count
    from (
      select s.window_start as start_at,
             e.window_end   as end_at,
             count(*)       as people
        from (select distinct window_start from open_plans) s
        cross join (select distinct window_end from open_plans) e
        join open_plans q
          on q.window_start <= s.window_start and q.window_end >= e.window_end
       where e.window_end > s.window_start
       group by s.window_start, e.window_end
      -- Long enough for the most demanding person in *this* overlap. Someone
      -- else's hour-long minimum elsewhere in the group is not their problem.
      having count(*) >= 2
         and extract(epoch from (e.window_end - s.window_start)) / 60 >= max(q.min_minutes)
    ) b
   order by b.people desc, (b.end_at - b.start_at) desc, b.start_at asc
   limit 1;

  if v_best_count < 2 then
    return null;
  end if;

  select array_agg(id), array_agg(user_id)
    into v_ids, v_users
    from public.quiet_plans
   where group_id = p_group and status = 'open'
     and window_start <= v_best_start and window_end >= v_best_end;

  -- Everyone's own rule, applied until the set stops changing.
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

-- ---------------------------------------------------------------------------
-- Running it when nobody is looking
-- ---------------------------------------------------------------------------
-- The matcher only reaches a group when somebody posts to it. A group that
-- goes quiet for a month would keep its stale windows until then, so an hourly
-- job sweeps every group.
--
-- Guarded, because pg_cron is an extension a project may not have enabled and
-- a migration that fails there fails everything after it. Without it the
-- deletes still happen whenever a group is matched — later than they should,
-- never later than the next post.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;

    -- Replace rather than duplicate when this migration is applied twice.
    if exists (select 1 from cron.job where jobname = 'purge-expired-quiet-plans') then
      perform cron.unschedule('purge-expired-quiet-plans');
    end if;

    perform cron.schedule(
      'purge-expired-quiet-plans',
      '17 * * * *',
      'select private.purge_expired_quiet_plans();');
  else
    raise notice 'pg_cron not available: expired quiet plans are removed when a group is next matched.';
  end if;
end;
$$;
