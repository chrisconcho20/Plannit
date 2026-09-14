-- 0017_group_hue_activity_bounds.sql — a shared group colour, a bounded feed,
-- and telling the organiser when someone can't make it.
--
-- Two of these touch my_activity() and the third is one column, so they ship
-- together behind one test pass.

-- ---------------------------------------------------------------------------
-- 1. groups.hue
-- ---------------------------------------------------------------------------
-- The colour picker already worked, but the choice was stored in the device's
-- UserDefaults, so everyone else saw the name-derived colour. Same value set as
-- profiles.avatar_hue (0013), constrained for the same reason: an unknown value
-- falls back silently on the client, which reads as "didn't save". Null means
-- "derive it from the name", which is every existing group.
--
-- No policy change: groups_update (0002) already limits writes to the owner,
-- and trg_broadcast_groups (0006) already tells members a group row changed.
alter table public.groups
  add column if not exists hue text;

alter table public.groups
  drop constraint if exists groups_hue_valid;
alter table public.groups
  add constraint groups_hue_valid
  check (hue is null or hue in ('coral','teal','amber','indigo','rose','sky'));

-- ---------------------------------------------------------------------------
-- 2 + 3. my_activity(): bounded in time, and a `declined` branch
-- ---------------------------------------------------------------------------
-- Bounding. `limit` applies after the UNION, so every branch produced all of
-- its history on every call, and the feed refreshes on a timer. Each branch now
-- stops at 90 days — a 50-row feed never reaches further back, so nothing
-- visible changes. The exception is `friend_request`: a pending request is
-- still actionable however old it is, and `status = 'pending'` already keeps
-- that branch small.
--
-- Declines. D-18 kept "not going" out of the feed so that saying no stays
-- cheap, and for group members that still holds. The organiser is different:
-- until now a decline reached them only as the going count dropping. So the
-- new branch is scoped to plans auth.uid() owns, and shown to nobody else.
--
-- Security reasoning is unchanged from 0015 (SECURITY DEFINER, every branch
-- scoped to `mine` or auth.uid() by hand). The return signature is identical,
-- so this is a replace rather than a drop.

create or replace function public.my_activity(p_limit int default 50)
returns table (
  kind        text,
  happened_at timestamptz,
  actor_name  text,
  title       text,
  subtitle    text,
  group_id    uuid,
  event_id    uuid
)
language sql stable security definer set search_path = public as $$
  with mine as (
    select m.group_id, m.joined_at
      from public.group_memberships m
     where m.user_id = auth.uid()
  ),
  minePlans as (
    select e.id, e.title, e.owner_id
      from public.events e
     where e.deleted_at is null
       and ( e.owner_id = auth.uid()
             or exists (select 1 from public.event_rsvps r
                         where r.event_id = e.id and r.user_id = auth.uid()
                           and r.response = 'going') )
  )
  select feed.kind, feed.happened_at, feed.actor_name, feed.title, feed.subtitle,
         feed.group_id, feed.event_id
  from (
    -- Someone offered your group a date.
    select 'invited'::text                                  as kind,
           s.created_at                                     as happened_at,
           coalesce(nullif(a.display_name, ''), 'Someone')  as actor_name,
           coalesce(nullif(e.title, ''), 'a plan')          as title,
           g.name                                           as subtitle,
           s.group_id                                       as group_id,
           e.id                                             as event_id
      from public.event_shares s
      join mine            on mine.group_id = s.group_id
      join public.events e on e.id = s.event_id
      join public.groups g on g.id = s.group_id
     left join public.profiles a on a.id = e.owner_id
     where s.group_id is not null
       and e.deleted_at is null
       and e.owner_id <> auth.uid()
       and s.created_at > now() - interval '90 days'

    union all

    -- Someone said they're going to a plan you made or are going to.
    select 'rsvp',
           r.updated_at,
           coalesce(nullif(a.display_name, ''), 'Someone'),
           coalesce(nullif(p.title, ''), 'a plan'),
           null::text,
           null::uuid,
           p.id
      from public.event_rsvps r
      join minePlans p on p.id = r.event_id
     left join public.profiles a on a.id = r.user_id
     where r.user_id <> auth.uid()
       and r.response = 'going'
       and r.updated_at > now() - interval '90 days'

    union all

    -- Someone can't make a plan you made. Owner only — see the note above.
    select 'declined',
           r.updated_at,
           coalesce(nullif(a.display_name, ''), 'Someone'),
           coalesce(nullif(e.title, ''), 'a plan'),
           null::text,
           null::uuid,
           e.id
      from public.event_rsvps r
      join public.events e on e.id = r.event_id
     left join public.profiles a on a.id = r.user_id
     where e.owner_id = auth.uid()
       and e.deleted_at is null
       and r.user_id <> auth.uid()
       and r.response = 'not_going'
       and r.updated_at > now() - interval '90 days'

    union all

    -- An event shared directly with you, person to person.
    select 'event_shared',
           s.created_at,
           coalesce(nullif(a.display_name, ''), 'Someone'),
           coalesce(nullif(e.title, ''), 'an event'),
           null::text,
           null::uuid,
           e.id
      from public.event_shares s
      join public.events e on e.id = s.event_id
     left join public.profiles a on a.id = e.owner_id
     where s.shared_user_id = auth.uid()
       and e.deleted_at is null
       and e.owner_id <> auth.uid()
       and s.created_at > now() - interval '90 days'
       and not exists (select 1 from public.event_shares gs
                        where gs.event_id = s.event_id and gs.group_id is not null)

    union all

    -- Someone wants to be friends. Not time-bounded — see the note above.
    select 'friend_request',
           f.created_at,
           coalesce(nullif(a.display_name, ''), 'Someone'),
           coalesce(nullif(a.display_name, ''), 'Someone'),
           null::text,
           null::uuid,
           null::uuid
      from public.friendships f
      left join public.profiles a on a.id = f.requester_id
     where f.addressee_id = auth.uid()
       and f.status = 'pending'

    union all

    -- Someone joined a group you're in.
    select 'joined_group',
           gm.joined_at,
           coalesce(nullif(a.display_name, ''), 'Someone'),
           g.name,
           null::text,
           gm.group_id,
           null::uuid
      from public.group_memberships gm
      join mine            on mine.group_id = gm.group_id
      join public.groups g on g.id = gm.group_id
      left join public.profiles a on a.id = gm.user_id
     where gm.user_id <> auth.uid()
       and gm.joined_at >= mine.joined_at
       and gm.joined_at > now() - interval '90 days'
  ) feed
  order by feed.happened_at desc
  limit p_limit;
$$;

revoke all on function public.my_activity(int) from public, anon;
grant execute on function public.my_activity(int) to authenticated;
