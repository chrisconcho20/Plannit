-- 0023_rate_limits.sql — per-person caps on the calls worth abusing.
--
-- Nothing throttled friend lookups, friend requests, invite links or the date
-- finder (docs/beta-to-production.md §5). Sign-up and sign-in are already
-- limited per IP by Supabase Auth (Authentication → Rate Limits), so this
-- covers what Auth doesn't see.
--
--   action           limit            why it matters
--   find_friend      30 / 10 min      guessing a username#code
--   friend_request   30 / hour        spamming requests at found handles
--   create_invite    30 / hour        minting links in bulk
--   redeem_invite    20 / hour        trying tokens
--   find_slots       60 / hour        each search reads every member's busy time
--
-- Over the limit, PostgREST answers HTTP 429 with a Retry-After header (the
-- documented `RAISE SQLSTATE 'PGRST'` form). The raise rolls back the attempt
-- that tripped it, so refused calls don't extend the lockout; the count resets
-- when the window does.

create table if not exists private.rate_limit_hits (
  user_id      uuid        not null,
  action       text        not null,
  window_start timestamptz not null,
  hits         int         not null default 1,
  primary key (user_id, action, window_start)
);
-- Not exposed by the Data API either way; RLS on with no policies keeps it
-- closed even if the schema ever is.
alter table private.rate_limit_hits enable row level security;
revoke all on private.rate_limit_hits from public, anon, authenticated;

create or replace function private.enforce_rate_limit(p_action text, p_max int, p_window interval)
returns void language plpgsql volatile security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_start timestamptz := date_bin(p_window, now(), timestamptz '2000-01-01 00:00:00+00');
  v_hits  int;
begin
  -- Service-role and trigger-internal calls have no user to count.
  if v_uid is null then
    return;
  end if;

  insert into private.rate_limit_hits as r (user_id, action, window_start)
  values (v_uid, p_action, v_start)
  on conflict (user_id, action, window_start) do update set hits = r.hits + 1
  returning r.hits into v_hits;

  -- Earlier windows for this person and action are finished; clear them as we go.
  delete from private.rate_limit_hits
   where user_id = v_uid and action = p_action and window_start < v_start;

  if v_hits > p_max then
    raise sqlstate 'PGRST' using
      message = json_build_object(
        'code', 'rate_limited',
        'message', 'Too many requests. Try again shortly.',
        'details', p_action,
        'hint', null)::text,
      detail = json_build_object(
        'status', 429,
        'headers', json_build_object(
          'Retry-After', ceil(extract(epoch from (v_start + p_window - now())))::int::text))::text;
  end if;
end;
$$;

revoke all on function private.enforce_rate_limit(text, int, interval) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The date finder (Edge Function) asks before searching
-- ---------------------------------------------------------------------------
-- Limits are fixed here, not passed in, so calling this directly can only use
-- up your own allowance.
create or replace function public.consume_rate_limit(p_action text)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  case p_action
    when 'find_slots' then perform private.enforce_rate_limit('find_slots', 60, interval '1 hour');
    else raise exception 'Unknown rate-limited action %', p_action using errcode = '22023';
  end case;
end;
$$;

