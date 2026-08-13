-- 0001_init.sql — Plannit core schema
-- Mirrors the data model in docs/technical-proposal.md.

create extension if not exists "pgcrypto";  -- gen_random_uuid(), crypt()

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type friendship_status as enum ('pending', 'accepted', 'blocked');
create type group_role        as enum ('owner', 'admin', 'member');
create type event_source      as enum ('plannit', 'device');
create type proposal_status   as enum ('open', 'finalized', 'cancelled');
create type vote_response     as enum ('yes', 'no', 'maybe');

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- profiles (1:1 with auth.users)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  avatar_url   text,
  timezone     text not null default 'UTC',   -- IANA tz; drives "weekend afternoon" evaluation
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create trigger trg_profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();

-- Auto-create a profile row whenever an auth user is created.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, timezone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', ''),
    coalesce(new.raw_user_meta_data->>'timezone', 'UTC')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- friendships (bidirectional, deduped by canonical pair)
-- ---------------------------------------------------------------------------
create table public.friendships (
  id           uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status       friendship_status not null default 'pending',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint no_self_friend check (requester_id <> addressee_id)
);
create unique index uq_friendship_pair on public.friendships
  (least(requester_id, addressee_id), greatest(requester_id, addressee_id));
create index idx_friendship_addressee on public.friendships(addressee_id);
create trigger trg_friendships_updated before update on public.friendships
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- groups + memberships
-- ---------------------------------------------------------------------------
create table public.groups (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  owner_id   uuid not null references public.profiles(id) on delete cascade,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_groups_owner on public.groups(owner_id);
create trigger trg_groups_updated before update on public.groups
  for each row execute function public.set_updated_at();

create table public.group_memberships (
  group_id  uuid not null references public.groups(id) on delete cascade,
  user_id   uuid not null references public.profiles(id) on delete cascade,
  role      group_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index idx_membership_user on public.group_memberships(user_id);

-- The owner is always a member of their own group.
create or replace function public.add_owner_membership()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.group_memberships (group_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict do nothing;
  return new;
end;
$$;
create trigger trg_group_owner_membership after insert on public.groups
  for each row execute function public.add_owner_membership();

-- ---------------------------------------------------------------------------
-- events
-- ---------------------------------------------------------------------------
create table public.events (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null references public.profiles(id) on delete cascade,
  title           text not null,
  notes           text,
  location        text,
  start_at        timestamptz not null,
  end_at          timestamptz not null,
  all_day         boolean not null default false,
  timezone        text not null default 'UTC',
  source          event_source not null default 'plannit',
  external_cal_id text,          -- EventKit calendarItemExternalIdentifier (device-origin)
  recurrence_rule text,          -- RFC 5545 RRULE
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,   -- tombstone for two-way sync
  constraint event_time_valid check (end_at >= start_at)
);
create index idx_events_owner_start on public.events(owner_id, start_at);
-- One Plannit row per device event, keyed on the stable external identifier.
create unique index uq_events_owner_extcal on public.events(owner_id, external_cal_id)
  where external_cal_id is not null;
create trigger trg_events_updated before update on public.events
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- event_shares — selective visibility (share to a group OR a single user)
-- ---------------------------------------------------------------------------
create table public.event_shares (
  id             uuid primary key default gen_random_uuid(),
  event_id       uuid not null references public.events(id) on delete cascade,
  group_id       uuid references public.groups(id) on delete cascade,
  shared_user_id uuid references public.profiles(id) on delete cascade,
  created_at     timestamptz not null default now(),
  constraint share_target_exactly_one check (
    (group_id is not null and shared_user_id is null) or
    (group_id is null and shared_user_id is not null)
  )
);
create unique index uq_share_group on public.event_shares(event_id, group_id)
  where group_id is not null;
create unique index uq_share_user on public.event_shares(event_id, shared_user_id)
  where shared_user_id is not null;
create index idx_share_group on public.event_shares(group_id);
create index idx_share_user  on public.event_shares(shared_user_id);

-- ---------------------------------------------------------------------------
-- busy_blocks — privacy-safe availability (no titles ever leave the phone)
-- ---------------------------------------------------------------------------
create table public.busy_blocks (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  start_at   timestamptz not null,
  end_at     timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint busy_time_valid check (end_at > start_at)
);
create index idx_busy_user_start on public.busy_blocks(user_id, start_at);
create trigger trg_busy_updated before update on public.busy_blocks
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- proposals / slots / votes — the scheduler
-- ---------------------------------------------------------------------------
create table public.proposals (
  id                uuid primary key default gen_random_uuid(),
  group_id          uuid not null references public.groups(id) on delete cascade,
  created_by        uuid not null references public.profiles(id) on delete cascade,
  title             text not null default '',
  constraints       jsonb not null default '{}'::jsonb,  -- Constraints (see scheduler.ts)
  window_start      timestamptz not null,
  window_end        timestamptz not null,
  status            proposal_status not null default 'open',
  finalized_slot_id uuid,   -- FK added after proposal_slots exists
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index idx_proposals_group on public.proposals(group_id);
create trigger trg_proposals_updated before update on public.proposals
  for each row execute function public.set_updated_at();

create table public.proposal_slots (
  id                 uuid primary key default gen_random_uuid(),
  proposal_id        uuid not null references public.proposals(id) on delete cascade,
  start_at           timestamptz not null,
  end_at             timestamptz not null,
  score              int not null default 0,           -- number of available members
  available_user_ids uuid[] not null default '{}',     -- aggregate only; never per-event detail
  created_at         timestamptz not null default now()
);
create index idx_slots_proposal on public.proposal_slots(proposal_id);

alter table public.proposals
  add constraint fk_finalized_slot foreign key (finalized_slot_id)
  references public.proposal_slots(id) on delete set null;

create table public.votes (
  id          uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.proposals(id) on delete cascade,
  slot_id     uuid not null references public.proposal_slots(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  response    vote_response not null default 'yes',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (slot_id, user_id)
);
create index idx_votes_proposal on public.votes(proposal_id);
create trigger trg_votes_updated before update on public.votes
  for each row execute function public.set_updated_at();
