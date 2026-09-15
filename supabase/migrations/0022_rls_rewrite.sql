-- 0021_rls_rewrite.sql — RLS that asks one question per query, and helpers that
-- only answer about the person asking.
--
-- Two problems, one rewrite (docs/scaling.md §3, docs/security-review.md §4):
--
--   1. Speed. events_select called can_view_event(id, auth.uid()) — a SECURITY
--      DEFINER function doing two EXISTS subqueries — once per candidate row.
--      memberships_select, rsvps_select and the rest had the same shape.
--   2. Oracles. The helpers took arbitrary ids and were EXECUTE-able by PUBLIC,
--      which includes `anon`: anyone holding the publishable key could ask
--      "are these two people friends?" or "is this person in that group?" about
--      anyone, straight through /rest/v1/rpc.
--
-- The shape that fixes both, per Supabase's RLS performance guidance:
--
--   • Definer functions in `private` (not exposed by the Data API) that take no
--     ids and return the caller's own sets — my groups, my events, my people.
--   • Policies of the form `x in (select private.my_...())` and
--     `(select auth.uid())`. Neither is correlated with the row, so Postgres
--     evaluates each once per statement and hashes the result.
--
-- Visibility is meant to be identical before and after. That was checked on the
-- live project by capturing a hash of every table as seen by every user under
-- the old policies, applying this file, recapturing, and rolling back.

-- ---------------------------------------------------------------------------
-- The caller's sets
-- ---------------------------------------------------------------------------
create schema if not exists private;

create or replace function private.my_group_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select m.group_id from public.group_memberships m where m.user_id = auth.uid();
$$;

create or replace function private.my_owned_group_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select g.id from public.groups g where g.owner_id = auth.uid();
$$;

create or replace function private.my_owned_event_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select e.id from public.events e where e.owner_id = auth.uid();
$$;

-- Events shared with me directly or with a group I'm in. Deleted events are not
-- filtered here, matching the can_view_event() this replaces; reads filter
-- `deleted_at` themselves.
create or replace function private.my_shared_event_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select s.event_id
    from public.event_shares s
   where s.shared_user_id = auth.uid()
      or s.group_id in (select m.group_id from public.group_memberships m
                         where m.user_id = auth.uid());
$$;

-- Friends (accepted, either direction) and anyone I share a group with.
create or replace function private.my_connection_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
    from public.friendships f
   where f.status = 'accepted'
     and (f.requester_id = auth.uid() or f.addressee_id = auth.uid())
  union
  select other.user_id
    from public.group_memberships mine
    join public.group_memberships other on other.group_id = mine.group_id
   where mine.user_id = auth.uid();
$$;

-- The retired voting tables (D-18) still carry policies; keep them closed.
create or replace function private.my_proposal_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select pr.id
    from public.proposals pr
   where pr.group_id in (select m.group_id from public.group_memberships m
                          where m.user_id = auth.uid());
$$;

-- For definer code that genuinely has to ask about someone else (an invite's
-- author). Not granted to any client role.
create or replace function private.is_group_member(p_group uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.group_memberships m
                  where m.group_id = p_group and m.user_id = p_user);
$$;

-- Policies run as the querying role, which needs to reach these. The schema is
-- still invisible to the Data API; this only lets policy expressions call in.
grant usage on schema private to authenticated;
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function
  private.my_group_ids(), private.my_owned_group_ids(), private.my_owned_event_ids(),
  private.my_shared_event_ids(), private.my_connection_ids(), private.my_proposal_ids()
  to authenticated;

-- ---------------------------------------------------------------------------
-- Policies
-- ---------------------------------------------------------------------------

-- profiles
drop policy if exists profiles_select on public.profiles;
drop policy if exists profiles_insert on public.profiles;
drop policy if exists profiles_update on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using ( id = (select auth.uid()) or id in (select private.my_connection_ids()) );
create policy profiles_insert on public.profiles for insert to authenticated
  with check ( id = (select auth.uid()) );
create policy profiles_update on public.profiles for update to authenticated
  using ( id = (select auth.uid()) ) with check ( id = (select auth.uid()) );

-- friendships
drop policy if exists friendships_select on public.friendships;
drop policy if exists friendships_insert on public.friendships;
drop policy if exists friendships_update on public.friendships;
drop policy if exists friendships_delete on public.friendships;
create policy friendships_select on public.friendships for select to authenticated
  using ( requester_id = (select auth.uid()) or addressee_id = (select auth.uid()) );
create policy friendships_insert on public.friendships for insert to authenticated
  with check ( requester_id = (select auth.uid()) );
