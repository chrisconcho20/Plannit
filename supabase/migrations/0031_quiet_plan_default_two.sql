-- 0031_quiet_plan_default_two.sql — two people is a plan.
--
-- 0027 asked for three before a quiet plan could become real, on the thinking
-- that two people is a conversation rather than an occasion. In use that reads
-- as a feature that rarely fires: two friends free on the same afternoon is the
-- ordinary case, and the one most worth catching.
--
-- Rows somebody has already saved are left exactly as they are: those are
-- choices, not defaults.

alter table public.quiet_plan_rules alter column min_people set default 2;

-- The built-in used when a person has saved no rule at all.
create or replace function private.quiet_plan_rule(p_user uuid, p_group uuid)
returns public.quiet_plan_rules language sql stable security definer
set search_path = public as $$
  select coalesce(
    (select r from public.quiet_plan_rules r
      where r.user_id = p_user and r.group_id = p_group),
    (select r from public.quiet_plan_rules r
      where r.user_id = p_user and r.group_id = '00000000-0000-0000-0000-000000000000'),
    row(p_user, p_group, 2, '{}'::uuid[], now())::public.quiet_plan_rules
  );
$$;
