-- 0006_realtime_broadcast.sql — live updates via Broadcast from Database.
-- Decision D-16; research in docs/realtime-research.md.
--
-- Shape: **notify, then fetch.** A trigger broadcasts a tiny hint — "something
-- about proposals changed in this group" — to a private topic named after the
-- group. The client refreshes that slice itself.
--
-- Why a hint instead of the changed row (which realtime.broadcast_changes would
-- send):
--   • Per-group visibility is a product pillar. A payload that never contains
--     event titles or vote details can't leak them, which is a stronger promise
--     than "RLS re-checks it per subscriber".
--   • Clients already have narrow refreshes (refreshProposals/Events/Groups),
--     so there's nothing to gain from applying deltas by hand — and no risk of
--     the local copy drifting from the server's.
--
-- Every broadcast is wrapped so a notification failure can never fail the write
-- that triggered it. A vote must land even if Realtime is unavailable.

create schema if not exists private;

-- ---------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------
create or replace function private.broadcast_group_change(p_group uuid, p_kind text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_group is null then
    return;
  end if;
  begin
    perform realtime.send(
      jsonb_build_object('kind', p_kind),   -- a hint; never row data
      'change',
      'group:' || p_group::text,
      true                                  -- private topic: the policy below applies
    );
  exception when others then
    null;  -- notifications are best-effort; never break the write
  end;
end;
$$;

-- proposals, and everything that hangs off one
create or replace function private.on_proposal_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform private.broadcast_group_change(
    coalesce(new.group_id, old.group_id), 'proposals');
  return coalesce(new, old);
end;
$$;

create or replace function private.on_proposal_child_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_group uuid;
begin
  select p.group_id into v_group
    from public.proposals p
   where p.id = coalesce(new.proposal_id, old.proposal_id);
  perform private.broadcast_group_change(v_group, 'proposals');
  return coalesce(new, old);
end;
$$;

create or replace function private.on_event_share_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform private.broadcast_group_change(
    coalesce(new.group_id, old.group_id), 'events');
  return coalesce(new, old);
end;
$$;

create or replace function private.on_membership_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform private.broadcast_group_change(
    coalesce(new.group_id, old.group_id), 'groups');
  return coalesce(new, old);
end;
$$;

create or replace function private.on_group_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform private.broadcast_group_change(coalesce(new.id, old.id), 'groups');
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_broadcast_proposals on public.proposals;
create trigger trg_broadcast_proposals
  after insert or update or delete on public.proposals
  for each row execute function private.on_proposal_change();

drop trigger if exists trg_broadcast_votes on public.votes;
create trigger trg_broadcast_votes
  after insert or update or delete on public.votes
  for each row execute function private.on_proposal_child_change();

drop trigger if exists trg_broadcast_slots on public.proposal_slots;
create trigger trg_broadcast_slots
  after insert or delete on public.proposal_slots
  for each row execute function private.on_proposal_child_change();

drop trigger if exists trg_broadcast_shares on public.event_shares;
create trigger trg_broadcast_shares
  after insert or delete on public.event_shares
  for each row execute function private.on_event_share_change();

drop trigger if exists trg_broadcast_memberships on public.group_memberships;
create trigger trg_broadcast_memberships
  after insert or update or delete on public.group_memberships
  for each row execute function private.on_membership_change();

drop trigger if exists trg_broadcast_groups on public.groups;
create trigger trg_broadcast_groups
  after update or delete on public.groups
  for each row execute function private.on_group_change();

-- ---------------------------------------------------------------------------
-- Receiving
-- ---------------------------------------------------------------------------
-- Topics are `group:<uuid>`. Parsing is its own function so a malformed topic
-- returns null instead of raising inside a policy — is_group_member(null, …)
-- is simply false.
create or replace function public.topic_group_id(p_topic text)
returns uuid language plpgsql immutable as $$
begin
  if p_topic is null or left(p_topic, 6) <> 'group:' then
    return null;
  end if;
  return substring(p_topic from 7)::uuid;
exception when others then
  return null;
end;
$$;

grant execute on function public.topic_group_id(text) to authenticated;

-- Realtime Authorization: a private channel is only joinable if a SELECT policy
-- on realtime.messages passes for that topic. Membership is the whole rule.
drop policy if exists "members receive their group's changes" on realtime.messages;
create policy "members receive their group's changes"
on realtime.messages for select to authenticated
using (
  extension = 'broadcast'
  and public.is_group_member(public.topic_group_id(realtime.topic()), auth.uid())
);
