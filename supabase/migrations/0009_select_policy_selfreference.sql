-- 0009_select_policy_selfreference.sql — let an insert return the row it just
-- wrote.
--
-- The bug this fixes: creating an event failed with "new row violates
-- row-level security policy for table events", while creating a *group* — a
-- policy of exactly the same shape — worked fine.
--
-- An INSERT that asks for the row back (PostgREST's `Prefer:
-- return=representation`) has the SELECT policy applied to the returned row,
-- not just the INSERT policy's WITH CHECK. So the SELECT policy has to be
-- satisfiable by a row that is, at that instant, not yet visible to anything
-- that goes looking for it.
--
--   events_select was:  can_view_event(id, auth.uid())
--
-- and can_view_event answers by *querying public.events for that id*. Inside
-- the inserting statement that query finds nothing — the function is STABLE, so
-- it reads the statement's snapshot — so it returns false and the whole insert
-- is refused.
--
-- groups_select never had the problem because it leads with
-- `owner_id = auth.uid()`, which reads the new row's own column and needs no
-- lookup at all.
--
-- The fix is the same trick: check ownership directly first, and only fall back
-- to the function for the shared-with-me cases. It's also cheaper — your own
-- events stop paying for a function call on every row.

drop policy if exists events_select on public.events;
create policy events_select on public.events for select to authenticated
  using ( owner_id = auth.uid()
       or public.can_view_event(id, auth.uid()) );

-- Same latent trap, not yet hit only because we insert memberships with
-- `return=minimal`: is_group_member() queries group_memberships, so adding a
-- membership and asking for it back would refuse itself.
drop policy if exists memberships_select on public.group_memberships;
create policy memberships_select on public.group_memberships for select to authenticated
  using ( user_id = auth.uid()
       or public.is_group_member(group_id, auth.uid()) );

-- Every other SELECT policy in the schema is safe: the rest either read a
-- column of the row directly (profiles, friendships, groups, busy_blocks,
-- invites) or call a helper that queries a *different* table, which is already
-- committed by the time the insert runs (event_shares, proposals,
-- proposal_slots, votes).
