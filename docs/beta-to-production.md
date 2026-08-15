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
| **Email confirmation** | Off (dashboard → Auth → Sign In / Providers → Email) | **On** | Off, anyone can register any address, including someone else's. Blocked on §4: the confirmation link points at `site_url` = `plannit://auth-callback`, a deep link with no web page behind it. Needs a real landing page first. |
| **`auto_friend_everyone`** | `true` | **`false`** — `update public.app_config set value = 'false' where key = 'auto_friend_everyone';` | Every new account is instantly friends with every existing one, so a stranger's first screen lists every user's name. Existing friendships survive the flip. |
| **Test accounts** | 5 × `@plannit.test`, shared password, in your groups | **Delete them** | They're real, sign-in-able accounts auto-friended to everyone. `delete from auth.users where email like '%@plannit.test';` cascades to profiles, memberships and busy blocks. |
| **`seed-test-users.sql`** | Run against the live project | **Never run** | It writes directly into `auth.users`. Point it at a staging project or retire it. |
| **Live Appetize preview** | Public URL, real project | **Retire, or point at staging** | An unauthenticated URL that runs the app against production. Treat it as a credential until then. |
| **`enable_signup`** | `true` | Consider **off** between cohorts | Closes the door behind a known set of testers without affecting existing accounts. |

## 2. Security review follow-ups

From [`security-review.md`](security-review.md) — none blocking a beta, all worth
closing before open sign-up.

- **Narrow the RLS helper signatures.** `are_friends(a, b)`, `is_group_member(group, user)` and friends are `SECURITY DEFINER`, take arbitrary ids and are executable by any authenticated user, so they answer "are these two people friends?" about anyone. The fix is one-argument versions using `auth.uid()` internally, which means rewriting 0002's policies and `find-slots`. Needs a database to test against — don't do it blind.
- **Invite tokens ride in a query string**, so they land in Edge Function logs. Fine at beta scale given 14-day expiry, use caps and revocation; worth a POST exchange if invites ever carry more.
- **`find_profile_by_email` has no rate limit** — it confirms whether an email has an account. Standard, but pair it with sign-up throttling eventually.

## 3. Client build

- **Entitlements:** device testing uses `Plannit-Personal.entitlements` (empty) because a free Apple ID can't sign Sign in with Apple. **Switch `project.yml` back to `Plannit.entitlements`** for TestFlight or the App Store, or Apple sign-in silently won't work.
- **Bundle id:** if you changed `com.plannit.app` for personal-team signing, change it back — it's the App Store identity.
- **`Info.plist` Supabase keys stay empty in the repo.** Live values are injected at build time. The anon key is publishable, but a committed one flips the demo build to live.
- **Keychain fallback:** `Keychain.swift` falls back to `UserDefaults` only when the Keychain returns `errSecMissingEntitlement` — unsigned simulator builds. Any signed build never takes that path, so production is unaffected. Don't "simplify" it away without checking that.

## 4. Not built, and needed before launch

- **A web presence.** Password reset, email confirmation and the invite page's "get the app" fallback all need a real page. Currently `site_url` is a deep link, which is why §1's first row is blocked.
- **Sign in with Apple.** The entitlement exists and `AppModel.signInWithApple()` is written, but no view calls it and the Supabase Apple provider isn't configured. Requires the $99 account. Apple *requires* it if you offer other social logins — worth checking against review guidelines before submitting.
- **Push notifications.** The whole server half is built (`send-push`, 0004's triggers, the APNs signer). Needs the paid account, an APNs key, and the two Vault secrets (`internal_function_secret`, `functions_base_url`) — without them `notify_push()` silently no-ops.
- **Privacy nutrition labels.** Calendar data is sensitive and this app reads it. Be precise: event details never leave the device (decision D-17); only opaque busy ranges are uploaded.
- **Crash reporting** (Sentry, per the proposal) — nothing today.

## 5. Known behaviours to re-check with real users

- **Rate limits.** Nothing throttles sign-up, invite redemption or the date-finder. `find-slots` is now clamped for size, not frequency.
- **Activity feed** has no pagination and tracks "seen" only on-device.
- **A locked plan can't be reopened** — cancel and re-run is the workaround.
- **Group colour is device-local** until `groups` gets a `hue` column.
