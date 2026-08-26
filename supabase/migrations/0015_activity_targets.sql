-- 0015_activity_targets.sql — make the feed point somewhere.
--
-- `my_activity()` has always returned a `proposal_id`, which has been null on
-- every row since 0011 retired proposals. So the feed tells you Maya is going
-- to Five-a-side and then dead-ends: the client has no id to open, which is why
-- the rows aren't tappable.
--
-- Swapping the dead column for a live one: `event_id`, filled on the three
-- branches that are about an event. The other two already carry what they need
-- (`group_id` for a join, and a friend request opens the friends screen).
--
-- Dropped and recreated rather than replaced: a `returns table` signature can't
-- have a column renamed in place.

drop function if exists public.my_activity(int);

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

    union all

    -- Someone said they're going. Only "going" — a feed that announces every
    -- no is a feed that makes saying no expensive.
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
       and not exists (select 1 from public.event_shares gs
                        where gs.event_id = s.event_id and gs.group_id is not null)

    union all

    -- Someone wants to be friends.
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
  ) feed
  order by feed.happened_at desc
  limit p_limit;
$$;

revoke all on function public.my_activity(int) from public, anon;
grant execute on function public.my_activity(int) to authenticated;
