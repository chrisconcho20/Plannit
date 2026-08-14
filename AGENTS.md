# AGENTS.md — orientation for AI agents working on Plannit

Plannit is a **native iOS (SwiftUI) social calendar** whose wedge is
**automatically finding a date that works for everyone**. Full plan and task
backlog: [`docs/ROADMAP.md`](docs/ROADMAP.md). Accepted product/tech decisions:
[`docs/decisions.md`](docs/decisions.md). Build the UI to the design system in
[`design-system/`](design-system) (tokens are the source of truth).

## ⚠️ Read this first: there is no Mac in this environment

The dev machine is Windows with **no Xcode**. You **cannot build or run the iOS
app locally**. Validate and test entirely through cloud services:

- **Compile check** — every push touching `ios/**` runs GitHub Actions
  (`.github/workflows/ios-build.yml`) on a macOS runner. This is your compiler.
- **`gh` CLI is installed and authenticated** (`C:\Program Files\GitHub CLI\gh.exe`,
  account `chrisconcho20`). Use it to read CI results yourself — don't ask the
  user to paste logs. Typical loop after a push:
  ```bash
  GH="/c/Program Files/GitHub CLI/gh.exe"
  RID=$("$GH" run list -R chrisconcho20/Plannit -L 6 --json databaseId,name \
        --jq '[.[] | select(.name=="iOS Build")][0].databaseId')
  "$GH" run watch "$RID" -R chrisconcho20/Plannit --interval 15 >/dev/null 2>&1
  "$GH" run view "$RID" -R chrisconcho20/Plannit --json conclusion --jq .conclusion
  # on failure, get the real errors:
  "$GH" run view "$RID" -R chrisconcho20/Plannit --log-failed 2>&1 \
    | grep -E "error:" | sed -E 's#^[^/]*/Users/runner/work/Plannit/Plannit/##' | sort -u
  ```
- **Run it in a browser (Appetize)** — no Mac, no Apple account needed (unsigned
  simulator builds). Two previews, both **stable URLs**:
  - Demo (sample data): `https://appetize.io/app/e2mqoojyf4ig4quzphi4p52dwi` —
    rebuilds automatically on `ios/**` push.
  - Live (real Supabase, dev email sign-in): `https://appetize.io/app/pf2plhtimqqxqku6kdlwyl7p2y`
    — rebuild with `"$GH" workflow run ios-appetize-live.yml -R chrisconcho20/Plannit`.
  - After a build, the run **Summary** prints the URL; the workflow also echoes
    `Appetize URL: …` in the log.

Native-on-physical-iPhone needs an Apple Developer account + Codemagic
([`ios/CODEMAGIC.md`](ios/CODEMAGIC.md)) — not available yet.

## Demo vs live mode

- `Config.isLiveBackend` is true only when `SUPABASE_URL` + `SUPABASE_ANON_KEY`
  are set in `Info.plist`. **Keep them EMPTY in the repo** (demo default) so the
  demo preview stays clickable. Live creds are injected **only at build time** by
  `ios-appetize-live.yml` from GitHub secrets — never commit them.
- Screens read data from `AppModel`, fed by `DataRepository` (`SampleRepository`
  in demo, `SupabaseRepository` in live). Add live features behind this seam and
  keep demo working.

## Working conventions

- **Commit style:** conventional commits; end messages with the
  `Co-Authored-By: Claude …` trailer. Push to `main` (solo project).
- **Match the design system** — use the Theme tokens (`ios/Plannit/Theme/*`), not
  ad-hoc colors/spacing. Icons map lucide→SF Symbols in `Theme/Icon.swift`.
- **Backend contracts** live in `docs/backend/` (api-contract, sync-contract,
  push-notifications) — implement clients against them.
- The backend client is intentionally **dependency-free** (URLSession) — no SPM
  packages, which keeps CI/Appetize builds simple. Keep it that way unless there's
  a strong reason.
- After any iOS change: push, confirm **iOS Build is green** via `gh`, then (if
  relevant) trigger the live Appetize build and hand the user the URL.

## Where to start
Open [`docs/ROADMAP.md`](docs/ROADMAP.md) → Phase 1 is the live date-finder
(`find-slots`), the highest-value remaining work. Known issues and the full
credentials checklist are in that file too.
