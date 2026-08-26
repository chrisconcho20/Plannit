-- 0013_profile_avatars.sql — a face, or at least a colour, on every profile.
--
-- Two ways to be recognisable, because they cost very different things:
--
--   • `avatar_hue`  — one of the app's group hues, behind your initials. Free,
--                     instant, offline, and nothing leaves the phone.
--   • `avatar_url`  — a photo in Storage. Already a column since 0001, never
--                     used; this migration gives it a bucket to point at.
--
-- The colour is deliberately the default path. A photo of your face is personal
-- data that everyone in your groups can fetch, so it's opt-in, replaceable and
-- deletable, and the bucket below is scoped so nobody can write over anyone
-- else's.

alter table public.profiles
  add column if not exists avatar_hue text;

-- Constrained rather than free text: the client maps this onto GroupHue, and an
-- unknown value would silently fall back, which looks like the setting didn't
-- save.
alter table public.profiles
  drop constraint if exists profiles_avatar_hue_valid;
alter table public.profiles
  add constraint profiles_avatar_hue_valid
  check (avatar_hue is null or avatar_hue in ('coral','teal','amber','indigo','rose','sky'));

-- ---------------------------------------------------------------------------
-- Storage for photos
-- ---------------------------------------------------------------------------
-- Public bucket: avatars are shown to everyone in your groups, and a signed URL
-- per member per render is a lot of round trips for a thumbnail. "Public" here
-- means unguessable-but-readable — the path contains a uuid you'd have to
-- already know. Nothing else about you is reachable through it.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152,
        array['image/jpeg','image/png','image/heic','image/webp'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Write access is per-user, keyed on the first path segment being your uid:
-- `avatars/<uid>/avatar.jpg`. This is the whole security model of the bucket,
-- so it's worth stating plainly — without it, any signed-in user could
-- overwrite anyone's face.
drop policy if exists avatars_read   on storage.objects;
drop policy if exists avatars_insert on storage.objects;
drop policy if exists avatars_update on storage.objects;
drop policy if exists avatars_delete on storage.objects;

create policy avatars_read on storage.objects for select
  using ( bucket_id = 'avatars' );

create policy avatars_insert on storage.objects for insert to authenticated
  with check ( bucket_id = 'avatars'
               and (storage.foldername(name))[1] = auth.uid()::text );

create policy avatars_update on storage.objects for update to authenticated
  using ( bucket_id = 'avatars'
          and (storage.foldername(name))[1] = auth.uid()::text )
  with check ( bucket_id = 'avatars'
               and (storage.foldername(name))[1] = auth.uid()::text );

create policy avatars_delete on storage.objects for delete to authenticated
  using ( bucket_id = 'avatars'
          and (storage.foldername(name))[1] = auth.uid()::text );

-- ---------------------------------------------------------------------------
-- Friends carry their avatar too
-- ---------------------------------------------------------------------------
-- `my_friends()` is SECURITY DEFINER (0005) and hand-picks its columns, so a
-- new column on `profiles` doesn't reach the client until this says so.
-- Recreating rather than altering: a `returns table` signature can't be widened
-- in place.
drop function if exists public.my_friends();

create or replace function public.my_friends()
returns table (id uuid, display_name text, avatar_hue text, avatar_url text)
language sql stable security definer set search_path = public as $$
  select p.id, p.display_name, p.avatar_hue, p.avatar_url
    from public.friendships f
    join public.profiles p
      on p.id = case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
   where f.status = 'accepted'
     and (f.requester_id = auth.uid() or f.addressee_id = auth.uid())
   order by p.display_name;
$$;

revoke all on function public.my_friends() from public, anon;
grant execute on function public.my_friends() to authenticated;
