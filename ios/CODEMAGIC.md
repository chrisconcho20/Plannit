# Ship Plannit to your iPhone with Codemagic (no Mac required)

Codemagic builds the app on a cloud Mac and uploads it to TestFlight; you install
it from the **TestFlight** app on your iPhone. The app runs in **demo mode** (no
backend needed), so this gets Plannit onto your phone with real EventKit and the
full UI immediately.

Config lives in [`../codemagic.yaml`](../codemagic.yaml). The steps below are the
one-time setup on your side.

## 1. Apple Developer Program ($99/yr)
Required to sign and distribute. Enrol at developer.apple.com if you haven't
(this is the beta cost noted in docs/cost-analysis.md).

## 2. Register the app (App Store Connect)
1. **Identifiers** (developer.apple.com → Certificates, Identifiers & Profiles):
   create an App ID for **`com.plannit.app`**, and enable the **Sign in with
   Apple** capability on it.
2. **App Store Connect → My Apps → +** → New App:
   - Platform: iOS · Name: Plannit · Bundle ID: `com.plannit.app` · SKU: `plannit`.

## 3. App Store Connect API key
App Store Connect → **Users and Access → Integrations → App Store Connect API** →
generate a key with the **App Manager** role. Download the `.p8` and note the
**Key ID** and **Issuer ID** (you can't re-download the key later).

## 4. Codemagic
1. Sign up at codemagic.io (free tier) and **connect your GitHub** — authorise the
   `chrisconcho20/Plannit` repo.
2. **Team settings → Integrations → App Store Connect → Add key**: upload the
   `.p8`, Key ID, and Issuer ID. Name it **`CodemagicAppStoreKey`** (must match
   the `integrations.app_store_connect` value in `codemagic.yaml`; change either
   to match).
3. Open the Plannit app in Codemagic → it detects `codemagic.yaml` → **Start new
   build** on the `ios-testflight` workflow (or just push to `main`).

## 5. Install on your iPhone
1. After the build finishes, the IPA is uploaded to TestFlight (processing takes a
   few minutes).
2. App Store Connect → your app → **TestFlight** → add yourself as an **internal
   tester** (your Apple ID).
3. Install **TestFlight** from the App Store on your iPhone, open it, install
   Plannit. Done — real device, demo data, real calendar.

## Notes
- **Demo mode** needs no Supabase or Apple-auth config — great for first install.
- To test the **live backend** later, add `SUPABASE_URL` / `SUPABASE_ANON_KEY` to
  `Plannit/App/Info.plist` and configure the Apple provider in Supabase Auth
  (see ../docs/backend/setup-runbook.md), then rebuild.
- If signing fails, confirm the App ID `com.plannit.app` exists and the API key
  has the App Manager role.
- Build numbers auto-increment from the latest TestFlight build (`agvtool` +
  `VERSIONING_SYSTEM = apple-generic` in `project.yml`).
