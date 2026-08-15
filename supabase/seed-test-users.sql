-- seed-test-users.sql — real people to test against, in a HOSTED project.
--
-- `seed.sql` is for `supabase db reset` (local only). This one is written to be
-- pasted into the Supabase SQL editor of the live project: it is idempotent
-- (safe to run again), it attaches everything to YOUR account, and it re-creates
-- the busy blocks relative to today so the date-finder always has fresh data.
--
-- ⚠️  These are REAL, SIGN-IN-ABLE ACCOUNTS on your live project, and they are
--     auto-friended to everyone and added to every group you own. Anyone who
--     knows an email and the password below can sign in and see whatever those
--     accounts can see — your groups, your shared events, your plans. Set
--     `test_password` to something of your own, and rotate it before the live
--     Appetize preview link goes anywhere public. See docs/security-review.md.
--
-- It creates:
--   • 5 test users (auth.users + profiles), password = `test_password` below
--   • membership in every group you own (or a new "Test Crew" if you own none)
--   • busy blocks designed to exercise both scheduler paths (see below)
--   • a few events on your own calendar for the next fortnight
--
-- Expected results afterwards, searching afternoons for 2h with all 6 members:
--   • Saturdays  → the first all-free date is the THIRD Saturday from now
--                  (Maya/Theo/Ada are busy before that) → "everyone free"
--   • Sundays    → Jo is busy every Sunday for six months → no all-free date,
--                  so you get the best-turnout fallback (5 of 6)
--
-- Change the email on the next line if you sign in as someone else.

do $$
declare
  owner_email   text := 'johnnysilverhands@gmail.com';
  -- CHANGE THIS. It's a shared password for accounts on a live database, and
  -- this file is in the repo — anything left here is effectively published.
  test_password text := 'change-me-before-sharing';
  owner_tz      text := 'America/Los_Angeles';
  owner_uid    uuid;
  test_ids     uuid[];
  gid          uuid;
  u            record;
  sat          date;   -- the next Saturday
  sun          date;   -- the next Sunday
  i            int;
