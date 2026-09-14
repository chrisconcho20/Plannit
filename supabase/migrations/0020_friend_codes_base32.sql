-- 0020_friend_codes_base32.sql — friend codes can contain letters.
--
-- 0019 made codes six digits: 1,000,000 possible codes, and a known username
-- could be matched by trying at most that many. This widens the alphabet to
-- Crockford's base32 — 0–9 and A–Z without I, L, O and U, the characters people
-- misread from a screenshot or mishear aloud — for 32^6 = 1,073,741,824 codes.
--
-- Codes already assigned are all digits, which are valid base32, so they stay
-- exactly as they are: a friend code never changes (0019's trigger). Only codes
-- assigned from now on can contain letters.
--
-- Stored uppercase. Lookup ignores case and reads O as 0 and I/L as 1, so a code
-- typed from a misread still finds the right person.

create or replace function private.unused_friend_code()
returns text language plpgsql volatile security definer set search_path = public as $$
declare
  v_alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  v_code text;
begin
  for attempt in 1..100 loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * 32)::int, 1);
    end loop;
    if not exists (select 1 from public.profiles where friend_code = v_code) then
      return v_code;
    end if;
  end loop;
  raise exception 'No unused friend code found after 100 attempts';
end;
$$;

revoke all on function private.unused_friend_code() from public, anon, authenticated;

alter table public.profiles
  drop constraint if exists profiles_friend_code_format;
alter table public.profiles
  add constraint profiles_friend_code_format
  check (friend_code ~ '^[0-9ABCDEFGHJKMNPQRSTVWXYZ]{6}$');

-- Same signature as 0019, so a replace. The app normalises the code too; doing
-- it here keeps any other caller from missing a match on a lowercase letter.
create or replace function public.find_profile_by_handle(p_username text, p_code text)
returns table (id uuid, display_name text, avatar_hue text, avatar_url text)
language sql stable security definer set search_path = public as $$
  select p.id, p.display_name, p.avatar_hue, p.avatar_url
    from public.profiles p
   where p.friend_code = translate(upper(replace(p_code, ' ', '')), 'OIL', '011')
     and lower(p.display_name) = lower(btrim(p_username))
     and p.id <> auth.uid()
   limit 1;
$$;

revoke all on function public.find_profile_by_handle(text, text) from public, anon;
grant execute on function public.find_profile_by_handle(text, text) to authenticated;
