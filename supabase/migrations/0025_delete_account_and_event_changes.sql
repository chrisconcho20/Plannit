-- 0025_delete_account_and_event_changes.sql — leaving Plannit, and plans that
-- disappear everywhere when their owner removes them.

-- ---------------------------------------------------------------------------
-- Deleting your account
-- ---------------------------------------------------------------------------
-- Deleting the auth user cascades through profiles to friendships, memberships,
-- busy blocks, RSVPs, shares, invites, device tokens and every event you own —
-- so plans you organised are removed for everyone invited. App Store Review
-- Guideline 5.1.1(v) requires this to be possible from inside the app.
--
-- Groups are the exception worth handling first: groups.owner_id cascades too,
-- which would delete a group out from under everyone else in it. A group with
-- other members passes to whoever has been in it longest; a group that's only
-- you goes with the account.
--
-- Not handled here: the avatar file (Storage objects must be removed through the
-- Storage API, which the app does before calling this), and revoking Sign in
-- with Apple tokens (needs the Apple Developer account's key; see
-- docs/backend/auth-setup.md).
create or replace function public.delete_my_account()
returns void language plpgsql volatile security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_group record;
  v_heir uuid;
begin
  if v_uid is null then
    raise exception 'Sign in to delete your account' using errcode = '42501';
  end if;

  for v_group in select g.id from public.groups g where g.owner_id = v_uid loop
    select m.user_id into v_heir
      from public.group_memberships m
     where m.group_id = v_group.id and m.user_id <> v_uid
     order by m.joined_at, m.user_id
     limit 1;
    if v_heir is not null then
      update public.groups set owner_id = v_heir where id = v_group.id;
      update public.group_memberships set role = 'owner'
       where group_id = v_group.id and user_id = v_heir;
    end if;
    v_heir := null;
  end loop;

  -- No foreign key to cascade through.
  delete from private.rate_limit_hits where user_id = v_uid;

  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- ---------------------------------------------------------------------------
-- Tell groups when a plan changes or is deleted
-- ---------------------------------------------------------------------------
-- Shares and RSVPs already broadcast (0006, 0010), and so does moving a plan
-- (0014). Editing or deleting the event row itself didn't, so invitees only
-- noticed on their next poll — and a deleted plan lingered on their calendar
-- until then. Broadcasting on update lets their app refresh at once and drop it
-- from the Plannit calendar on the phone. Hard deletes are covered by the share
-- rows cascading away, which 0006's trigger already announces.
create or replace function private.on_event_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_group uuid;
begin
  for v_group in
    select distinct s.group_id from public.event_shares s
     where s.event_id = new.id and s.group_id is not null
  loop
    perform private.broadcast_group_change(v_group, 'events');
  end loop;
  return new;
end;
$$;

revoke all on function private.on_event_change() from public, anon, authenticated;

drop trigger if exists trg_broadcast_events on public.events;
create trigger trg_broadcast_events
  after update of title, location, start_at, end_at, all_day, recurrence_rule, deleted_at
  on public.events
  for each row execute function private.on_event_change();