begin
  -- pgcrypto lives in `extensions` on hosted projects; reach crypt()/gen_salt().
  perform set_config('search_path', 'public, extensions', true);

  select id into owner_uid from auth.users where lower(email) = lower(owner_email);
  if owner_uid is null then
    raise exception
      'No auth user with email %. Sign in once in the app (or add the user under Auth → Users), then re-run.',
      owner_email;
  end if;

  -- Your own profile needs a display name, or you show up nameless in groups.
  -- Insert rather than update: an account created before the profiles trigger
  -- existed has no row at all, and an UPDATE would silently do nothing.
  insert into public.profiles (id, display_name, timezone)
  values (owner_uid, initcap(split_part(owner_email, '@', 1)), owner_tz)
  on conflict (id) do update
    set display_name = case when coalesce(profiles.display_name, '') = ''
                            then excluded.display_name else profiles.display_name end,
        timezone     = coalesce(nullif(profiles.timezone, ''), excluded.timezone);

  -- ---------------------------------------------------------------- users ---
  for u in
    select * from (values
      ('11111111-aaaa-4aaa-8aaa-111111111111'::uuid, 'maya@plannit.test',  'Maya Ellis'),
      ('22222222-aaaa-4aaa-8aaa-222222222222'::uuid, 'theo@plannit.test',  'Theo Sand'),
      ('33333333-aaaa-4aaa-8aaa-333333333333'::uuid, 'ada@plannit.test',   'Ada Kim'),
      ('44444444-aaaa-4aaa-8aaa-444444444444'::uuid, 'sam@plannit.test',   'Sam Roe'),
      ('55555555-aaaa-4aaa-8aaa-555555555555'::uuid, 'jo@plannit.test',    'Jo Vane')
    ) as t(id, email, name)
  loop
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change, email_change_token_new
    ) values (
      '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated',
      u.email, crypt(test_password, gen_salt('bf')), now(),
      now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('display_name', u.name, 'timezone', owner_tz),
      '', '', '', ''
    ) on conflict (id) do update
        -- Re-running rotates the password, so changing test_password above and
        -- re-running is the way to revoke a leaked one.
        set encrypted_password = excluded.encrypted_password;

    -- GoTrue wants an identity row for email sign-in; the column layout has
    -- changed across versions, so only write it when this project has provider_id.
    if exists (
      select 1 from information_schema.columns
       where table_schema = 'auth' and table_name = 'identities'
         and column_name = 'provider_id'
    ) then
      execute format(
        'insert into auth.identities
           (user_id, provider, provider_id, identity_data, last_sign_in_at, created_at, updated_at)
         values (%L, %L, %L, %L::jsonb, now(), now(), now())
         on conflict do nothing',
        u.id, 'email', u.id::text,
        jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true)::text
      );
    end if;

    -- handle_new_user() creates the profile on insert; this also repairs a row
    -- that already existed with a blank name.
    insert into public.profiles (id, display_name, timezone)
    values (u.id, u.name, owner_tz)
    on conflict (id) do update
      set display_name = excluded.display_name,
          timezone     = excluded.timezone;

    test_ids := array_append(test_ids, u.id);
  end loop;

  -- --------------------------------------------------------------- groups ---
  if not exists (select 1 from public.groups where owner_id = owner_uid) then
    insert into public.groups (name, owner_id) values ('Test Crew', owner_uid);
  end if;

  -- Put the test users in every group you own, so whichever you pick works.
  for gid in select id from public.groups where owner_id = owner_uid loop
    insert into public.group_memberships (group_id, user_id, role)
    select gid, unnest(test_ids), 'member'
    on conflict (group_id, user_id) do nothing;
  end loop;

  -- ---------------------------------------------------------- busy blocks ---
  -- Whole UTC days, so a member reads as busy whatever timezone the app runs in.
  delete from public.busy_blocks where user_id = any(test_ids);

  sat := current_date + ((6 - extract(dow from current_date)::int + 7) % 7);
  if sat = current_date then sat := sat + 7; end if;
  sun := sat + 1;

  -- Maya: the next two Saturdays.  Theo: the next two Saturdays + this Sunday.
  -- Ada: the next Saturday only.   Sam: always free.
  insert into public.busy_blocks (user_id, start_at, end_at) values
    (test_ids[1], sat,                   sat + 1),
    (test_ids[1], sat + 7,               sat + 8),
    (test_ids[2], sat,                   sat + 1),
    (test_ids[2], sat + 7,               sat + 8),
    (test_ids[2], sun,                   sun + 1),
    (test_ids[3], sat,                   sat + 1);

  -- Jo: every Sunday for six months — so a Sunday-only search can never find a
  -- date the whole group can make, and has to fall back to the best turnout.
  for i in 0..25 loop
    insert into public.busy_blocks (user_id, start_at, end_at)
    values (test_ids[5], sun + (i * 7), sun + (i * 7) + 1);
  end loop;

  -- --------------------------------------------------------------- events ---
  -- A handful of your own events so the calendar has something real to draw.
  -- Fixed ids keep re-runs from piling up duplicates.
  insert into public.events (id, owner_id, title, location, start_at, end_at, timezone, source)
  values
    ('e0000001-0000-4000-8000-000000000001', owner_uid, 'Five-a-side', 'Hackney Marshes',
     ((current_date + 2) + time '14:00') at time zone owner_tz,
     ((current_date + 2) + time '16:00') at time zone owner_tz, owner_tz, 'plannit'),
    ('e0000002-0000-4000-8000-000000000002', owner_uid, 'Dinner with Ada', 'Bermondsey',
     ((current_date + 2) + time '19:30') at time zone owner_tz,
     ((current_date + 2) + time '21:30') at time zone owner_tz, owner_tz, 'plannit'),
    ('e0000003-0000-4000-8000-000000000003', owner_uid, 'Mum''s birthday lunch', 'Hers',
     ((current_date + 3) + time '13:00') at time zone owner_tz,
     ((current_date + 3) + time '15:00') at time zone owner_tz, owner_tz, 'plannit'),
    ('e0000004-0000-4000-8000-000000000004', owner_uid, 'Film night', 'The flat',
     ((current_date + 6) + time '20:00') at time zone owner_tz,
     ((current_date + 6) + time '22:30') at time zone owner_tz, owner_tz, 'plannit'),
    ('e0000005-0000-4000-8000-000000000005', owner_uid, 'Dentist', null,
     ((current_date + 9) + time '09:15') at time zone owner_tz,
     ((current_date + 9) + time '10:00') at time zone owner_tz, owner_tz, 'plannit')
  on conflict (id) do update
    set title    = excluded.title,
        location = excluded.location,
        start_at = excluded.start_at,
        end_at   = excluded.end_at;

  raise notice 'Seeded 5 test users into % group(s) owned by %.',
    (select count(*) from public.groups where owner_id = owner_uid), owner_email;
end $$;

-- Check what you ended up with:
--   select g.name, p.display_name
--     from public.groups g
--     join public.group_memberships m on m.group_id = g.id
--     join public.profiles p on p.id = m.user_id
--    order by g.name, p.display_name;
