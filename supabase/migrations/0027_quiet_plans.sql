-- 0027_quiet_plans.sql — a plan nobody is told about until enough people want it.
--
-- A quiet plan is a private window: "I'm free Saturday 12–6 if anyone fancies
-- something." It notifies nobody and is visible to nobody. The server
-- intersects the open windows in a group, and when an overlap satisfies every
-- participant's own criteria, the overlap becomes an ordinary event shared with
-- the group — from there it behaves like any other invitation, and people say
-- going or not going.
--
-- The privacy rule is the point, so it is enforced in three places rather than
-- one: RLS lets you read only your own rows, the matcher runs SECURITY DEFINER
-- so no client ever sees another person's window, and a matched plan reveals a
-- time rather than a calendar. Nobody learns that you were free on a Saturday
-- unless a plan actually happens.
--
-- Whose rules decide: your own. Your criteria say when *you* may be pulled into
-- a match — a minimum turnout, and optionally the only people you want matched
-- with. Someone else's looser settings can never lower your bar.

-- ---------------------------------------------------------------------------
-- The windows
-- ---------------------------------------------------------------------------
create type quiet_plan_status as enum ('open', 'matched', 'cancelled', 'expired');

create table public.quiet_plans (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  group_id     uuid not null references public.groups(id)   on delete cascade,
  -- What they'd like to do, if they said. Revealed only when a plan is made.
  title        text,
  window_start timestamptz not null,
  window_end   timestamptz not null,
  -- An overlap shorter than this isn't a plan, it's a coincidence.
  min_minutes  int not null default 60,
  status       quiet_plan_status not null default 'open',
  matched_event_id uuid references public.events(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint quiet_plan_window_valid check (window_end > window_start),
  constraint quiet_plan_min_minutes_sane check (min_minutes between 15 and 1440)
);

create index idx_quiet_plans_matching
  on public.quiet_plans (group_id, status, window_start, window_end);
create index idx_quiet_plans_user on public.quiet_plans (user_id, status);

create trigger trg_quiet_plans_updated before update on public.quiet_plans
  for each row execute function public.set_updated_at();

alter table public.quiet_plans enable row level security;

-- Your own rows and nobody else's. The matcher is SECURITY DEFINER precisely so
-- that this policy can stay this strict.
create policy quiet_plans_select on public.quiet_plans for select to authenticated
  using ( user_id = (select auth.uid()) );

-- Post one only for yourself, only to a group you are in.
create policy quiet_plans_insert on public.quiet_plans for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and group_id in (select private.my_group_ids())
  );

-- Cancelling is the only edit a client makes; everything else is the matcher's.
create policy quiet_plans_update on public.quiet_plans for update to authenticated
  using ( user_id = (select auth.uid()) )
  with check ( user_id = (select auth.uid()) );

create policy quiet_plans_delete on public.quiet_plans for delete to authenticated
  using ( user_id = (select auth.uid()) );

grant select, insert, update, delete on public.quiet_plans to authenticated;

-- ---------------------------------------------------------------------------
-- Each person's criteria
-- ---------------------------------------------------------------------------
-- A row per person, and optionally a row per group that overrides it. These
-- live on the server rather than the phone because the matcher enforces them,
-- and a rule the server can't read is a rule that doesn't hold.
create table public.quiet_plan_rules (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  -- The all-zeroes uuid is "every group": a null here would defeat the primary
  -- key, since Postgres treats nulls as distinct.
  group_id   uuid not null default '00000000-0000-0000-0000-000000000000',
  -- Including you. Two is a plan; the default asks for one more than that.
  min_people int not null default 3,
  -- Match me only with these people. Empty means anyone in the group.
  only_with  uuid[] not null default '{}',
  updated_at timestamptz not null default now(),
  primary key (user_id, group_id),
  constraint quiet_plan_min_people_sane check (min_people between 2 and 50)
);

create trigger trg_quiet_plan_rules_updated before update on public.quiet_plan_rules
  for each row execute function public.set_updated_at();

alter table public.quiet_plan_rules enable row level security;

create policy quiet_plan_rules_all on public.quiet_plan_rules for all to authenticated
  using ( user_id = (select auth.uid()) )
  with check ( user_id = (select auth.uid()) );

