# Supabase Setup Runbook

Steps to connect this repo to a hosted Supabase project and deploy the backend.
The hosted path needs **no Docker and no Deno** — those are only for running
Supabase locally. Node is enough (`npx supabase`).

## 0. Prerequisites

- **Supabase CLI** — use `npx supabase@latest <cmd>` (no install needed), or
  install via `scoop install supabase` / download from GitHub releases.
- **Docker Desktop** — only if you want to run the stack locally
  (`supabase start`, local `db reset`, `functions serve`). Skip for cloud deploy.
- **Deno** — only to run the scheduler unit tests locally. Optional.
- **Apple Developer Program ($99/yr)** — required for Sign in with Apple *and*
  APNs push (see steps 5–6).

## 1. Collect from the Supabase dashboard

| Value | Where |
|---|---|
| Project ref | Settings → General (also in the URL) |
| Database password | set when you created the project |
| Project URL + `anon` key | Settings → API |
| `service_role` key | Settings → API (**secret** — never commit/paste) |

## 2. Link the repo to the project

```bash
# Interactive (opens a browser) — run this yourself. In the Claude Code prompt
# you can type:  ! npx supabase login
npx supabase login

npx supabase link --project-ref <PROJECT_REF>
```

## 3. Apply the database migrations

```bash
npx supabase db push          # runs migrations/0001, 0002, 0003 on the hosted DB
```

⚠️ **Do not run `seed.sql` against production** — it inserts fake auth users for
local dev only. `db push` does not run it; a *local* `db reset` does. Leave prod clean.

Verify in the dashboard: Table Editor should show `profiles`, `groups`,
`events`, `event_shares`, `busy_blocks`, `proposals`, `device_tokens`, etc., all
with RLS enabled.

## 4. Deploy the Edge Functions

```bash
npx supabase functions deploy find-slots
npx supabase functions deploy send-push
```

## 5. Set function secrets

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` are injected
automatically — **do not set them**. You set:

```bash
# Internal secret shared between find-slots -> send-push. Generate a fresh one:
#   node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
npx supabase secrets set INTERNAL_FUNCTION_SECRET=<random-hex>

# APNs (from your Apple Developer account, step 6)
npx supabase secrets set APNS_KEY_ID=<key-id> APNS_TEAM_ID=<team-id> \
  APNS_BUNDLE_ID=<app.bundle.id> APNS_ENV=sandbox
npx supabase secrets set APNS_PRIVATE_KEY="$(cat AuthKey_XXXXXXXX.p8)"
```

Set these **yourself** — don't paste the `.p8` or `service_role` key into chat.

## 6. Apple Developer setup (auth + push)

Needs the $99/yr program.

**Sign in with Apple**
- App ID with "Sign in with Apple" capability.
- A **Services ID** → this is your `APPLE_CLIENT_ID`.
- A **Sign in with Apple key** → used to generate `APPLE_SECRET`.
- In Supabase: Auth → Providers → **Apple** → enable, paste client id + secret.
- Redirect / deep link: `plannit://auth-callback` (already in `config.toml`).

**APNs (push)**
- Create an **APNs Auth Key (.p8)** in Certificates, Identifiers & Profiles.
  This gives you the key file + `APNS_KEY_ID`.
- `APNS_TEAM_ID` = your Apple Developer Team ID.
- `APNS_BUNDLE_ID` = the app's bundle id.
- Use `APNS_ENV=sandbox` for TestFlight/dev builds, `production` for App Store.

## 7. Smoke test

```bash
# Should return 401 (no JWT) — proves the function is deployed and reachable.
curl -i -X POST "https://<PROJECT_REF>.functions.supabase.co/find-slots"
```

Full end-to-end (a real proposal) needs an authenticated user + some
`busy_blocks`, which arrives with the iOS app.

## Who does what

- **You:** `supabase login` (interactive), dashboard values, secrets, Apple
  Developer setup. These need your account/credentials.
- **Claude:** can prepare exact commands from your non-secret **project ref**,
  add the remaining push triggers, and debug anything `db push` /
  `functions deploy` reports.
