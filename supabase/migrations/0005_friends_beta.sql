-- 0005_friends_beta.sql — the friend graph, plus a beta switch that makes
-- everyone friends automatically.
--
-- The `friendships` table has existed since 0001; nothing wrote to it. This adds
-- the two pieces the app needs around it:
--
--   1. `app_config` — runtime switches. `auto_friend_everyone` is ON for the
--      beta so a new account can immediately plan with anyone. Turning it off is
--      an UPDATE, not a migration:
--          update public.app_config set value = 'false' where key = 'auto_friend_everyone';
--      Existing friendships are left alone when it's turned off.
--   2. `find_profile_by_email` — the only way to reach someone you can't already
--      see. Exact email match only, so the directory can't be enumerated.

-- ---------------------------------------------------------------------------
-- Runtime config
-- ---------------------------------------------------------------------------
create table if not exists public.app_config (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

insert into public.app_config (key, value)
values ('auto_friend_everyone', 'true'::jsonb)
on conflict (key) do nothing;

alter table public.app_config enable row level security;

-- Readable by any signed-in user (the app shows different copy in beta mode);
-- writable only from the dashboard / service role.
drop policy if exists app_config_select on public.app_config;
create policy app_config_select on public.app_config for select to authenticated using (true);

create or replace function public.config_flag(p_key text, p_default boolean default false)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select value::text::boolean from public.app_config where key = p_key), p_default);
$$;

-- ---------------------------------------------------------------------------
-- Beta: every new profile becomes friends with everyone else
-- ---------------------------------------------------------------------------
create or replace function public.auto_friend_new_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.config_flag('auto_friend_everyone') then
    return new;
  end if;

  -- One row per pair; uq_friendship_pair keeps direction from mattering.
  insert into public.friendships (requester_id, addressee_id, status)
  select new.id, p.id, 'accepted'
    from public.profiles p
   where p.id <> new.id
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists trg_auto_friend_new_profile on public.profiles;
create trigger trg_auto_friend_new_profile
  after insert on public.profiles
  for each row execute function public.auto_friend_new_profile();

-- Backfill: everyone who already exists becomes friends too, so the beta
-- doesn't have a "joined before the switch" underclass.
insert into public.friendships (requester_id, addressee_id, status)
select a.id, b.id, 'accepted'
  from public.profiles a
  join public.profiles b on b.id > a.id
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Finding someone you can't already see
-- ---------------------------------------------------------------------------
-- profiles RLS only exposes yourself, your friends and your groups' co-members —
-- correct, but it means you can't look up a stranger to befriend them. This is
-- the deliberate hole: an exact, case-insensitive email match, returning only
-- what you need to send a request. No prefix search, no listing.
create or replace function public.find_profile_by_email(p_email text)
returns table (id uuid, display_name text)
language sql stable security definer set search_path = public as $$
  select p.id, p.display_name
    from public.profiles p
    join auth.users u on u.id = p.id
   where lower(u.email) = lower(trim(p_email))
     and p.id <> auth.uid()
   limit 1;
$$;

revoke all on function public.find_profile_by_email(text) from public, anon;
grant execute on function public.find_profile_by_email(text) to authenticated;
grant execute on function public.config_flag(text, boolean) to authenticated;
grant select on public.app_config to authenticated;

-- ---------------------------------------------------------------------------
-- Friend list helper — profiles of everyone you're accepted friends with.
-- ---------------------------------------------------------------------------
-- The client could join this itself, but `friendships` has two foreign keys to
-- `profiles`, which makes a PostgREST embed ambiguous. One function is cheaper
-- than two round trips plus a hint that depends on generated constraint names.
create or replace function public.my_friends()
returns table (id uuid, display_name text)
language sql stable security definer set search_path = public as $$
  select p.id, p.display_name
    from public.friendships f
    join public.profiles p
      on p.id = case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
   where f.status = 'accepted'
     and (f.requester_id = auth.uid() or f.addressee_id = auth.uid())
   order by p.display_name;
$$;

grant execute on function public.my_friends() to authenticated;

-- Pending requests, in both directions.
--
-- This has to be a definer function for a subtle reason: `profiles` RLS shows
-- you friends and co-members, and someone who has merely *requested* you is
-- neither — so a plain join would hand you a request from "Member" with no way
-- to judge it. The function exposes exactly the name attached to a request that
-- already involves you, and nothing else.
create or replace function public.my_friend_requests()
returns table (id uuid, other_id uuid, display_name text, incoming boolean, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select f.id,
         case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end,
         p.display_name,
         f.addressee_id = auth.uid() as incoming,
         f.created_at
    from public.friendships f
    join public.profiles p
      on p.id = case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
   where f.status = 'pending'
     and (f.requester_id = auth.uid() or f.addressee_id = auth.uid())
   order by f.created_at desc;
$$;

grant execute on function public.my_friend_requests() to authenticated;
