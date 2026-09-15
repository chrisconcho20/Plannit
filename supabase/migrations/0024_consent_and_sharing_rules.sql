-- 0024_consent_and_sharing_rules.sql — nobody joins, befriends, adds or shares
-- with someone without the rules saying so.
--
-- A review on 2026-09-15 attempted each of these against the live project as a
-- signed-in user (in a rolled-back transaction) and every one succeeded:
--
--   S1  anyone could insert themselves into any group whose id they knew
--   S2  a group owner could add any user id, then read their free/busy through
--       the date finder
--   S3  a friend request could be inserted already 'accepted', or accepted by
--       the person who sent it
--   S4  an event could be shared onto any user's calendar, or into any group
--   S5  anyone holding the publishable key could list the avatars bucket, whose
--       object names are user ids
--   S6  a soft-deleted event stayed readable to everyone it had been shared with
--
-- Every path the app itself uses stays open: owners add people they already
-- know, requests start pending and are answered by the person asked, shares go
-- to your own groups and connections, and joining a group happens through
-- redeem_invite() and the owner-membership trigger, both SECURITY DEFINER.

-- ---------------------------------------------------------------------------
-- S1, S2 — group memberships
-- ---------------------------------------------------------------------------
drop policy if exists memberships_insert on public.group_memberships;
create policy memberships_insert on public.group_memberships for insert to authenticated
  with check (
    group_id in (select private.my_owned_group_ids())
    and ( user_id = (select auth.uid())
          or user_id in (select private.my_connection_ids()) )
  );

-- ---------------------------------------------------------------------------
-- S3 — friendships
-- ---------------------------------------------------------------------------
drop policy if exists friendships_insert on public.friendships;
create policy friendships_insert on public.friendships for insert to authenticated
  with check ( requester_id = (select auth.uid()) and status = 'pending' );

-- Only the person who was asked can answer. Cancelling your own request is a
-- delete, which friendships_delete still allows either side.
drop policy if exists friendships_update on public.friendships;
create policy friendships_update on public.friendships for update to authenticated
  using ( addressee_id = (select auth.uid()) )
  with check ( addressee_id = (select auth.uid()) );

-- WITH CHECK can't see the old row, so without this the addressee could rewrite
-- requester_id and "accept" a friendship with a third person. Clients only ever
-- change the status.
revoke update on public.friendships from authenticated, anon;
grant update (status) on public.friendships to authenticated;

-- ---------------------------------------------------------------------------
-- S4 — event shares
-- ---------------------------------------------------------------------------
-- A group share needs you in that group; a personal share needs the person to
-- be a friend or co-member. rsvp_to_event() adds your own personal share as
-- definer and is unaffected.
drop policy if exists shares_insert on public.event_shares;
create policy shares_insert on public.event_shares for insert to authenticated
  with check (
    event_id in (select private.my_owned_event_ids())
    and ( (group_id is not null and group_id in (select private.my_group_ids()))
          or (shared_user_id is not null and shared_user_id in (select private.my_connection_ids())) )
  );

-- ---------------------------------------------------------------------------
-- S5 — avatar listing
-- ---------------------------------------------------------------------------
-- The bucket is public, so photo URLs load without any SELECT policy. What the
-- policy added was listing, for anyone. Owners keep reading their own folder,
-- because replacing a photo (upsert) needs SELECT alongside INSERT and UPDATE.
drop policy if exists avatars_read on storage.objects;
create policy avatars_read on storage.objects for select to authenticated
  using ( bucket_id = 'avatars'
          and (storage.foldername(name))[1] = (select auth.uid())::text );

-- ---------------------------------------------------------------------------
-- S6 — deleted events
-- ---------------------------------------------------------------------------
-- The owner still sees their own tombstones, so their other devices can drop
-- the event; everyone else stops seeing it at the moment it's deleted.
drop policy if exists events_select on public.events;
create policy events_select on public.events for select to authenticated
  using ( owner_id = (select auth.uid())
          or (deleted_at is null and id in (select private.my_shared_event_ids())) );
