-- seed.sql — local development data only. Loaded by `supabase db reset`.
-- Creates three users, one group, and busy blocks spanning the 2026-08-15/16
-- weekend so the find-slots function returns meaningful results.

-- Demo auth users. In local dev we may insert directly into auth.users; the
-- handle_new_user() trigger creates the matching public.profiles rows.
insert into auth.users
  (instance_id, id, aud, role, email, encrypted_password,
   email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-000000000000',
   '11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated',
   'ava@example.com', crypt('password123', gen_salt('bf')),
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}',
   '{"display_name":"Ava","timezone":"America/Los_Angeles"}'),
  ('00000000-0000-0000-0000-000000000000',
   '22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated',
   'ben@example.com', crypt('password123', gen_salt('bf')),
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}',
   '{"display_name":"Ben","timezone":"America/Los_Angeles"}'),
  ('00000000-0000-0000-0000-000000000000',
   '33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated',
   'cat@example.com', crypt('password123', gen_salt('bf')),
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}',
   '{"display_name":"Cat","timezone":"America/Los_Angeles"}');

-- Ava owns a group; the owner membership is added by trigger. Add Ben and Cat.
insert into public.groups (id, name, owner_id)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Weekend Crew',
        '11111111-1111-1111-1111-111111111111');

insert into public.group_memberships (group_id, user_id, role)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'member'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333', 'member');

-- Busy blocks (UTC). Saturday afternoon PT ~= 19:00–02:00 UTC. Ben is busy
-- early Saturday afternoon; Cat is busy Sunday; Ava is wide open — so the best
-- slot should be Saturday late afternoon with all three free.
insert into public.busy_blocks (user_id, start_at, end_at)
values
  -- Ben busy Sat 12:00–14:00 PT (19:00–21:00 UTC)
  ('22222222-2222-2222-2222-222222222222', '2026-08-15T19:00:00Z', '2026-08-15T21:00:00Z'),
  -- Cat busy all Sunday afternoon PT
  ('33333333-3333-3333-3333-333333333333', '2026-08-16T19:00:00Z', '2026-08-17T02:00:00Z');
