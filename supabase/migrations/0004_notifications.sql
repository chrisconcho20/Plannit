-- 0004_notifications.sql — server-side push triggers.
--
-- Direct client writes (sharing an event, sending a friend request, finalizing a
-- proposal) can't be trusted to send their own notifications, so we fire pushes
-- from the database. Each trigger calls the internal send-push Edge Function via
-- pg_net (async — never blocks the write).
--
-- Config comes from Vault (set once; see docs/backend/setup-runbook.md):
--   internal_function_secret  — must match the send-push INTERNAL_FUNCTION_SECRET
--   functions_base_url        — https://<PROJECT_REF>.supabase.co/functions/v1
-- If either is missing, notify_push() no-ops, so writes always succeed.

create extension if not exists pg_net;
create schema if not exists private;

-- ---------------------------------------------------------------------------
-- Fire-and-forget push to a set of users. Async via pg_net; safe if unconfigured.
-- ---------------------------------------------------------------------------
create or replace function private.notify_push(
  p_user_ids uuid[], p_title text, p_body text, p_data jsonb, p_collapse text
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_secret text;
  v_base   text;
begin
  if p_user_ids is null or array_length(p_user_ids, 1) is null then
    return;
  end if;

  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'internal_function_secret';
  select decrypted_secret into v_base   from vault.decrypted_secrets where name = 'functions_base_url';
  if v_secret is null or v_base is null then
    return;  -- notifications not configured yet; skip silently
  end if;

  perform net.http_post(
    url     := v_base || '/send-push',
    headers := jsonb_build_object('content-type', 'application/json', 'x-internal-secret', v_secret),
    body    := jsonb_build_object(
      'userIds', to_jsonb(p_user_ids),
      'notification', jsonb_build_object(
        'title', p_title, 'body', p_body,
        'data', coalesce(p_data, '{}'::jsonb), 'collapseId', p_collapse
      )
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Event shared -> notify the group (minus the owner) or the single target user.
-- ---------------------------------------------------------------------------
create or replace function private.on_event_share()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_title      text;
  v_owner      uuid;
  v_recipients uuid[];
begin
  select title, owner_id into v_title, v_owner from public.events where id = new.event_id;

  if new.group_id is not null then
    select array_agg(user_id) into v_recipients
    from public.group_memberships
    where group_id = new.group_id and user_id <> v_owner;
  else
    v_recipients := array[new.shared_user_id];
  end if;

  perform private.notify_push(
    v_recipients,
    'New shared event',
    coalesce(nullif(v_title, ''), 'An event') || ' was shared with you',
    jsonb_build_object('eventId', new.event_id),
    'event-' || new.event_id
  );
  return new;
end;
$$;
create trigger trg_event_share_push after insert on public.event_shares
  for each row execute function private.on_event_share();

-- ---------------------------------------------------------------------------
-- Friend request created -> notify addressee; accepted -> notify requester.
-- ---------------------------------------------------------------------------
create or replace function private.on_friendship()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if tg_op = 'INSERT' and new.status = 'pending' then
    select display_name into v_name from public.profiles where id = new.requester_id;
    perform private.notify_push(
      array[new.addressee_id],
      'Friend request',
      coalesce(nullif(v_name, ''), 'Someone') || ' sent you a friend request',
      jsonb_build_object('userId', new.requester_id),
      'friend-' || new.requester_id
    );
  elsif tg_op = 'UPDATE' and new.status = 'accepted' and old.status is distinct from 'accepted' then
    select display_name into v_name from public.profiles where id = new.addressee_id;
    perform private.notify_push(
      array[new.requester_id],
      'Friend request accepted',
      coalesce(nullif(v_name, ''), 'Someone') || ' accepted your friend request',
      jsonb_build_object('userId', new.addressee_id),
      'friend-' || new.addressee_id
    );
  end if;
  return new;
end;
$$;
create trigger trg_friendship_push after insert or update on public.friendships
  for each row execute function private.on_friendship();

-- ---------------------------------------------------------------------------
-- Proposal finalized -> notify all group members the date is locked in.
-- ---------------------------------------------------------------------------
create or replace function private.on_proposal_finalized()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_recipients uuid[];
begin
  if new.status = 'finalized' and old.status is distinct from 'finalized' then
    select array_agg(user_id) into v_recipients
    from public.group_memberships where group_id = new.group_id;

    perform private.notify_push(
      v_recipients,
      'Date locked in',
      coalesce(nullif(new.title, ''), 'Your plan') || ' is confirmed',
      jsonb_build_object('proposalId', new.id, 'groupId', new.group_id),
      'proposal-' || new.id
    );
  end if;
  return new;
end;
$$;
create trigger trg_proposal_finalized_push after update on public.proposals
  for each row execute function private.on_proposal_finalized();