revoke all on function public.consume_rate_limit(text) from public, anon;
grant execute on function public.consume_rate_limit(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Friend lookup — same as 0020 plus the limit. Volatile now: it writes a count,
-- and PostgREST runs STABLE functions in a read-only transaction.
-- ---------------------------------------------------------------------------
create or replace function public.find_profile_by_handle(p_username text, p_code text)
returns table (id uuid, display_name text, avatar_hue text, avatar_url text)
language plpgsql volatile security definer set search_path = public as $$
begin
  perform private.enforce_rate_limit('find_friend', 30, interval '10 minutes');
  return query
  select p.id, p.display_name, p.avatar_hue, p.avatar_url
    from public.profiles p
   where p.friend_code = translate(upper(replace(p_code, ' ', '')), 'OIL', '011')
     and lower(p.display_name) = lower(btrim(p_username))
     and p.id <> auth.uid()
   limit 1;
end;
$$;

revoke all on function public.find_profile_by_handle(text, text) from public, anon;
grant execute on function public.find_profile_by_handle(text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Friend requests are plain inserts, so the limit is a trigger
-- ---------------------------------------------------------------------------
-- Depth 1 only: rows written by another trigger (0005's auto-friending of a new
-- profile) aren't someone sending requests, and counting them could fail a
-- sign-up once there are more users than the limit.
create or replace function private.limit_friend_requests()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if pg_trigger_depth() = 1 then
    perform private.enforce_rate_limit('friend_request', 30, interval '1 hour');
  end if;
  return new;
end;
$$;

revoke all on function private.limit_friend_requests() from public, anon, authenticated;

drop trigger if exists trg_limit_friend_requests on public.friendships;
create trigger trg_limit_friend_requests
  before insert on public.friendships
  for each row execute function private.limit_friend_requests();

-- ---------------------------------------------------------------------------
-- Invites — same as 0007 / 0022 plus the limit
-- ---------------------------------------------------------------------------
create or replace function public.create_group_invite(p_group uuid)
returns table (token text, expires_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare
  v_token   text;
  v_expires timestamptz;
begin
  if not public.is_group_member(p_group, auth.uid()) then
    raise exception 'You are not a member of this group' using errcode = '42501';
  end if;
  perform private.enforce_rate_limit('create_invite', 30, interval '1 hour');

  insert into public.invites (group_id, created_by)
  values (p_group, auth.uid())
  returning invites.token, invites.expires_at into v_token, v_expires;

  return query select v_token, v_expires;
end;
$$;

revoke all on function public.create_group_invite(uuid) from public, anon;
grant execute on function public.create_group_invite(uuid) to authenticated;

create or replace function public.redeem_invite(p_token text)
returns table (group_id uuid, group_name text, already_member boolean)
language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_invite public.invites%rowtype;
  v_name   text;
  v_rows   int;
  v_added  boolean;
begin
  if v_uid is null then
    raise exception 'Sign in to accept an invite' using errcode = '42501';
  end if;
  perform private.enforce_rate_limit('redeem_invite', 20, interval '1 hour');

  select * into v_invite
    from public.invites i
   where i.token = trim(p_token)
   for update;

  if not found then
    raise exception 'This invite link is not valid';
  elsif v_invite.expires_at <= now() then
    raise exception 'This invite link has expired';
  elsif v_invite.uses >= v_invite.max_uses then
    raise exception 'This invite link has been used up';
  end if;

  if v_invite.group_id is not null
     and not private.is_group_member(v_invite.group_id, v_invite.created_by) then
    raise exception 'This invite link is no longer valid';
  end if;

  if v_invite.created_by <> v_uid then
    insert into public.friendships (requester_id, addressee_id, status)
    values (v_invite.created_by, v_uid, 'accepted')
    on conflict (least(requester_id, addressee_id), greatest(requester_id, addressee_id))
    do update set status = 'accepted'
    where friendships.status = 'pending';
  end if;

  if v_invite.group_id is null then
    return query select null::uuid, null::text, false;
    return;
  end if;

  insert into public.group_memberships (group_id, user_id, role)
  values (v_invite.group_id, v_uid, 'member')
  on conflict do nothing;
  get diagnostics v_rows = row_count;
  v_added := v_rows > 0;

  if v_added then
    update public.invites i set uses = i.uses + 1 where i.id = v_invite.id;
  end if;

  select g.name into v_name from public.groups g where g.id = v_invite.group_id;

  return query select v_invite.group_id, v_name, not v_added;
end;
$$;

revoke all on function public.redeem_invite(text) from public, anon;
grant execute on function public.redeem_invite(text) to authenticated;
