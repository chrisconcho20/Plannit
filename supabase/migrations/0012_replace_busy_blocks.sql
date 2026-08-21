-- 0012_replace_busy_blocks.sql — upload availability without a window where
-- you look free.
--
-- The client used to do this in two calls: delete every future busy block, then
-- insert the new set. Three things can happen between them — the insert fails
-- (offline, expired token, oversized payload), the app is killed, or the user
-- backgrounds it at the wrong moment. All three leave the row set **empty**,
-- and an empty busy set doesn't read as "we don't know", it reads as
-- "free at all times". The scheduler then confidently offers a group a slot in
-- the middle of someone's workday, and nothing anywhere reports an error.
--
-- Failures should point toward "we couldn't check" rather than "everyone's
-- free", so the replace has to be atomic. One statement, one transaction: if
-- the insert half fails the delete half rolls back with it and the previous
-- blocks stand — stale by a few minutes, which is the failure we want.
--
-- Definer because `user_id` must come from auth.uid() rather than from the
-- payload. The old client-side insert set user_id itself; RLS checked it, but
-- there is no reason to accept the field at all.

create or replace function public.replace_busy_blocks(
  p_blocks jsonb,
  p_from   timestamptz default now()
)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_count integer;
begin
  if v_uid is null then
    raise exception 'Sign in to sync availability' using errcode = '42501';
  end if;

  -- Only the future is replaced. Past blocks are nobody's business — the
  -- scheduler never reads them — but deleting history on every sync would be a
  -- surprising side effect of "upload my availability".
  delete from public.busy_blocks
   where user_id = v_uid
     and end_at >= p_from;

  insert into public.busy_blocks (user_id, start_at, end_at)
  select v_uid,
         (b->>'start_at')::timestamptz,
         (b->>'end_at')::timestamptz
    from jsonb_array_elements(coalesce(p_blocks, '[]'::jsonb)) as b
   -- The table's check constraint would reject these anyway; filtering here
   -- means one bad row can't take the whole upload down with it.
   where (b->>'end_at')::timestamptz > (b->>'start_at')::timestamptz;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.replace_busy_blocks(jsonb, timestamptz) from public, anon;
grant execute on function public.replace_busy_blocks(jsonb, timestamptz) to authenticated;
