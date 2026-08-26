-- 0014_reschedule_event.sql — the organiser moves a plan.
--
-- Until now the only way to change a group plan's time was to delete it and run
-- the finder again, which throws away everyone's answers and sends a fresh
-- invitation for what is, to everyone else, the same plan.
--
-- The interesting question isn't the update, it's what happens to the people who
-- already said yes. Two bad answers and one good one:
--
--   • Keep every answer, always. Someone who agreed to Saturday 2pm is now
--     down as going to Sunday 9am without being asked. That's the stale yes
--     the whole RSVP design exists to prevent (D-18).
--   • Clear every answer, always. Moving a plan by fifteen minutes re-opens a
--     settled decision and pesters six people for nothing.
--   • **Clear them only when the DAY changes.** A different time on the same
--     day is a detail; a different day is a different commitment — it's the
--     line people already use when they decide whether to re-check their
--     calendar.
--
-- The client decides which case it is and passes `p_reset`, because that rule is
-- about human intent and belongs where the copy that explains it lives. The
-- function does what it's told, but only for the owner.

create or replace function public.reschedule_event(
  p_event uuid,
  p_start timestamptz,
  p_end   timestamptz,
  p_reset boolean default false
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_owner uuid;
  v_group uuid;
begin
  select owner_id into v_owner
    from public.events
   where id = p_event and deleted_at is null;

  if v_owner is null then
    raise exception 'That plan no longer exists' using errcode = 'P0002';
  end if;
  -- Definer bypasses RLS, so the ownership check is the whole authorisation.
  if v_owner is distinct from v_uid then
    raise exception 'Only whoever made the plan can move it' using errcode = '42501';
  end if;
  if p_end <= p_start then
    raise exception 'A plan has to end after it starts' using errcode = '22007';
  end if;

  update public.events
     set start_at = p_start, end_at = p_end
   where id = p_event;

  if p_reset then
    -- Everyone answers again. Taking the personal share back with the answer is
    -- what actually removes it from their calendar — the share IS the
    -- visibility (0010), so leaving it would show them a time they never
    -- agreed to.
    delete from public.event_rsvps
     where event_id = p_event and user_id <> v_owner;
    delete from public.event_shares
     where event_id = p_event
       and shared_user_id is not null
       and shared_user_id <> v_owner;
  end if;

  -- Tell the group either way: the time changed for everyone still going.
  select s.group_id into v_group
    from public.event_shares s
   where s.event_id = p_event and s.group_id is not null
   limit 1;
  perform private.broadcast_group_change(v_group, 'events');
end;
$$;

revoke all on function public.reschedule_event(uuid, timestamptz, timestamptz, boolean)
  from public, anon;
grant execute on function public.reschedule_event(uuid, timestamptz, timestamptz, boolean)
  to authenticated;
