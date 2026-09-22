-- 0026_push_preferences.sql — let a device say which pushes it wants.
--
-- The You tab has carried three switches that controlled nothing. Two of them
-- are notification categories, and honouring them needs the sender to know what
-- it is sending and who wants it. The preference lives on the token rather than
-- on the profile because it describes one device: muting "a date was found" on
-- a phone should not mute it on a tablet the same person signs in on.
--
-- Default true, so devices registered before this migration keep receiving
-- everything, which is what they were told they would.

alter table public.device_tokens
  add column if not exists notify_date_found boolean not null default true,
  add column if not exists notify_invites    boolean not null default true;

-- notify_push gains a category, passed through to send-push, which filters the
-- devices it resolves. Unrecognised or absent categories reach every device:
-- a notification nobody has a switch for is not silently dropped.
create or replace function private.notify_push(
  p_user_ids uuid[], p_title text, p_body text, p_data jsonb, p_collapse text,
  p_category text default null
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
      'category', p_category,
      'notification', jsonb_build_object(
        'title', p_title, 'body', p_body,
        'data', coalesce(p_data, '{}'::jsonb), 'collapseId', p_collapse
      )
    )
  );
end;
$$;

-- The three triggers from 0004, each now naming its category. Bodies are
-- unchanged apart from that argument.
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
    'event-' || new.event_id,
    'invites'
  );
  return new;
end;
$$;

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
      'friend-' || new.requester_id,
      'invites'
    );
  elsif tg_op = 'UPDATE' and new.status = 'accepted' and old.status is distinct from 'accepted' then
    select display_name into v_name from public.profiles where id = new.addressee_id;
    perform private.notify_push(
      array[new.requester_id],
      'Friend request accepted',
      coalesce(nullif(v_name, ''), 'Someone') || ' accepted your friend request',
      jsonb_build_object('userId', new.addressee_id),
      'friend-' || new.addressee_id,
      'invites'
    );
  end if;
  return new;
end;
$$;

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
      'proposal-' || new.id,
      'date_found'
    );
  end if;
  return new;
end;
$$;
