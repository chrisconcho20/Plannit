# Auth setup — Apple, Google and email

_2026-09-14. How sign-in is built, and the dashboard work that turns each method
on for the hosted project. The app code for all three methods ships in the same
build; each one starts working when its section below is done._

## How it works

| Method | Client | Server grant |
|---|---|---|
| **Sign in with Apple** | `SignInWithAppleButton` → identity token + nonce (`Services/AppleSignIn.swift`) | `POST /auth/v1/token?grant_type=id_token` |
| **Google** | Supabase's OAuth page in `ASWebAuthenticationSession`, PKCE (`Services/WebSignIn.swift`) | `GET /auth/v1/authorize` → `plannit://auth-callback?code=` → `POST /auth/v1/token?grant_type=pkce` |
| **Email + password** | `LiveSignInView` in `Features/Onboarding/Onboarding.swift` | `/signup`, `/token?grant_type=password`, `/verify`, `/resend`, `/recover`, `PUT /user` |

**Email accounts confirm once, with a code.** Creating an account emails a
6-digit code that is entered in the app (`POST /verify`, `type: email`). Later
sign-ins need only the password. Signing in to an unconfirmed account sends a
fresh code and opens the code screen. A forgotten password is reset the same
way (`type: recovery`), followed by a new password entered twice.

Codes rather than links, because `site_url` is `plannit://auth-callback`: there
is no web page for an emailed link to open.

**Google does not use the Google SDK.** The native path requires the
GoogleSignIn package; the backend client is dependency-free by convention
(`AGENTS.md`), so Google runs through Supabase's hosted OAuth page instead. The
redirect carries a one-time code that is useless without the PKCE verifier,
which never leaves the phone.

**Names.** Email sign-up sends `display_name` in the user metadata. Google
accounts are named from `full_name` / `name` by `handle_new_user()` (migration
0018). Apple sends a name only on the first authorisation, and never in the
identity token, so the app saves it to the profile at that moment.

---

## Order of operations for the hosted project

Each step is safe on its own except **step 4**, which breaks sign-up if done
before steps 2 and 3.

### 1. Migration 0018

```bash
npx supabase db push
```

### 2. Custom SMTP (required before confirmation)

Supabase's built-in email sender **delivers only to members of the project's
Supabase team**, at 2 emails per hour across the whole project, with no delivery
guarantee ([Supabase docs](https://supabase.com/docs/guides/auth/auth-smtp)).
Anyone else who signs up would never receive a code.

Using [Resend](https://resend.com/docs/send-with-supabase-smtp) as the example
(Postmark, AWS SES, SendGrid, ZeptoMail and Brevo are also supported):

1. Create a Resend account and **verify a domain you own** (DNS records at your
   registrar). Resend won't send to arbitrary recipients from an unverified
   domain.
2. Create an API key in Resend. It is a secret: it goes into the Supabase
   dashboard and nowhere else — not this repo, not `.env.example`.
3. Supabase dashboard → **Authentication → Emails → SMTP Settings** → enable:
   - Host `smtp.resend.com`, port `465`, username `resend`, password = the API key
   - Sender email e.g. `no-reply@<your-domain>`, sender name `Plannit`
4. **Authentication → Rate Limits**: custom SMTP starts at 30 emails per hour.
   Raise it to suit the number of testers.

### 3. Email templates

**Authentication → Emails → Templates**. Paste the files from
`supabase/templates/`:

| Template | Subject | Body |
|---|---|---|
| Confirm signup | `Your Plannit code` | `confirmation.html` |
| Reset password | `Your Plannit password reset code` | `recovery.html` |

Both print `{{ .Token }}`. The default templates only contain a link, which
would send people to a deep link instead of giving them a code.

Supabase restricts template editing on Free-plan projects that use the built-in
sender (changelog, 2026-06-03), which is another reason step 2 comes first.

### 4. Turn on email confirmation

**Authentication → Sign In / Providers → Email → Confirm email: on.** Leave
**Email OTP Length** at 6.

Existing accounts are unaffected: they are already confirmed. Only accounts
created from now on need a code, once.

Do this only when testers have a build that includes the code screen (commit
`feat(auth): Apple, Google and email sign-in with emailed codes` or later). An
older build tells a new user to look for a confirmation link that never arrives.

### 5. Google

1. [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services →
   **OAuth consent screen**: app name `Plannit`, support email, scopes `email`,
   `profile`, `openid`.
2. **Credentials → Create OAuth client ID → Web application.** Authorised
   redirect URI: `https://<project-ref>.supabase.co/auth/v1/callback`.
3. Supabase dashboard → **Authentication → Sign In / Providers → Google**:
   enable, paste the Web client ID and client secret (the secret stays in the
   dashboard).
4. **Authentication → URL Configuration → Redirect URLs**: make sure
   `plannit://auth-callback` is listed.

Until this is done, "Continue with Google" opens a Supabase error page and the
app shows "Google sign-in didn't go through."

### 6. Apple

Needs the Apple Developer Program membership.

1. Certificates, Identifiers & Profiles → the app's **App ID** → enable **Sign in
   with Apple**. Leave server-to-server notification endpoints blank.
2. `ios/project.yml`: set `CODE_SIGN_ENTITLEMENTS` back to
   `Plannit/App/Plannit.entitlements` and the bundle id back to the App Store
   one (see [`../beta-to-production.md`](../beta-to-production.md) §3).
3. Supabase dashboard → **Authentication → Sign In / Providers → Apple**: enable,
   and add the bundle id under **Client IDs**. A native-only setup needs no
   Services ID and no secret key
   ([Supabase docs](https://supabase.com/docs/guides/auth/social-login/auth-apple)).

Builds without the entitlement — Appetize, and free-Apple-ID device builds —
show the Apple button, and tapping it reports that Sign in with Apple isn't
available in this build.

---

## Known gaps

- **Google button branding.** Google's guidelines expect the Google "G" mark on
  the button; it is text-only today. Add the official asset before App Store
  review.
- **The Google sheet names `supabase.co`.** iOS asks "Plannit wants to use
  supabase.co to sign in" because that is where the OAuth page lives. A Supabase
  custom domain changes it.
- **App Store guideline 4.8.** Offering Google requires an equivalent
  privacy-preserving login; Sign in with Apple is that option, so Google should
  not ship to the App Store without step 6.
- **A reset code signs the device in before the new password is saved.** If
  the app is killed between the two steps, the next launch opens the app with
  the old password still set. The person has already proved they own the email.
