-- 0018_provider_display_names.sql — name accounts that arrive from Google or Apple.
--
-- handle_new_user() (0001) fills profiles.display_name from the `display_name`
-- key in raw_user_meta_data, which only the app's email sign-up sends. Google
-- sign-in fills `full_name` and `name` instead, so those accounts started with
-- a blank name and fell back to the part of the email before the @. For an
-- Apple "Hide My Email" address that is a random string, shown to every group
-- the person joins.
--
-- Apple's identity token carries no name at all; the app saves the name Apple
-- hands it on the first sign-in (AppModel.finishSignIn). This only covers what
-- the auth server already knows.
--
-- Same function, same trigger, same SECURITY DEFINER reasoning as 0001: it
-- runs as the auth server inserts the user, before any session exists.

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, timezone)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'display_name'), ''),
      nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
      nullif(trim(new.raw_user_meta_data->>'name'), ''),
      ''
    ),
    coalesce(new.raw_user_meta_data->>'timezone', 'UTC')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- No grant changes: `create or replace` keeps 0001's privileges, and Postgres
-- refuses to call a `returns trigger` function any way but as a trigger.
