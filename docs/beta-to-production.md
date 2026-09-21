# Beta → production checklist

_Everything deliberately loosened, faked or deferred to make beta testing
possible, and what it has to become before strangers can sign up. Written down
because each item is individually sensible and collectively a security incident._

Nothing here is a bug. Each was a considered trade for a closed test with people
you know. Work top-down: the first section is what actually exposes data.

---

## 1. Access — do these before anyone outside your circle has an account

| Setting | Beta | Production | Why |
|---|---|---|---|
| **Email confirmation** | Off (dashboard → Auth → Sign In / Providers → Email) | **On** | Off, anyone can register any address, including someone else's. No longer blocked on a web page: the app confirms with a 6-digit code. Needs custom SMTP and the code templates first — order in [`backend/auth-setup.md`](backend/auth-setup.md). |
| **`auto_friend_everyone`** | `true` | **`false`** — `update public.app_config set value = 'false' where key = 'auto_friend_everyone';` | Every new account is instantly friends with every existing one, so a stranger's first screen lists every user's name. Existing friendships survive the flip. ✅ Off since 2026-09-15. |
| **Test accounts** | 5 × `@plannit.test`, shared password, in your groups | **Delete them** | They're real, sign-in-able accounts auto-friended to everyone. `delete from auth.users where email like '%@plannit.test';` cascades to profiles, memberships and busy blocks. Checked 2026-09-14: they own no groups or events; deleting removes 24 memberships and their friendships. ✅ Deleted 2026-09-15. |
| **`seed-test-users.sql`** | Run against the live project | **Never run** | ✅ Refuses to run on a project marked `app_config.environment = 'production'` (2026-09-14). |
| **Live Appetize preview** | Public URL, real project | **Retire, or point at staging** | ✅ Build workflow removed 2026-09-14; the uploaded app was deleted on 2026-09-15 and its URL returns 404. |
| **`enable_signup`** | `true` | Consider **off** between cohorts | Closes the door behind a known set of testers without affecting existing accounts. |

## 2. Security review follow-ups

From [`security-review.md`](security-review.md) — none blocking a beta, all worth
closing before open sign-up.

- ✅ **RLS helper signatures narrowed (0022, 2026-09-14).** The two-id helpers that answered about anyone — callable even by `anon` — are dropped or only answer about the caller. See [`security-review.md`](security-review.md) §4.
- **Invite tokens ride in a query string**, so they land in Edge Function logs. Fine at beta scale given 14-day expiry, use caps and revocation; worth a POST exchange if invites ever carry more.
- ✅ **`find_profile_by_handle` is rate limited (0023):** 30 lookups per person per 10 minutes, on top of the 32^6 code space.

## 3. Client build

- ✅ **Entitlements** (2026-09-20): `project.yml` builds with `Plannit.entitlements`, which carries Sign in with Apple. `Plannit-Personal.entitlements` (empty) stays for free-Apple-ID device builds only. Add `aps-environment` to the same file when push is wired.
- **Bundle id** is `com.chrisconcho.plannit` — the App Store identity, since `com.plannit.app` is registered to someone else.
- **`Info.plist` Supabase keys stay empty in the repo.** Live values are injected at build time. The anon key is publishable, but a committed one flips the demo build to live.
- **Keychain fallback:** `Keychain.swift` falls back to `UserDefaults` only when the Keychain returns `errSecMissingEntitlement` — unsigned simulator builds. Any signed build never takes that path, so production is unaffected. Don't "simplify" it away without checking that.

## 4. Not built, and needed before launch

- **A web presence.** The invite page's "get the app" fallback needs a real page. Password reset and email confirmation no longer do: both use codes entered in the app.
- ✅ **Custom SMTP** (2026-09-18): Resend, sending as `no-reply@mail.plannittogether.com` with SPF, DKIM and DMARC in place; both code templates are live and the auth email rate limit is raised. The Resend free plan caps sending at 100 emails a day — see [`scaling.md`](scaling.md) §10 before launch. Setup: [`backend/auth-setup.md`](backend/auth-setup.md) §2.
- **Sign in with Apple and Google.** Both are on the sign-in screen. Apple needs the $99 account, the entitlement switched back (§3) and the provider's Client IDs set; Google needs a Google Cloud OAuth client. Google must not reach the App Store without Apple alongside it (guideline 4.8).
- **Push notifications.** The whole server half is built (`send-push`, 0004's triggers, the APNs signer). Needs the paid account, an APNs key, and the two Vault secrets (`internal_function_secret`, `functions_base_url`) — without them `notify_push()` silently no-ops. The You tab's "A date was found", "Invites & requests" and "Share availability" toggles are placeholders that control nothing; wire them up in the same change (roadmap Phase 4, item 8).
- ✅ **Account deletion** (0025, 2026-09-15): You → Delete account. Groups with other members pass to the longest-standing member. **When Sign in with Apple goes live, also revoke the user's Apple tokens on deletion** — Apple requires it for apps offering Sign in with Apple, and it needs the Apple Developer key ([`backend/auth-setup.md`](backend/auth-setup.md) §6).
- **Invite links can't be listed or revoked in the app**, though RLS already allows the creator or group owner to delete them.
- **Privacy nutrition labels.** Calendar data is sensitive and this app reads it. Be precise: event details never leave the device (decision D-17); only opaque busy ranges are uploaded.
- **Crash reporting** — built (Sentry 9.28.0, `Services/CrashReporting.swift`), off until a DSN exists. To turn on: create a Sentry project (iOS), add `SENTRY_DSN` to Codemagic's `plannit_release` group ([`../ios/CODEMAGIC.md`](../ios/CODEMAGIC.md)). Privacy label: declare **Crash Data**, not linked to the user, not used for tracking — screenshots, view hierarchy, network breadcrumbs and PII are all disabled.

## 5. Known behaviours to re-check with real users

- **Rate limits** (0023): per person, friend lookup 30/10 min, friend requests 30/h, invite creation 30/h, invite redemption 20/h, date searches 60/h — answered as HTTP 429. Sign-up and sign-in rely on Supabase Auth's per-IP defaults (30 per 5 minutes; Authentication → Rate Limits). Watch whether real use trips any of them.
- **Activity feed** has no pagination and tracks "seen" only on-device.
