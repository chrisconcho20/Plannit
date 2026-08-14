# Plannit — Roadmap & Finalization Plan

_Last updated 2026-08-14. Audience: a future Claude agent (or dev) resuming this
project. Read [`../AGENTS.md`](../AGENTS.md) first for how to build/test without a
Mac, then this for what's left._

Product recap: a native iOS social calendar with (1) two-way device-calendar
sync, (2) per-group event visibility, and (3) the wedge — **automatically finding
a date that works for everyone** from a plain-language constraint. See
[`market-research.md`](market-research.md), [`technical-proposal.md`](technical-proposal.md),
and the accepted [`decisions.md`](decisions.md) (D-01…D-15).

---

## 1. Where things stand ✅

**Docs & decisions** — research, proposal, cost analysis, decision log (all
Accepted), backend API/sync/push contracts, Supabase + Codemagic + Appetize setup
runbooks.

**Backend (Supabase)** — schema + RLS + device tokens + notification triggers
(`supabase/migrations/0001–0004`), the `find-slots` scheduler Edge Function
(validated) and internal `send-push` function. Project is live; the founder ran
link/db push/functions deploy and set secrets. **Not yet done:** `db push` for
`0004` + the two Vault secrets (see §6), and the Apple auth provider.

**Design system** — `design-system/` (tokens, components, iOS ui_kit, app icon).
The SwiftUI app is built to it.

**iOS app (`ios/`, SwiftUI)** — full theme (tokens → Swift), component library,
all screens (onboarding, calendar, groups, plans + the date-finder flow, you),
**demo mode** on sample data, **real EventKit** read + busy-block upload, a
dependency-free `SupabaseClient` (URLSession), **Sign in with Apple** + **dev
email sign-in**, a `DataRepository` seam (sample vs Supabase), and **live groups:
members via embedded query + create-group persistence**.

**Testing without a Mac** — GitHub Actions macOS CI compiles every push; **Appetize**
runs it in a browser: demo preview + live preview (both stable URLs). Codemagic →
TestFlight config exists for real-device testing once there's an Apple Developer
account. See §6 for URLs/creds.

---

## 2. Roadmap (phased, most valuable first)

### Phase 1 — Finish the core live loop (the product's reason to exist)
1. ~~**Live date-finder (`find-slots`)**~~ ✅ **done (2026-08-14).** `Services/SlotFinder.swift`
   builds the `SlotConstraintsDTO` (days → `allowedWeekdays`, time-of-day →
   `dayStart/EndMinutes`, duration, a 4-week window from the next whole hour,
   device timezone, majority quorum) and maps `FoundSlotDTO` → `PSlot`.
   `NewPlanSheet` previews with `persist:false` and only persists the proposal on
   **Send to group to vote**, with loading / error / no-results states.
   _Follow-ups:_ slot avatars still show the first N group members rather than the
   real `availableUserIds` (needs member ids on `PGroup`); the quorum is a
   hard-coded majority with no UI.
2. **Live proposals + voting** — `SupabaseRepository.fetchProposals` (embed
   `proposal_slots`, group, `votes`), render in `PlansScreen`/`PlanDetailView`;
   wire vote insert and **Lock in** → set `proposals.finalized_slot_id` + status,
   and create the winning `event`. Files: `Services/DataRepository.swift`,
   `Features/Plans/PlansScreen.swift`.
3. **Event sharing to groups (live)** — `ShareSheet` currently demo; insert
   `event_shares` rows. Files: `Features/Calendar/CalendarScreen.swift`.

### Phase 2 — Real calendar, real dates
4. **Move off the fixed Aug-2026 sample month** — `MonthGrid`/`CalendarScreen`
   should use the current month and real event dates; derive `marks` from events.
5. **Full two-way sync** per [`backend/sync-contract.md`](backend/sync-contract.md):
   dedicated "Plannit" `EKCalendar`, write Plannit-origin events to the device,
   `calendarItemExternalIdentifier` mapping, deltas + tombstones, `BGAppRefreshTask`.
   Today we only *read* device events + upload busy blocks. Files:
   `Services/CalendarService.swift`, new sync engine.

### Phase 3 — Social graph
6. **Friends** — friend requests / accept (tables exist: `friendships`), a
   people search, and pending-requests UI. Prereq for member-adding and
   share-to-user.
7. **Group management** — add members (needs friends), leave/rename, and **hue
   persistence** (needs a `hue` column or mapping table — currently derived from
   name; see known issues).

### Phase 4 — Notifications
8. **APNs client** — request permission, register the device token into
   `device_tokens` on launch, handle taps → deep-link (`proposalId`/`groupId`).
   Server side already exists (`send-push` + triggers). Contract:
   [`backend/push-notifications.md`](backend/push-notifications.md). Requires the
   Apple Developer account + APNs key.