create policy friendships_update on public.friendships for update to authenticated
  using ( requester_id = (select auth.uid()) or addressee_id = (select auth.uid()) )
  with check ( requester_id = (select auth.uid()) or addressee_id = (select auth.uid()) );
create policy friendships_delete on public.friendships for delete to authenticated
  using ( requester_id = (select auth.uid()) or addressee_id = (select auth.uid()) );

-- groups
drop policy if exists groups_select on public.groups;
drop policy if exists groups_insert on public.groups;
drop policy if exists groups_update on public.groups;
drop policy if exists groups_delete on public.groups;
create policy groups_select on public.groups for select to authenticated
  using ( owner_id = (select auth.uid()) or id in (select private.my_group_ids()) );
create policy groups_insert on public.groups for insert to authenticated
  with check ( owner_id = (select auth.uid()) );
create policy groups_update on public.groups for update to authenticated
  using ( owner_id = (select auth.uid()) ) with check ( owner_id = (select auth.uid()) );
create policy groups_delete on public.groups for delete to authenticated
  using ( owner_id = (select auth.uid()) );

-- group_memberships — `user_id = uid` leads so an insert can read its own row
-- back (0009).
drop policy if exists memberships_select on public.group_memberships;
drop policy if exists memberships_insert on public.group_memberships;
drop policy if exists memberships_update on public.group_memberships;
drop policy if exists memberships_delete on public.group_memberships;
create policy memberships_select on public.group_memberships for select to authenticated
  using ( user_id = (select auth.uid()) or group_id in (select private.my_group_ids()) );
create policy memberships_insert on public.group_memberships for insert to authenticated
  with check ( user_id = (select auth.uid()) or group_id in (select private.my_owned_group_ids()) );
create policy memberships_update on public.group_memberships for update to authenticated
  using ( group_id in (select private.my_owned_group_ids()) )
  with check ( group_id in (select private.my_owned_group_ids()) );
create policy memberships_delete on public.group_memberships for delete to authenticated
  using ( user_id = (select auth.uid()) or group_id in (select private.my_owned_group_ids()) );

-- events — the one that ran a function per row.
drop policy if exists events_select on public.events;
drop policy if exists events_insert on public.events;
drop policy if exists events_update on public.events;
drop policy if exists events_delete on public.events;
create policy events_select on public.events for select to authenticated
  using ( owner_id = (select auth.uid()) or id in (select private.my_shared_event_ids()) );
create policy events_insert on public.events for insert to authenticated
  with check ( owner_id = (select auth.uid()) );
create policy events_update on public.events for update to authenticated
  using ( owner_id = (select auth.uid()) ) with check ( owner_id = (select auth.uid()) );
create policy events_delete on public.events for delete to authenticated
  using ( owner_id = (select auth.uid()) );

-- event_shares
drop policy if exists shares_select on public.event_shares;
drop policy if exists shares_insert on public.event_shares;
drop policy if exists shares_delete on public.event_shares;
create policy shares_select on public.event_shares for select to authenticated
  using ( shared_user_id = (select auth.uid())
       or event_id in (select private.my_owned_event_ids())
       or group_id in (select private.my_group_ids()) );
create policy shares_insert on public.event_shares for insert to authenticated
  with check ( event_id in (select private.my_owned_event_ids()) );
create policy shares_delete on public.event_shares for delete to authenticated
  using ( event_id in (select private.my_owned_event_ids()) );

-- event_rsvps
drop policy if exists rsvps_select on public.event_rsvps;
drop policy if exists rsvps_write on public.event_rsvps;
create policy rsvps_select on public.event_rsvps for select to authenticated
  using ( user_id = (select auth.uid())
       or event_id in (select private.my_owned_event_ids())
       or event_id in (select private.my_shared_event_ids()) );
create policy rsvps_write on public.event_rsvps for all to authenticated
  using ( user_id = (select auth.uid()) ) with check ( user_id = (select auth.uid()) );

-- busy_blocks
drop policy if exists busy_all on public.busy_blocks;
create policy busy_all on public.busy_blocks for all to authenticated
  using ( user_id = (select auth.uid()) ) with check ( user_id = (select auth.uid()) );

-- device_tokens
drop policy if exists device_tokens_select on public.device_tokens;
drop policy if exists device_tokens_insert on public.device_tokens;
drop policy if exists device_tokens_update on public.device_tokens;
drop policy if exists device_tokens_delete on public.device_tokens;
create policy device_tokens_select on public.device_tokens for select to authenticated
  using ( user_id = (select auth.uid()) );
create policy device_tokens_insert on public.device_tokens for insert to authenticated
  with check ( user_id = (select auth.uid()) );
create policy device_tokens_update on public.device_tokens for update to authenticated
  using ( user_id = (select auth.uid()) ) with check ( user_id = (select auth.uid()) );
