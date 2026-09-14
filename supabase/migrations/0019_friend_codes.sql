-- 0019_friend_codes.sql — find a friend by username#code instead of by email.
--
-- Until now the only way to reach someone you couldn't already see was their
-- exact email (find_profile_by_email, 0005). That fails for anyone who signs in
-- with Apple's Hide My Email, and it made "does this email have an account?" a
-- question any signed-in user could ask.
--
-- The replacement is a handle: the name a person chose (profiles.display_name,
-- which the app now calls their username) plus a permanent 6-digit code, e.g.
-- `Maya#482913`.
--
--   • The code is unique across ALL accounts, not per username. That is what
--     lets it survive a rename: a per-name code could collide with someone else's
--     the moment the name changed.
--   • It never changes for the life of the account (trigger below).
--   • Lookup needs the name AND the code. The code alone is six digits — a
--     million guesses enumerates every account; pairing it with the name makes
--     the handle something you have to be given.
--
-- Capacity is 1,000,000 codes. Widening later means a longer code for new
-- accounts only; existing handles keep working.

-- ---------------------------------------------------------------------------
-- Usernames: what the handle format needs from display_name
-- ---------------------------------------------------------------------------
-- `#` separates name from code, so a name can't contain one. 32 characters
-- keeps a handle typeable. Every existing profile already satisfies both
-- (checked against the live project before writing this). Blank stays allowed:
-- an Apple account with no name arrives blank and the app names it at once.
alter table public.profiles
  drop constraint if exists profiles_username_valid;
alter table public.profiles
  add constraint profiles_username_valid
  check (position('#' in display_name) = 0 and char_length(display_name) <= 32);

-- ---------------------------------------------------------------------------
-- The code
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists friend_code text;

-- Definer so the "already taken?" check sees every profile, not just the ones
-- RLS shows the inserting user. Lives in `private`, which the Data API doesn't
-- expose. Not a secret generator: codes are meant to be handed out, so
-- random() is enough; uniqueness is what matters, and the index enforces it.
create or replace function private.unused_friend_code()
returns text language plpgsql volatile security definer set search_path = public as $$
declare
  v_code text;
begin
  for attempt in 1..100 loop
    v_code := lpad(floor(random() * 1000000)::int::text, 6, '0');
    if not exists (select 1 from public.profiles where friend_code = v_code) then
      return v_code;
    end if;
  end loop;
  raise exception 'No unused friend code found after 100 attempts';
end;
$$;

revoke all on function private.unused_friend_code() from public, anon, authenticated;

-- Existing accounts get theirs before the column becomes required.
do $$
declare
  r record;
begin
  for r in select id from public.profiles where friend_code is null loop
    update public.profiles set friend_code = private.unused_friend_code() where id = r.id;
  end loop;
end;
$$;

alter table public.profiles
  alter column friend_code set not null;
alter table public.profiles
  drop constraint if exists profiles_friend_code_format;
alter table public.profiles
  add constraint profiles_friend_code_format check (friend_code ~ '^[0-9]{6}$');
create unique index if not exists uq_profiles_friend_code on public.profiles(friend_code);

-- Assigned on insert, whoever inserts: handle_new_user() for new sign-ups, or
-- the app's fallback insert for an account that predates that trigger.
-- Definer, like 0006's trigger functions: the app's own fallback insert runs as
-- `authenticated`, which has no rights in `private`.
create or replace function private.assign_friend_code()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.friend_code is null then
    new.friend_code := private.unused_friend_code();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_friend_code on public.profiles;
create trigger trg_profiles_friend_code
  before insert on public.profiles
  for each row execute function private.assign_friend_code();

-- Permanent. profiles_update (0002) lets people edit their own row, which
-- includes this column, so the rule has to live below RLS.
create or replace function private.keep_friend_code()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.friend_code is distinct from old.friend_code then
    raise exception 'A friend code never changes' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_keep_friend_code on public.profiles;
create trigger trg_profiles_keep_friend_code
  before update on public.profiles
  for each row execute function private.keep_friend_code();

-- ---------------------------------------------------------------------------
-- New accounts: a provider's name must fit the username rules
-- ---------------------------------------------------------------------------
-- Same as 0018, plus: strip `#` and cap at 32, so a Google name can never make
-- the insert fail the constraint above (which would fail the whole sign-up).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, timezone)
  values (
    new.id,
    left(btrim(replace(coalesce(
      nullif(trim(new.raw_user_meta_data->>'display_name'), ''),
      nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
      nullif(trim(new.raw_user_meta_data->>'name'), ''),
      ''
    ), '#', '')), 32),
    coalesce(new.raw_user_meta_data->>'timezone', 'UTC')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Lookup
-- ---------------------------------------------------------------------------
-- Definer for the same reason as the email version it replaces: the person
-- you're looking for is, by definition, someone RLS doesn't show you yet.
-- Case-insensitive on the name, exact on the code, never yourself.
create or replace function public.find_profile_by_handle(p_username text, p_code text)
returns table (id uuid, display_name text, avatar_hue text, avatar_url text)
language sql stable security definer set search_path = public as $$
  select p.id, p.display_name, p.avatar_hue, p.avatar_url
    from public.profiles p
   where p.friend_code = btrim(p_code)
     and lower(p.display_name) = lower(btrim(p_username))
     and p.id <> auth.uid()
   limit 1;
$$;

revoke all on function public.find_profile_by_handle(text, text) from public, anon;
grant execute on function public.find_profile_by_handle(text, text) to authenticated;

-- The email lookup goes: nothing calls it after this release, and it answered
-- "does this address have an account?" for anyone signed in.
drop function if exists public.find_profile_by_email(text);
