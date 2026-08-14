# Live backend preview (test real Supabase data in a browser — no Apple account)

This builds a **separate** Appetize preview wired to your real Supabase project.
You sign in with a test email/password (no Sign in with Apple needed), so it works
in the browser simulator. The demo preview stays untouched.

## One-time setup

### 1. Create a test user in Supabase
Supabase dashboard → **Authentication → Users → Add user**:
- Email: e.g. `test@plannit.app`, a password you'll remember.
- Tick **Auto Confirm User** (so no email confirmation is needed).

(Email auth is enabled by default. If not: Authentication → Providers → Email → on.)

### 2. Add repo secrets
The live build injects these at build time (they are **not** committed):
```
gh secret set SUPABASE_URL      -R chrisconcho20/Plannit   # https://<ref>.supabase.co
gh secret set SUPABASE_ANON_KEY -R chrisconcho20/Plannit   # Settings → API → anon key
```
(`APPETIZE_API_TOKEN` is already set.)

### 3. (Optional) Seed some data for the test user
So there's something to see. Supabase → SQL editor, edit the email, run:
```sql
do $$
declare uid uuid; gid uuid;
begin
  select id into uid from auth.users where email = 'test@plannit.app';
  if uid is null then raise notice 'no such user'; return; end if;

  insert into public.groups (name, owner_id) values ('Soccer', uid) returning id into gid;
  -- owner membership is added automatically by the trigger

  insert into public.events (owner_id, title, location, start_at, end_at, source) values
    (uid, 'Five-a-side',    'Hackney Marshes', now() + interval '2 days',  now() + interval '2 days 2 hours',  'plannit'),
    (uid, 'Dinner with Ada','Bermondsey',      now() + interval '3 days',  now() + interval '3 days 1 hour',   'device');

  insert into public.busy_blocks (user_id, start_at, end_at) values
    (uid, now() + interval '1 day', now() + interval '1 day 3 hours');
end $$;
```

## Run it
- Repo → **Actions → iOS Appetize Preview (Live) → Run workflow**, or ask Claude to
  trigger it. When it finishes, the run **Summary** prints the live
  `https://appetize.io/app/…` URL.
- Open it, **sign in** with the test email/password → you're on live Supabase data.

## Notes
- The live URL is separate from the demo one; set the repo variable
  `APPETIZE_LIVE_PUBLIC_KEY` (Claude does this after the first run) to keep it stable.
- Live proposals aren't mapped yet (groups + events are) — that's the next wiring step.
- This is still the cloud **simulator**; native-on-device remains the Codemagic +
  Apple Developer path (`ios/CODEMAGIC.md`) for later.