create policy device_tokens_delete on public.device_tokens for delete to authenticated
  using ( user_id = (select auth.uid()) );

-- invites
drop policy if exists invites_select on public.invites;
drop policy if exists invites_insert on public.invites;
drop policy if exists invites_delete on public.invites;
create policy invites_select on public.invites for select to authenticated
  using ( created_by = (select auth.uid()) or group_id in (select private.my_group_ids()) );
create policy invites_insert on public.invites for insert to authenticated
  with check ( created_by = (select auth.uid())
               and (group_id is null or group_id in (select private.my_group_ids())) );
create policy invites_delete on public.invites for delete to authenticated
  using ( created_by = (select auth.uid()) or group_id in (select private.my_owned_group_ids()) );

-- proposals / proposal_slots / votes (retired, still guarded)
drop policy if exists proposals_select on public.proposals;
drop policy if exists proposals_insert on public.proposals;
drop policy if exists proposals_update on public.proposals;
drop policy if exists proposals_delete on public.proposals;
create policy proposals_select on public.proposals for select to authenticated
  using ( group_id in (select private.my_group_ids()) );
create policy proposals_insert on public.proposals for insert to authenticated
  with check ( created_by = (select auth.uid()) and group_id in (select private.my_group_ids()) );
create policy proposals_update on public.proposals for update to authenticated
  using ( created_by = (select auth.uid()) or group_id in (select private.my_owned_group_ids()) )
  with check ( created_by = (select auth.uid()) or group_id in (select private.my_owned_group_ids()) );
create policy proposals_delete on public.proposals for delete to authenticated
  using ( created_by = (select auth.uid()) or group_id in (select private.my_owned_group_ids()) );

drop policy if exists slots_select on public.proposal_slots;
drop policy if exists slots_insert on public.proposal_slots;
create policy slots_select on public.proposal_slots for select to authenticated
  using ( proposal_id in (select private.my_proposal_ids()) );
create policy slots_insert on public.proposal_slots for insert to authenticated
  with check ( proposal_id in (select private.my_proposal_ids()) );

drop policy if exists votes_select on public.votes;
drop policy if exists votes_insert on public.votes;
drop policy if exists votes_update on public.votes;
drop policy if exists votes_delete on public.votes;
create policy votes_select on public.votes for select to authenticated
  using ( proposal_id in (select private.my_proposal_ids()) );
create policy votes_insert on public.votes for insert to authenticated
  with check ( user_id = (select auth.uid()) and proposal_id in (select private.my_proposal_ids()) );
create policy votes_update on public.votes for update to authenticated
  using ( user_id = (select auth.uid()) ) with check ( user_id = (select auth.uid()) );
create policy votes_delete on public.votes for delete to authenticated
  using ( user_id = (select auth.uid()) );

-- ---------------------------------------------------------------------------
-- Definer code that asked about someone else
-- ---------------------------------------------------------------------------
-- redeem_invite checks the invite's *author* is still in the group, so it can't
-- use a helper that only answers about the caller. Identical to 0007 apart from
-- that one call.
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

-- ---------------------------------------------------------------------------
-- The old public helpers
-- ---------------------------------------------------------------------------
-- No policy uses these any more. Five go outright. Three stay because callers
-- outside this file pass the caller's own id — the realtime.messages policy
-- (is_group_member), find-slots (is_group_member) and rsvp_to_event
-- (is_event_owner, is_event_invitee) — and are narrowed to answer only that:
-- any other id gets false.
drop function if exists public.can_view_event(uuid, uuid);
drop function if exists public.are_friends(uuid, uuid);
drop function if exists public.shares_group(uuid, uuid);
drop function if exists public.is_group_owner(uuid, uuid);
drop function if exists public.is_proposal_group_member(uuid, uuid);

create or replace function public.is_group_member(p_group uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_user = auth.uid() and p_group in (select private.my_group_ids());
$$;

create or replace function public.is_event_owner(p_event uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_user = auth.uid() and p_event in (select private.my_owned_event_ids());
$$;

create or replace function public.is_event_invitee(p_event uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_user = auth.uid() and exists (
    select 1 from public.event_shares s
     where s.event_id = p_event
       and s.group_id in (select private.my_group_ids())
  );
$$;

revoke all on function public.is_group_member(uuid, uuid) from public, anon;
revoke all on function public.is_event_owner(uuid, uuid) from public, anon;
revoke all on function public.is_event_invitee(uuid, uuid) from public, anon;
grant execute on function public.is_group_member(uuid, uuid) to authenticated;
grant execute on function public.is_event_owner(uuid, uuid) to authenticated;
grant execute on function public.is_event_invitee(uuid, uuid) to authenticated;
