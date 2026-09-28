-- 0030_one_quiet_plan.sql — one open quiet plan per person.
--
-- Several at once were allowed, which sounded generous and reads badly: the
-- You tab becomes a list to manage, "your quiet plan" stops naming one thing,
-- and someone can blanket a fortnight with windows until something sticks,
-- which is a way of asking the group when it is free without ever saying so.
--
-- So a new one replaces the old. Posting is the whole gesture — there is
-- nothing to tidy up afterwards and nothing to explain.
--
-- Matched plans are untouched: they are history, pointing at the event they
-- produced, and a person may have any number of those.

-- Delete rather than cancel the one being replaced: a superseded window is not
-- a decision anybody needs a record of.
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

  perform private.enforce_rate_limit('quiet_plan', 30, interval '1 hour');

  -- The one you had, whichever group it was in.
  delete from public.quiet_plans
   where user_id = v_uid and status = 'open';

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

-- Belt and braces. The function above is the only way the app posts one, but
-- the table is writable through the API by its owner, and "one" should be a
-- fact about the data rather than a habit of one function.
create unique index if not exists uq_quiet_plans_one_open
  on public.quiet_plans (user_id)
  where status = 'open';
