-- 0007_invites.sql — invite links: a URL that puts someone in your group.
--
-- The cold-start problem is the whole reason this exists. Asking a friend to
-- install an app, sign in with Apple, find you by exact email and send a request
-- is four chances to give up. A texted link collapses that to one tap.
--
-- Scope note: this is the *link*, not decision D-14 (non-user web participation
-- — voting from a browser without the app). Redeeming still requires a signed-in
-- Plannit account; only `peek_invite` is reachable without one.
--
-- Three functions rather than direct table access, because each does something
-- RLS can't:
--   create_group_invite — needs to write a row whose token the caller must not choose
--   redeem_invite       — writes into a group the caller is provably not yet in
--   peek_invite         — must answer an anonymous browser, which RLS shows nothing

-- pgcrypto lives in the `extensions` schema on Supabase, so the bare
-- `create extension` in 0001 is a no-op there and gen_random_bytes() is not on
-- the search_path of a function pinned to `public`. Qualify it explicitly.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- invites
-- ---------------------------------------------------------------------------
create table public.invites (
  id         uuid primary key default gen_random_uuid(),
  -- 128 bits of CSPRNG, hex. The token *is* the authorization: anyone holding
  -- it joins the group. A sequential id or a uuid derived from a timestamp
  -- would let someone walk the space and land in strangers' groups, so this
  -- must be unguessable rather than merely unique.
  token      text not null unique
             default encode(extensions.gen_random_bytes(16), 'hex'),
  -- Null group = a friend-only invite ("add me on Plannit"), which creates the
  -- friendship and nothing else.
  group_id   uuid references public.groups(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  -- Links that live forever are links that leak. Two weeks and 25 uses cover a
  -- group chat without leaving a permanent back door in a WhatsApp scrollback.
  expires_at timestamptz not null default now() + interval '14 days',
  max_uses   int not null default 25,
  uses       int not null default 0,
  created_at timestamptz not null default now()
);
create index idx_invites_group on public.invites(group_id);

alter table public.invites enable row level security;

-- Members see and create their group's invites; a friend-only invite is visible
-- only to whoever made it.
create policy invites_select on public.invites for select to authenticated
  using ( created_by = auth.uid()
       or (group_id is not null and public.is_group_member(group_id, auth.uid())) );

-- `created_by = auth.uid()` is not decoration: without it a member could mint an
-- invite attributed to someone else, and the redeemer would be auto-friended to
-- a person who never invited them.
create policy invites_insert on public.invites for insert to authenticated
  with check ( created_by = auth.uid()
           and (group_id is null or public.is_group_member(group_id, auth.uid())) );

create policy invites_delete on public.invites for delete to authenticated
  using ( created_by = auth.uid() );

-- No UPDATE policy and no UPDATE grant, on purpose. `uses` is the only mutable
-- column and the whole point of the cap is that the holder of a link can't
-- raise it. redeem_invite() is SECURITY DEFINER and so bypasses both.
grant select, insert, delete on public.invites to authenticated;

-- ---------------------------------------------------------------------------
-- Creating
-- ---------------------------------------------------------------------------
-- Definer because the token must be generated server-side. If the client
-- inserted its own row it would also choose its own token, and a token chosen
-- by the client is a token an attacker can predict.
create or replace function public.create_group_invite(p_group uuid)
returns table (token text, expires_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare
  v_token   text;
  v_expires timestamptz;
begin
  -- 42501 so PostgREST answers 403 rather than a generic 400.
  if not public.is_group_member(p_group, auth.uid()) then
    raise exception 'You are not a member of this group' using errcode = '42501';
  end if;

  insert into public.invites (group_id, created_by)
  values (p_group, auth.uid())
  returning invites.token, invites.expires_at into v_token, v_expires;

  return query select v_token, v_expires;
end;
$$;

-- ---------------------------------------------------------------------------
-- Redeeming
-- ---------------------------------------------------------------------------
-- The one that matters. Definer for the obvious reason: the caller is by
-- definition not yet in the group, so every policy that guards
-- group_memberships would (correctly) refuse the write. The token is the
-- authorization; this function is where it gets checked.
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

  -- FOR UPDATE: two people tapping the same link at the same moment must not
  -- both read uses = max_uses - 1 and both get in. The lock serialises them.
  select * into v_invite
    from public.invites i
   where i.token = trim(p_token)
   for update;

  -- Three separate messages because the person reading them can act on the
  -- difference — "expired" means ask for a new link, "used up" means ask the
  -- group owner. Nothing here is secret: you already hold the token.
  if not found then
    raise exception 'This invite link is not valid';
  elsif v_invite.expires_at <= now() then
    raise exception 'This invite link has expired';
  elsif v_invite.uses >= v_invite.max_uses then
    raise exception 'This invite link has been used up';
  end if;

  -- Someone who hands you a working invite link and someone who accepts it
  -- plainly know each other, so skip the request/accept dance entirely.
  -- uq_friendship_pair is an expression index; a bare ON CONFLICT DO NOTHING
  -- arbitrates against it without naming it.
  if v_invite.created_by <> v_uid then
    insert into public.friendships (requester_id, addressee_id, status)
    values (v_invite.created_by, v_uid, 'accepted')
    on conflict do nothing;
  end if;

  -- Friend-only invite: there is no group to join and nothing to count.
  if v_invite.group_id is null then
    return query select null::uuid, null::text, false;
    return;
  end if;

  insert into public.group_memberships (group_id, user_id, role)
  values (v_invite.group_id, v_uid, 'member')
  on conflict do nothing;
  get diagnostics v_rows = row_count;
  v_added := v_rows > 0;

  -- Only a real join burns a use. Otherwise reopening the link on a second
  -- device, or a member re-tapping it in the group chat, would exhaust a
  -- perfectly good invite without adding anybody.
  if v_added then
    update public.invites i set uses = i.uses + 1 where i.id = v_invite.id;
  end if;

  select g.name into v_name from public.groups g where g.id = v_invite.group_id;

  return query select v_invite.group_id, v_name, not v_added;
end;
$$;

-- ---------------------------------------------------------------------------
-- Previewing (the only thing in this schema an anonymous browser may call)
-- ---------------------------------------------------------------------------
-- Everything else in Plannit is closed to `anon` because per-group visibility is
-- a product pillar. This is the deliberate exception, and it is narrow: the
-- caller must already hold a 128-bit token, and in exchange gets two strings
-- that were about to be shown to them anyway — the group they're being invited
-- to and the name of the person inviting them. A landing page that said only
-- "you have been invited" would be indistinguishable from a phishing link.
--
-- It always returns exactly one row, and returns empty strings for an invite
-- that is missing, expired or exhausted — never a name — so the page cannot be
-- used to test whether a token ever existed.
create or replace function public.peek_invite(p_token text)
returns table (group_name text, inviter_name text, valid boolean)
language sql stable security definer set search_path = public as $$
  select coalesce(g.name, ''),
         coalesce(nullif(p.display_name, ''), 'Someone'),
         true
    from public.invites i
    left join public.groups   g on g.id = i.group_id
    left join public.profiles p on p.id = i.created_by
   where i.token = trim(p_token)
     and i.expires_at > now()
     and i.uses < i.max_uses
  union all
  select '', '', false
   where not exists (
     select 1 from public.invites i2
      where i2.token = trim(p_token)
        and i2.expires_at > now()
        and i2.uses < i2.max_uses
   );
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
-- Postgres grants EXECUTE to PUBLIC on every new function, and 0002's blanket
-- `grant execute on all functions` only covered what existed then — so these
-- revokes are what actually keeps anon out, not the absence of a grant.
revoke all on function public.create_group_invite(uuid) from public, anon;
revoke all on function public.redeem_invite(text)        from public, anon;
revoke all on function public.peek_invite(text)          from public;

grant execute on function public.create_group_invite(uuid) to authenticated;
grant execute on function public.redeem_invite(text)       to authenticated;
grant execute on function public.peek_invite(text)         to anon, authenticated;
