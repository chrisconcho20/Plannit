-- 0002_rls.sql — Row-Level Security: the per-group visibility pillar, enforced in the DB.
--
-- Authorization helpers are SECURITY DEFINER so they bypass RLS when checking
-- membership. This is deliberate: a policy on group_memberships that queried
-- group_memberships directly would recurse infinitely. Routing the check
-- through a definer function is the standard Supabase fix.

-- ---------------------------------------------------------------------------
-- Authorization helpers
-- ---------------------------------------------------------------------------
create or replace function public.is_group_member(p_group uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.group_memberships m
    where m.group_id = p_group and m.user_id = p_user
  );
$$;

create or replace function public.is_group_owner(p_group uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.groups g where g.id = p_group and g.owner_id = p_user
  );
$$;

create or replace function public.are_friends(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ( (f.requester_id = p_a and f.addressee_id = p_b)
         or (f.requester_id = p_b and f.addressee_id = p_a) )
  );
$$;

create or replace function public.shares_group(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.group_memberships ma
    join public.group_memberships mb on ma.group_id = mb.group_id
    where ma.user_id = p_a and mb.user_id = p_b
  );
$$;

create or replace function public.is_event_owner(p_event uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.events e where e.id = p_event and e.owner_id = p_user
  );
$$;

create or replace function public.can_view_event(p_event uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select
    exists (select 1 from public.events e where e.id = p_event and e.owner_id = p_user)
    or exists (
      select 1 from public.event_shares s
      where s.event_id = p_event
        and ( s.shared_user_id = p_user
           or (s.group_id is not null and public.is_group_member(s.group_id, p_user)) )
    );
$$;

create or replace function public.is_proposal_group_member(p_proposal uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.proposals pr
    join public.group_memberships m on m.group_id = pr.group_id
    where pr.id = p_proposal and m.user_id = p_user
  );
$$;

-- ---------------------------------------------------------------------------
-- Enable RLS
-- ---------------------------------------------------------------------------
alter table public.profiles          enable row level security;
alter table public.friendships       enable row level security;
alter table public.groups            enable row level security;
alter table public.group_memberships enable row level security;
alter table public.events            enable row level security;
alter table public.event_shares      enable row level security;
alter table public.busy_blocks       enable row level security;
alter table public.proposals         enable row level security;
alter table public.proposal_slots    enable row level security;
alter table public.votes             enable row level security;

-- ---------------------------------------------------------------------------
-- profiles — visible to self, friends, and group co-members only
-- ---------------------------------------------------------------------------
create policy profiles_select on public.profiles for select to authenticated
  using ( id = auth.uid()
       or public.are_friends(auth.uid(), id)
       or public.shares_group(auth.uid(), id) );
create policy profiles_insert on public.profiles for insert to authenticated
  with check ( id = auth.uid() );
create policy profiles_update on public.profiles for update to authenticated
  using ( id = auth.uid() ) with check ( id = auth.uid() );

-- ---------------------------------------------------------------------------
-- friendships — only the two parties can see or act on a row
-- ---------------------------------------------------------------------------
create policy friendships_select on public.friendships for select to authenticated
  using ( requester_id = auth.uid() or addressee_id = auth.uid() );
create policy friendships_insert on public.friendships for insert to authenticated
  with check ( requester_id = auth.uid() );
create policy friendships_update on public.friendships for update to authenticated
  using ( requester_id = auth.uid() or addressee_id = auth.uid() )
  with check ( requester_id = auth.uid() or addressee_id = auth.uid() );
create policy friendships_delete on public.friendships for delete to authenticated
  using ( requester_id = auth.uid() or addressee_id = auth.uid() );

-- ---------------------------------------------------------------------------
-- groups
-- ---------------------------------------------------------------------------
create policy groups_select on public.groups for select to authenticated
  using ( owner_id = auth.uid() or public.is_group_member(id, auth.uid()) );
create policy groups_insert on public.groups for insert to authenticated
  with check ( owner_id = auth.uid() );
create policy groups_update on public.groups for update to authenticated
  using ( owner_id = auth.uid() ) with check ( owner_id = auth.uid() );
create policy groups_delete on public.groups for delete to authenticated
  using ( owner_id = auth.uid() );

-- ---------------------------------------------------------------------------
-- group_memberships
-- ---------------------------------------------------------------------------
create policy memberships_select on public.group_memberships for select to authenticated
  using ( public.is_group_member(group_id, auth.uid()) );
create policy memberships_insert on public.group_memberships for insert to authenticated
  with check ( public.is_group_owner(group_id, auth.uid()) or user_id = auth.uid() );
create policy memberships_update on public.group_memberships for update to authenticated
  using ( public.is_group_owner(group_id, auth.uid()) )
  with check ( public.is_group_owner(group_id, auth.uid()) );
create policy memberships_delete on public.group_memberships for delete to authenticated
  using ( public.is_group_owner(group_id, auth.uid()) or user_id = auth.uid() );

-- ---------------------------------------------------------------------------
-- events — owner always; others only via an EventShare they're a target of
-- ---------------------------------------------------------------------------
create policy events_select on public.events for select to authenticated
  using ( public.can_view_event(id, auth.uid()) );
create policy events_insert on public.events for insert to authenticated
  with check ( owner_id = auth.uid() );
create policy events_update on public.events for update to authenticated
  using ( owner_id = auth.uid() ) with check ( owner_id = auth.uid() );
create policy events_delete on public.events for delete to authenticated
  using ( owner_id = auth.uid() );

-- ---------------------------------------------------------------------------
-- event_shares — only the event owner shares; targets can see the share
-- ---------------------------------------------------------------------------
create policy shares_select on public.event_shares for select to authenticated
  using ( public.is_event_owner(event_id, auth.uid())
       or shared_user_id = auth.uid()
       or (group_id is not null and public.is_group_member(group_id, auth.uid())) );
create policy shares_insert on public.event_shares for insert to authenticated
  with check ( public.is_event_owner(event_id, auth.uid()) );
create policy shares_delete on public.event_shares for delete to authenticated
  using ( public.is_event_owner(event_id, auth.uid()) );

-- ---------------------------------------------------------------------------
-- busy_blocks — strictly private. Others' availability is only ever exposed
-- as the aggregate proposal_slots.available_user_ids, computed server-side.
-- ---------------------------------------------------------------------------
create policy busy_all on public.busy_blocks for all to authenticated
  using ( user_id = auth.uid() ) with check ( user_id = auth.uid() );

-- ---------------------------------------------------------------------------
-- proposals / slots / votes — scoped to the proposal's group
-- ---------------------------------------------------------------------------
create policy proposals_select on public.proposals for select to authenticated
  using ( public.is_group_member(group_id, auth.uid()) );
create policy proposals_insert on public.proposals for insert to authenticated
  with check ( created_by = auth.uid() and public.is_group_member(group_id, auth.uid()) );
create policy proposals_update on public.proposals for update to authenticated
  using ( created_by = auth.uid() or public.is_group_owner(group_id, auth.uid()) )
  with check ( created_by = auth.uid() or public.is_group_owner(group_id, auth.uid()) );
create policy proposals_delete on public.proposals for delete to authenticated
  using ( created_by = auth.uid() or public.is_group_owner(group_id, auth.uid()) );

create policy slots_select on public.proposal_slots for select to authenticated
  using ( public.is_proposal_group_member(proposal_id, auth.uid()) );
create policy slots_insert on public.proposal_slots for insert to authenticated
  with check ( public.is_proposal_group_member(proposal_id, auth.uid()) );

create policy votes_select on public.votes for select to authenticated
  using ( public.is_proposal_group_member(proposal_id, auth.uid()) );
create policy votes_insert on public.votes for insert to authenticated
  with check ( user_id = auth.uid() and public.is_proposal_group_member(proposal_id, auth.uid()) );
create policy votes_update on public.votes for update to authenticated
  using ( user_id = auth.uid() ) with check ( user_id = auth.uid() );
create policy votes_delete on public.votes for delete to authenticated
  using ( user_id = auth.uid() );

-- ---------------------------------------------------------------------------
-- Grants (RLS still applies on top of these)
-- ---------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on all functions in schema public to authenticated;
