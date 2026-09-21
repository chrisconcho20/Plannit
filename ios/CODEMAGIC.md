# Ship Plannit to your iPhone with Codemagic (no Mac required)

Codemagic builds the app on a cloud Mac and uploads it to TestFlight; you install
it from the **TestFlight** app on your iPhone. The build reads the live Supabase
project from the `plannit_release` variable group (step 4), so the app arrives
signed in against real data with real EventKit.

Config lives in [`../codemagic.yaml`](../codemagic.yaml). The steps below are the
one-time setup on your side.

## 1. Apple Developer Program ($99/yr)
Required to sign and distribute. Enrol at developer.apple.com if you haven't
(this is the beta cost noted in docs/cost-analysis.md).

## 2. Register the app (App Store Connect)
1. **Identifiers** (developer.apple.com → Certificates, Identifiers & Profiles):
   create an App ID for **`com.chrisconcho.plannit`** (`com.plannit.app` is
   registered to someone else), and enable **Sign in with Apple** and **Push
   Notifications** on it.
2. **App Store Connect → My Apps → +** → New App:
   - Platform: iOS · Name: Plannit · Bundle ID: `com.chrisconcho.plannit` ·
     SKU: `plannit`.

## 3. App Store Connect API key
App Store Connect → **Users and Access → Integrations → App Store Connect API** →
generate a key with the **App Manager** role. Download the `.p8` and note the
**Key ID** and **Issuer ID** (you can't re-download the key later).

## 4. Codemagic
1. Sign up at codemagic.io and **connect your GitHub** — authorise the
   `chrisconcho20/Plannit` repo. Use a **personal account, not a Team**: the 500
   free macOS build minutes a month are personal-account only.
2. **Integrations → App Store Connect → Add key**: upload the
   `.p8`, Key ID, and Issuer ID. Name it **`CodemagicAppStoreKey`** (must match
   the `integrations.app_store_connect` value in `codemagic.yaml`; change either
   to match).
3. **App settings → Environment variables**: create a group named
   **`plannit_release`** with these variables, each marked **Secure**:
   - `SUPABASE_URL` — `https://<project-ref>.supabase.co`
   - `SUPABASE_ANON_KEY` — Supabase dashboard → Settings → API
   - `SENTRY_DSN` — optional; Sentry → your iOS project → Client Keys (DSN).
     Empty leaves crash reporting off.

   The build writes them into `Info.plist` for that build only. Without the two
   Supabase values the build stops, because an app without them opens in demo
   mode.
4. Open the Plannit app in Codemagic → it detects `codemagic.yaml` → **Start new
   build** on the `ios-testflight` workflow (or just push to `main`).

## 5. Install on your iPhone
1. After the build finishes, the IPA is uploaded to TestFlight (processing takes a
   few minutes).
2. App Store Connect → your app → **TestFlight** → add yourself as an **internal
   tester** (your Apple ID).
3. Install **TestFlight** from the App Store on your iPhone, open it, install
   Plannit. Done — real device, demo data, real calendar.

## Notes
- **Sign in with Apple** also needs the Apple provider configured in Supabase Auth
  — see [`../docs/backend/auth-setup.md`](../docs/backend/auth-setup.md) §6.
- **Demo mode** is what a build without the two Supabase variables falls back to;
  the workflow stops instead, so a misconfigured group can't ship as a demo.
- If signing fails, confirm the App ID `com.chrisconcho.plannit` exists and the
  API key has the App Manager role.
- Build numbers auto-increment from the latest TestFlight build (`agvtool` +
  `VERSIONING_SYSTEM = apple-generic` in `project.yml`).
