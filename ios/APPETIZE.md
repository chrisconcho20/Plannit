# Run Plannit in a browser — no Mac, no Apple Developer account

Appetize.io runs an unsigned iOS **Simulator** build in your browser (Windows
laptop or phone). Our CI (`.github/workflows/ios-appetize.yml`) builds the `.app`
and uploads it automatically. You just open a URL.

Why this works: simulator builds need **no code signing and no Apple Developer
account** — only the free Appetize account below.

## One-time setup (≈3 min)

1. **Create a free Appetize account** at https://appetize.io and confirm email.
2. **Get your API token** — Appetize dashboard → account/settings → **API token**
   (create one if needed). Copy it.
3. **Add it as a GitHub secret** so CI can upload. Either:
   - CLI: `gh secret set APPETIZE_API_TOKEN -R chrisconcho20/Plannit` (paste the
     token when prompted), or
   - Web: repo → Settings → Secrets and variables → Actions → **New repository
     secret** → name `APPETIZE_API_TOKEN`.

## Get a preview

- Push any change under `ios/**`, or trigger it manually: repo → Actions →
  **iOS Appetize Preview** → **Run workflow**.
- When it finishes, open the run's **Summary** — it prints the
  **`https://appetize.io/app/<publicKey>`** URL. Open that on your laptop or your
  phone's browser and use the app (demo mode, real UI, tappable).

## Keep the URL stable (optional)

By default each upload creates a new app (new URL) and free accounts allow ~5.
To always update the same app (one stable URL):

- After the first run, copy the printed `publicKey` and set it as a repo
  **variable**: `gh variable set APPETIZE_PUBLIC_KEY -R chrisconcho20/Plannit`
  (value = the publicKey). Subsequent builds update that app in place.

## Limits & notes

- Free tier ≈ **15 minutes of streaming per day** and up to 5 apps — plenty for
  iterating; it only counts time you're actively using the browser app, not build
  time.
- This is a **simulator in the cloud**, not your physical iPhone hardware. For a
  truly native install on your device you'll eventually want the Apple Developer
  account + Codemagic path (`ios/CODEMAGIC.md`) — but that's not needed to test
  and keep building now.
- Instant, zero-build option for **design/flow** iteration: open
  `design-system/ui_kits/plannit-ios/index.html` in any browser (the designer's
  clickable prototype).
