-- 0010_group_events_rsvp.sql — from "vote on when" to "propose one time, RSVP".
--
-- The old shape: the finder wrote a proposal with several slots, the group voted
-- on which slot they preferred, and an organiser locked one in. The new shape,
-- and the reason for this migration:
--
--   1. The finder is now a preview. Whoever ran it picks ONE time.
--   2. That time becomes a real event, owned by them, shared with the group.
--   3. Every member answers going / not going.
--   4. Saying yes puts the event on YOUR calendar, whatever anyone else says.
--
-- The visibility trick is the point: an event shared with a *group* is only
-- visible as an invitation. It reaches your calendar when a row exists in
-- event_shares naming *you* — so "confirm" literally means "grant myself
-- visibility", and "decline" means "take it away again".
--
-- proposals / proposal_slots / votes are left in place, unused. Dropping them
-- would be a one-way door, and they cost nothing empty.

-- ---------------------------------------------------------------------------
-- Who's coming
-- ---------------------------------------------------------------------------
create type rsvp_response as enum ('going', 'not_going');

create table public.event_rsvps (
  event_id   uuid not null references public.events(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  response   rsvp_response not null,
  updated_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
create index idx_rsvps_event on public.event_rsvps(event_id);

alter table public.event_rsvps enable row level security;

-- Everyone invited can see who's coming — that's the point of a group plan.
-- `user_id = auth.uid()` leads deliberately: a policy that can only answer by
-- looking the row up elsewhere can't authorise an insert that returns the row
-- it just wrote (see 0009).
create policy rsvps_select on public.event_rsvps for select to authenticated
  using ( user_id = auth.uid()
       or public.can_view_event(event_id, auth.uid()) );

-- Writes go through rsvp_to_event(); these exist so a client can read its own
-- state back and so a decline can be withdrawn.
create policy rsvps_write on public.event_rsvps for all to authenticated
  using ( user_id = auth.uid() ) with check ( user_id = auth.uid() );

grant select, insert, update, delete on public.event_rsvps to authenticated;

-- ---------------------------------------------------------------------------
-- Is this event actually offered to me?
-- ---------------------------------------------------------------------------
-- An invitation is an event shared with a group I belong to. Definer because it
-- reads event_shares for an event I may not be able to see yet.
create or replace function public.is_event_invitee(p_event uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.event_shares s
     where s.event_id = p_event
       and s.group_id is not null
       and public.is_group_member(s.group_id, p_user)
  );
$$;

grant execute on function public.is_event_invitee(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Answering
-- ---------------------------------------------------------------------------
-- Definer for one specific reason: saying yes means creating an event_shares
-- row naming you, and shares_insert only lets the event's *owner* do that. The
-- attendee is granting themselves visibility, which is safe precisely because
-- this function checks the invitation first.
create or replace function public.rsvp_to_event(p_event uuid, p_going boolean)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Sign in to answer an invitation' using errcode = '42501';
  end if;

  -- The owner is going by definition and doesn't need a share; the event is
  -- already theirs. Let them decline, though — plans change.
  if not public.is_event_invitee(p_event, v_uid)
     and not public.is_event_owner(p_event, v_uid) then
    raise exception 'That invitation is not for you' using errcode = '42501';
  end if;

  insert into public.event_rsvps (event_id, user_id, response)
  values (p_event, v_uid, case when p_going then 'going' else 'not_going' end)
  on conflict (event_id, user_id)
  do update set response = excluded.response, updated_at = now();

  if p_going then
    -- This is the whole mechanism: a personal share is what puts an event on
    -- someone's calendar. The owner already sees their own event, so giving
    -- them a share too would just be a redundant row.
    if not public.is_event_owner(p_event, v_uid) then
      insert into public.event_shares (event_id, shared_user_id)
      values (p_event, v_uid)
      on conflict do nothing;
    end if;
  else
    delete from public.event_shares
     where event_id = p_event and shared_user_id = v_uid;
  end if;
end;
$$;

revoke all on function public.rsvp_to_event(uuid, boolean) from public, anon;
grant execute on function public.rsvp_to_event(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Live updates
-- ---------------------------------------------------------------------------
-- An RSVP changes what everyone else sees, so it belongs on the group topic.
create or replace function private.on_rsvp_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_group uuid;
begin
  select s.group_id into v_group
    from public.event_shares s
   where s.event_id = coalesce(new.event_id, old.event_id)
     and s.group_id is not null
   limit 1;
  perform private.broadcast_group_change(v_group, 'events');
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_broadcast_rsvps on public.event_rsvps;
create trigger trg_broadcast_rsvps
  after insert or update or delete on public.event_rsvps
  for each row execute function private.on_rsvp_change();