### Phase 5 — Robustness & finalization
9. **Session persistence** — `SupabaseClient` holds the token in memory only; add
   **Keychain** storage + refresh-token handling (auto-refresh on 401). Decision
   context: sessions currently lost on relaunch.
10. **Offline cache** — decision **D-02 chose GRDB**; none yet. Add an offline-first
    local store so the app works without network and syncs deltas.
11. **Error & loading states** — user-facing errors (toasts) on network failures,
    spinners on live loads, retry. Currently failures fall back silently to sample.
12. **Empty-state copy** — friendly "nothing yet / here's what to do" states.
13. **Wire or hide placeholder buttons** — Settings, Search, Bell, Inbox, ⋯/More,
    Add-people all have empty actions today (see [[plannit-live-feedback]]).
14. **Tests** — only Deno scheduler tests + CI compile exist. Add XCTest (unit +
    a few UI smoke tests). Consider an Appetize-based smoke check in CI.
15. **Accessibility & Dynamic Type**, and decide on **dark mode** (design system is
    light-only today).

### Phase 6 — Ship
16. **Apple Developer Program** ($99/yr) → real Sign in with Apple (configure the
    Apple provider in Supabase Auth) + APNs + on-device testing via **Codemagic →
    TestFlight** ([`../ios/CODEMAGIC.md`](../ios/CODEMAGIC.md)).
17. **App Store prep** — privacy nutrition labels (calendar data is sensitive),
    screenshots, review. Add **Sentry** (crash reporting) per the proposal.
18. **Non-user web participation link** (decision D-14) — lets people join a plan
    without the app; helps the cold-start problem.

---

## 3. Known issues / tech debt
- **Session not persisted** (in-memory token) — relaunch logs you out. (Phase 5.9)
- **Group hue not persisted** — no `hue` column; derived from name, so the hue
  picker in "New group" is cosmetic. Add a column or accept derived.
- **Group create can't add real members** — needs the friends system; today it
  creates the group with just the owner.
- **Calendar is a fixed sample month** (Aug 2026); live events map their day onto
  it, which is wrong across months. (Phase 2.4)
- **Placeholder buttons** do nothing (see Phase 5.13).
- **`fetchProposals` returns `[]`** in live mode (stub) — Plans tab is empty live.
- **No offline support / no retry** — network failure silently keeps sample data
  (the date-finder is the exception: it now surfaces a real error + retry).
- **A sent plan is invisible live** — `find-slots` persists the proposal, but the
  Plans tab can't read it back until 1.2 lands.

## 4. Small backlog
- Loading skeletons; pull-to-refresh; sign-out button wiring; avatar images
  (currently initials only); group avatars; time-zone-aware formatting; haptics;
  app version/build display in Settings.

---

## 5. Repository map
```
docs/            research, proposal, cost, decisions, backend contracts, THIS roadmap
design-system/   tokens, components, iOS ui_kit, app icon (source of truth for UI)
supabase/        migrations, RLS, seed, Edge Functions (find-slots, send-push)
ios/             SwiftUI app
  Plannit/App        entry, RootView (flow+tabs), AppModel, Info.plist, entitlements
  Plannit/Theme      tokens → Swift (color, type, metrics, icon, group hues)
  Plannit/Components  design-system components as SwiftUI views
  Plannit/Features    screens: Onboarding, Calendar, Groups, Plans, You
  Plannit/Services    SupabaseClient, AppleSignIn, CalendarService, DataRepository, Config
  Plannit/Models      UI models + sample data
.github/workflows/  ios-build (compile), ios-appetize (demo), ios-appetize-live
codemagic.yaml      Codemagic → TestFlight (needs Apple Developer account)
```

## 6. Environment & credentials checklist
- **GitHub secrets set:** `APPETIZE_API_TOKEN`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`.
- **GitHub repo variables:** `APPETIZE_PUBLIC_KEY` (demo app), `APPETIZE_LIVE_PUBLIC_KEY` (live app).
- **Appetize preview URLs (stable):**
  - Demo: `https://appetize.io/app/e2mqoojyf4ig4quzphi4p52dwi`
  - Live: `https://appetize.io/app/pf2plhtimqqxqku6kdlwyl7p2y`
- **Supabase project:** live; migrations 0001–0003 applied. **TODO:** `supabase db
  push` for `0004`, then set Vault secrets `internal_function_secret` and
  `functions_base_url` (see [`backend/setup-runbook.md`](backend/setup-runbook.md)
  §5b) to activate push triggers. Also configure Auth → Apple provider for
  on-device Sign in with Apple.
- **Not yet acquired:** Apple Developer Program ($99/yr) — gates real Apple
  sign-in, APNs, and on-device/TestFlight testing.
- **Keep `ios/Plannit/App/Info.plist` Supabase keys EMPTY** in the repo (demo
  default). Live creds are injected only in `ios-appetize-live.yml` at build time.
