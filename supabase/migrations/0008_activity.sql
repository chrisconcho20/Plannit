-- 0008_activity.sql — one feed of what happened while you were away.
--
-- Six things can happen to you in Plannit and they live in six tables. The
-- client could fetch all six and merge them, but that is six round trips whose
-- results are from six different instants — scroll far enough and the interleave
-- is visibly wrong. One query, one snapshot, one sort.
--
-- SECURITY DEFINER for a subtler reason than "it's easier". Half of these rows
-- are about someone RLS deliberately hides from you: `profiles` shows you
-- yourself, your friends and your group co-members, so a plain join would render
-- a pending friend request as "Someone wants to be friends" — the one field you
-- need to judge it is the one RLS removes. Same shape as `my_friend_requests()`
-- in 0005. Definer bypasses that, so this function has to do the scoping itself:
-- every branch below is joined to `mine` (the groups you belong to) or keyed on
-- auth.uid() directly. There is no blanket read anywhere in here.
--
-- No new indexes: every join below already has one from 0001
-- (idx_membership_user, idx_proposals_group, idx_votes_proposal,
-- idx_share_group, idx_friendship_addressee).

create or replace function public.my_activity(p_limit int default 50)
returns table (
  kind        text,
  happened_at timestamptz,
  actor_name  text,
  title       text,
  subtitle    text,
  group_id    uuid,
  proposal_id uuid
)
language sql stable security definer set search_path = public as $$
  with mine as (
    -- joined_at comes along so branches can ask "was I even here yet?".
    select m.group_id, m.joined_at
      from public.group_memberships m
     where m.user_id = auth.uid()
  )
  -- Everything is qualified, here and in every branch: `group_id`, `title` and
  -- friends are also this function's OUT parameters, and an unqualified
  -- reference to one is an ambiguity error rather than a wrong answer.
  select feed.kind, feed.happened_at, feed.actor_name, feed.title, feed.subtitle,
         feed.group_id, feed.proposal_id
  from (
    -- Nothing in this feed is ever about you. Every branch excludes the actor
    -- being auth.uid(), because a list that opens with "you voted yes" is a list
    -- nobody reads. `subtitle` is uniformly *where* it happened.

    -- Someone started a plan in one of your groups.
    select 'plan_created'::text                             as kind,
           pr.created_at                                    as happened_at,
           coalesce(nullif(a.display_name, ''), 'Someone')  as actor_name,
           coalesce(nullif(pr.title, ''), 'a plan')         as title,
           g.name                                           as subtitle,
           pr.group_id                                      as group_id,
           pr.id                                            as proposal_id
      from public.proposals pr
      join mine            on mine.group_id = pr.group_id
      join public.groups g on g.id = pr.group_id
      left join public.profiles a on a.id = pr.created_by
     where pr.created_by <> auth.uid()

    union all

    -- Someone voted. The vote row has no title of its own, so it borrows the
    -- proposal's — "Ollie voted on Weekend hang" is the only useful phrasing.
    select 'vote',
           v.created_at,
           coalesce(nullif(a.display_name, ''), 'Someone'),
           coalesce(nullif(pr.title, ''), 'a plan'),
           g.name,
           pr.group_id,
           pr.id
      from public.votes v
      join public.proposals pr on pr.id = v.proposal_id
      join mine               on mine.group_id = pr.group_id
      join public.groups g    on g.id = pr.group_id
      left join public.profiles a on a.id = v.user_id
     where v.user_id <> auth.uid()

    union all

    -- A date got locked in. There is no `finalized_by` column, so the actor is
    -- attributed to whoever created the proposal.
    --
    -- This is the one branch that does NOT exclude your own plans. The rule
    -- elsewhere is "don't tell people what they just did", but the organiser is
    -- precisely who wants to know a date landed, and the client words this one
    -- impersonally ("Five-a-side is locked in") rather than naming an actor.
    select 'plan_locked',
           pr.updated_at,
           coalesce(nullif(a.display_name, ''), 'Someone'),
           coalesce(nullif(pr.title, ''), 'a plan'),
           g.name,
           pr.group_id,
           pr.id
      from public.proposals pr
      join mine            on mine.group_id = pr.group_id
      join public.groups g on g.id = pr.group_id
      left join public.profiles a on a.id = pr.created_by
     where pr.finalized_slot_id is not null

    union all

    -- An event was shared into one of your groups. Showing the event's real
    -- title is fine precisely here: the share is the act that made it visible to
    -- you, so this reveals nothing the events tab wouldn't. Only the owner can
    -- create a share (shares_insert in 0002), so the owner is the actor.
    select 'event_shared',
           s.created_at,
           coalesce(nullif(a.display_name, ''), 'Someone'),
           coalesce(nullif(e.title, ''), 'an event'),
           g.name,
           s.group_id,
           null::uuid
      from public.event_shares s
      join mine            on mine.group_id = s.group_id
      join public.events e on e.id = s.event_id
      join public.groups g on g.id = s.group_id
      left join public.profiles a on a.id = e.owner_id
     where s.group_id is not null
       and e.deleted_at is null
       and e.owner_id <> auth.uid()

    union all

    -- Someone wants to be friends. The subject of a friend request is the
    -- person, so actor and title are the same name; there is no group.
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

    -- Someone joined a group you're in — including via an invite link (0007),
    -- which is how most of these will arrive.
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
       -- Only joins you were around for. Without this, a new member's first
       -- feed is every historical join in every group they were just added to.
       and gm.joined_at >= mine.joined_at
  ) feed
  order by feed.happened_at desc
  limit p_limit;
$$;

-- Same reasoning as 0007: a new function is EXECUTE-to-PUBLIC until revoked,
-- and this one runs as its owner.
revoke all on function public.my_activity(int) from public, anon;
grant execute on function public.my_activity(int) to authenticated;
