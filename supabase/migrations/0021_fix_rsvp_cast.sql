-- 0021_fix_rsvp_cast.sql — answering an invitation has never saved.
--
-- rsvp_to_event() (0010) inserted `case when p_going then 'going' else
-- 'not_going' end` into event_rsvps.response. A CASE over bare literals
-- resolves to text, and there is no implicit cast from text to an enum, so
-- every call failed with 42804 ("column response is of type rsvp_response but
-- expression is of type text"). Found 2026-09-14 while rehearsing 0022 against
-- the live project: event_rsvps had no rows at all.
--
-- What people saw: Going / Can't make it always showed "Couldn't save your
-- answer", and sending a found date to a group created and shared the event but
-- then reported "Couldn't send that to the group" when marking the organiser as
-- going. The client tests stub the network, so they never reached this.
--
-- Identical to 0010's function apart from the cast.

create or replace function public.rsvp_to_event(p_event uuid, p_going boolean)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Sign in to answer an invitation' using errcode = '42501';
  end if;

  if not public.is_event_invitee(p_event, v_uid)
     and not public.is_event_owner(p_event, v_uid) then
    raise exception 'That invitation is not for you' using errcode = '42501';
  end if;

  insert into public.event_rsvps (event_id, user_id, response)
  values (p_event, v_uid,
          (case when p_going then 'going' else 'not_going' end)::public.rsvp_response)
  on conflict (event_id, user_id)
  do update set response = excluded.response, updated_at = now();

  if p_going then
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