grant select, insert, update, delete on public.quiet_plan_rules to authenticated;

-- The rule that applies to one person in one group: the group's override if
-- they set one, else their default, else the built-in.
create or replace function private.quiet_plan_rule(p_user uuid, p_group uuid)
returns public.quiet_plan_rules language sql stable security definer
set search_path = public as $$
  select coalesce(
    (select r from public.quiet_plan_rules r
      where r.user_id = p_user and r.group_id = p_group),
    (select r from public.quiet_plan_rules r
      where r.user_id = p_user and r.group_id = '00000000-0000-0000-0000-000000000000'),
    row(p_user, p_group, 3, '{}'::uuid[], now())::public.quiet_plan_rules
  );
$$;

-- ---------------------------------------------------------------------------
-- The matcher
-- ---------------------------------------------------------------------------
-- Given a group, find the best overlap among its open windows and, if every
-- participant's criteria are satisfied, turn it into an event.
--
-- "Best" is the longest overlap shared by the most people: candidate boundaries
-- are the window edges, so the sweep only has to consider those. The group is
-- small (a handful of people with at most a few open windows each), so this is
-- a nested loop over boundaries rather than anything cleverer.
--
-- Criteria are applied as a fixed point: dropping someone whose minimum isn't
-- met can put another person below theirs, so the set shrinks until it settles
-- or empties.
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
  -- Anything whose window has passed stops being a candidate.
  update public.quiet_plans
     set status = 'expired'
   where group_id = p_group and status = 'open' and window_end <= now();

  -- The overlap with the most people in it, of at least everyone's minimum
  -- length. Boundaries come from the windows themselves.
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

  -- Shared with the group, so it arrives as an invitation and everyone answers
  -- going or not going — the same road a found date takes.
  insert into public.event_shares (event_id, group_id) values (v_event, p_group);

  update public.quiet_plans
     set status = 'matched', matched_event_id = v_event
   where id = any(v_ids);

  -- The group's own trigger tells everyone but the owner about the share. This
  -- one is for the people whose quiet plans made it happen, the owner included,
  -- and it is the "a date was found" kind of news rather than an invitation.
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
-- What the app calls
-- ---------------------------------------------------------------------------
create or replace function public.create_quiet_plan(
  p_group uuid, p_start timestamptz, p_end timestamptz,
  p_title text default null, p_min_minutes int default 60
) returns table (quiet_plan_id uuid, matched_event_id uuid)
language plpgsql volatile security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_id  uuid;
  v_event uuid;
begin
  if v_uid is null then
    raise exception 'Sign in to make a plan' using errcode = '42501';
  end if;
  if not private.is_group_member(p_group, v_uid) then
    raise exception 'That group is not yours' using errcode = '42501';
  end if;
  if p_end <= p_start then
    raise exception 'A window has to end after it starts' using errcode = '22007';
  end if;

  -- Same shape as the other caps: quiet plans are cheap to post and would
  -- otherwise be a way to probe a group's free time by posting many windows.
  perform private.enforce_rate_limit('quiet_plan', 30, interval '1 hour');

  insert into public.quiet_plans (user_id, group_id, title, window_start, window_end, min_minutes)
  values (v_uid, p_group, nullif(trim(coalesce(p_title, '')), ''), p_start, p_end,
          greatest(15, least(1440, coalesce(p_min_minutes, 60))))
  returning id into v_id;

  v_event := private.match_quiet_plans(p_group);
  return query select v_id, v_event;
end;
$$;

revoke all on function public.create_quiet_plan(uuid, timestamptz, timestamptz, text, int)
  from public, anon;
grant execute on function public.create_quiet_plan(uuid, timestamptz, timestamptz, text, int)
  to authenticated;

-- Cancelling is a status change rather than a delete, so a matched plan keeps
-- pointing at the event it produced.
create or replace function public.cancel_quiet_plan(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  update public.quiet_plans
     set status = 'cancelled'
   where id = p_id and user_id = auth.uid() and status = 'open';
end;
$$;

revoke all on function public.cancel_quiet_plan(uuid) from public, anon;
grant execute on function public.cancel_quiet_plan(uuid) to authenticated;
