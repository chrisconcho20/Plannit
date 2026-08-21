-- 0011_activity_rsvp.sql — the feed, after group plans stopped being proposals.
--
-- 0008 built my_activity() around the slot-voting flow: a plan was a row in
-- `proposals`, participating meant a row in `votes`, and the plan ended when
-- someone set `finalized_slot_id`. Nothing writes those tables any more
-- (decision D-12, revised) — a group plan is now an event shared with a group,
-- and participating is a row in `event_rsvps`. Those three branches would keep
-- returning older rows forever and nothing newer, which is worse than an empty
-- feed: it looks like the app stopped working.
--
-- So: plan_created / vote / plan_locked are replaced by
--
--   invited  — someone offered your group a date (event + share, in one row)
--   rsvp     — someone answered a plan that is yours or that you're going to
--
-- Everything else is 0008 unchanged. The security reasoning there still holds
-- and is worth re-reading before touching this: SECURITY DEFINER bypasses RLS,
-- so every branch scopes itself to `mine` or to auth.uid() by hand.
--
-- The two new branches join `event_shares` → `mine` (the groups you're in) and
-- `event_rsvps` → an event you can already see, so neither widens what you can
-- read. `idx_share_group` and the event_rsvps primary key cover both.

create or replace function public.my_activity(p_limit int default 50)
returns table (
  kind        text,
  happened_at timestamptz,
  actor_name  text,
  title       text,
  subtitle    text,
  group_id    uuid,
  proposal_id uuid      -- kept: the client's DTO still reads it, always null now
)
language sql stable security definer set search_path = public as $$
  with mine as (
    select m.group_id, m.joined_at
      from public.group_memberships m
     where m.user_id = auth.uid()
  ),
  -- Group plans you can speak for: yours, or ones you said yes to. Used to
  -- scope the rsvp branch — you should not get a running commentary on a plan
  -- you declined.
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
         feed.group_id, feed.proposal_id
  from (
    -- Nothing in this feed is ever about you: every branch excludes the actor
    -- being auth.uid(). `subtitle` is uniformly *where* it happened.

    -- Someone offered your group a date. This is the invitation — the one row
    -- that should pull you into the app.
    select 'invited'::text                                  as kind,
           s.created_at                                     as happened_at,
           coalesce(nullif(a.display_name, ''), 'Someone')  as actor_name,
           coalesce(nullif(e.title, ''), 'a plan')          as title,
           g.name                                           as subtitle,
           s.group_id                                       as group_id,
           null::uuid                                       as proposal_id
      from public.event_shares s
      join mine            on mine.group_id = s.group_id
      join public.events e on e.id = s.event_id
      join public.groups g on g.id = s.group_id
     left join public.profiles a on a.id = e.owner_id
     where s.group_id is not null
       and e.deleted_at is null
       and e.owner_id <> auth.uid()

    union all

    -- Someone answered. Only "going" — a feed that announces every no is a
    -- feed that makes saying no feel expensive.
    select 'rsvp',
           r.updated_at,
           coalesce(nullif(a.display_name, ''), 'Someone'),
           coalesce(nullif(p.title, ''), 'a plan'),
           null::text,
           null::uuid,
           null::uuid
      from public.event_rsvps r
      join minePlans p on p.id = r.event_id
     left join public.profiles a on a.id = r.user_id
     where r.user_id <> auth.uid()
       and r.response = 'going'

    union all

    -- An event shared directly with you, person to person. The group case is
    -- the `invited` branch above; this one has no group to name.
    select 'event_shared',
           s.created_at,
           coalesce(nullif(a.display_name, ''), 'Someone'),
           coalesce(nullif(e.title, ''), 'an event'),
           null::text,
           null::uuid,
           null::uuid
      from public.event_shares s
      join public.events e on e.id = s.event_id
     left join public.profiles a on a.id = e.owner_id
     where s.shared_user_id = auth.uid()
       and e.deleted_at is null
       and e.owner_id <> auth.uid()
       -- Accepting a group plan inserts a personal share naming you (0010).
       -- Without this, saying yes would report itself back as "Maya shared
       -- Five-a-side with you" a second after the invitation.
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

    -- Someone joined a group you're in — including via an invite link (0007).
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
