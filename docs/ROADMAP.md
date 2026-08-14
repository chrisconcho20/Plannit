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
   `dayStart/EndMinutes`, duration, device timezone) and maps `FoundSlotDTO` →
   `PSlot`. `NewPlanSheet` previews with `persist:false` and only persists the
   proposal on **Send to group to vote**, with loading / error / no-results states.
   **A date the whole group can make always wins:** the scheduler
   (`findBestSlots`) returns the earliest all-free slots anywhere in the window
   and only falls back to the best turnout when there are none — the results
   header says which. The window is a personal preference (You → Date finder,
   1/3/6/12 months, default 6) stored under `SearchWindow.key`.
   _Follow-up:_ slot avatars still show the first N group members rather than the
   real `availableUserIds` (needs member ids on `PGroup`).
2. ~~**Live proposals + voting**~~ ✅ **done (2026-08-14).** `fetchProposals`
   reads proposals + group members + votes, and slots in a second query (the two
   FKs between `proposals` and `proposal_slots` make an embed ambiguous).
   `PlanDetailView` votes (one choice per proposal — casting replaces your last),
   shows per-slot counts and "Your pick", and **Lock in** (creator or group owner,
   matching RLS) sets `finalized_slot_id` + status, creates the winning `event`
   and shares it to the group. Slots carry `available_user_ids`, so cards show
   the faces of whoever is actually free.
   ✅ **Also done (2026-08-14):** you can take your vote back, and the organiser
   can cancel a plan.
   _Next here:_ no realtime — votes appear on reload, not as they land; a
   locked-in plan can't be reopened (cancel and re-run is the workaround).
3. ~~**Event sharing to groups (live)**~~ ✅ **done (2026-08-14).** `ShareSheet`
   lists your real groups pre-ticked with the event's current shares and diffs
   the selection on save (insert added / delete removed `event_shares`).
   `fetchEvents` embeds the shares, so an event knows who can see it, takes its
   group's colour, and appears in that group's "Shared events" (matched by id).
   Owner-only, matching RLS.
   _Next here:_ share-to-a-single-person (`shared_user_id`) is unused, and there's
   no "who can see this" list of names on the event.

### Phase 2 — Real calendar, real dates
4. ~~**Move off the fixed Aug-2026 sample month**~~ ✅ **done (2026-08-14).**
   `PEvent` carries a real `start: Date`; the grid shows the current month (with
   ‹ › navigation), "today" comes from the clock, and `marks` are derived from
   the loaded events — no more dots on days with nothing behind them.
   **New event** (`Features/Calendar/NewEventSheet.swift`) writes to `events` in
   live mode and appends locally in demo.
   ✅ **Also done (2026-08-14):** events can be edited and deleted (soft delete,
   so the tombstone propagates), and **Week** is a real week strip instead of a
   copy of the List.
5. **Full two-way sync** per [`backend/sync-contract.md`](backend/sync-contract.md).
   **Done (2026-08-14):** availability is now trustworthy — uncapped, merged
   (`Services/Availability.swift`, 11 tests), replace-not-append uploads, and it
   re-syncs on foreground + `EKEventStoreChanged` instead of only on first
   connect; events marked Free/cancelled/all-day no longer count as busy. Export
   works: a dedicated **"Plannit" `EKCalendar`** that Plannit-origin events are
   mirrored into (create/update/remove, keyed by an `events.id → eventIdentifier`
   map), so a locked-in plan really lands on the device.
   **Still to do:** the import half — device events as `events` rows keyed by
   `calendarItemExternalIdentifier` (now carried on `DeviceEvent`), a
   `last_synced_at` high-water mark, tombstones, and `BGAppRefreshTask`.
   ⚠️ Verification: EventKit round-trips can't be confirmed on Appetize (fresh
   empty simulator each session). The import half really wants TestFlight on a
   real device — see phase 6.

### Phase 3 — Social graph
6. ~~**Friends**~~ ✅ **structure done (2026-08-14).** `0005_friends_beta.sql`
   adds `app_config` (runtime switches), the `auto_friend_everyone` trigger and
   backfill, and three SECURITY DEFINER functions — `my_friends`,
   `my_friend_requests`, `find_profile_by_email` — for the things RLS correctly
   hides. You → **Friends**: accept/decline incoming, remove a friend, see
   outgoing, add by exact email. Group pickers draw from friends, falling back
   to visible co-members.
   **Beta behaviour:** every new account is auto-friended to everyone, so
   testing needs no request dance. Switching it off is an UPDATE on `app_config`.
   _Still to do:_ invite links (D-14 territory), blocking, and a friends-only
   privacy option for sharing (`event_shares.shared_user_id` is still unused).
7. ~~**Group management**~~ ✅ **done (2026-08-14).** Add / remove members,
   delete, leave, and rename + recolour. The hue is stored **on-device** per
   group (no `hue` column yet) and falls back to the name-derived colour —
   a migration would make it shared.

### Phase 4 — Notifications
8. **APNs client** — request permission, register the device token into
   `device_tokens` on launch, handle taps → deep-link (`proposalId`/`groupId`).
   Server side already exists (`send-push` + triggers). Contract:
   [`backend/push-notifications.md`](backend/push-notifications.md). Requires the
   Apple Developer account + APNs key.

### Phase 5 — Robustness & finalization
9. ~~**Session persistence**~~ ✅ **done (2026-08-14).** Keychain-backed session
   (access + refresh token + expiry), refreshed before it expires and retried
   once on a 401. Sign out is wired and clears everything. Unsigned simulator
   builds (CI, Appetize) fall back to UserDefaults, since the Keychain refuses
   an app with no entitlements.
10. **Offline cache** — decision **D-02 chose GRDB**; none yet. Add an offline-first
    local store so the app works without network and syncs deltas.
11. **Error & loading states** — ✅ live mode no longer starts on sample data, a
    failed load shows a banner with Retry, and every list pulls to refresh.
    _Still to do:_ skeletons while first loading, and per-action toasts for the
    writes that currently fail quietly (add/remove member, share).
12. **Empty-state copy** — friendly "nothing yet / here's what to do" states.
13. ~~**Wire or hide placeholder buttons**~~ ✅ **done (2026-08-14).** Search
    filters groups by name or member; ⋯ on an event is Edit/Share/Delete; the
    dead Inbox and Settings buttons are gone; Sign out works.
14. **Tests** — ✅ two suites run on every push: **XCTest** (`ios/PlannitTests`,
    22 tests — constraint maths, date/slot mapping, ownership and badge rules)
    via `xcodebuild test` in `ios-build.yml`, and **Deno** (19 tests including
    `scheduler.stress.test.ts` — scale, DST, timezones, degenerate input) via
    `functions-test.yml`. Manual pass: [`manual-test-plan.md`](manual-test-plan.md).
    _Still missing:_ UI tests, and nothing exercises the Supabase client against
    a real (or faked) backend — repository mapping is only covered by eye.
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
- **No realtime** — votes, shares and new plans appear on the next load, not as
  they happen. `postgres_changes` subscriptions are specced in the API contract
  but unused. This is the next structural gap now that phase 1 is complete.
- **Group hue is device-local** — the picker works, but the colour lives in
  UserDefaults, so teammates see the name-derived one. Needs a `hue` column.
- **Reaching a stranger needs their exact email** — by design (the directory
  isn't enumerable), but it means invite links matter more than they look.
- **Placeholder buttons** do nothing (see Phase 5.13).
- **No offline support / no retry** — network failure silently keeps sample data
  (the date-finder is the exception: it now surfaces a real error + retry).
- **Sample data still leaks into live mode** — `AppModel` seeds sample groups/
  events/proposals, so a failed or empty live load shows demo content. The Plans
  tab is the visible case (see above).

## 4. Small backlog
- Loading skeletons; pull-to-refresh; sign-out button wiring; avatar images
  (currently initials only); group avatars; time-zone-aware formatting; haptics;
  app version/build display in Settings.

---

## 5. Repository map
```
docs/            research, proposal, cost, decisions, backend contracts, THIS roadmap,
                 manual-test-plan (the pass a machine can't do)
design-system/   tokens, components, iOS ui_kit, app icon (source of truth for UI)
supabase/        migrations, RLS, seed, Edge Functions (find-slots, send-push)
ios/             SwiftUI app (+ PlannitTests, run by xcodebuild test in CI)
  Plannit/App        entry, RootView (flow+tabs), AppModel, Info.plist, entitlements
  Plannit/Theme      tokens → Swift (color, type, metrics, icon, group hues)
  Plannit/Components  design-system components as SwiftUI views
  Plannit/Features    screens: Onboarding, Calendar, Groups, Plans, You
  Plannit/Services    SupabaseClient, AppleSignIn, CalendarService, DataRepository, Config
  Plannit/Models      UI models + sample data
.github/workflows/  ios-build (compile), ios-appetize (demo), ios-appetize-live,
                    functions-test (Deno scheduler tests + type-check)
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
  sign-in, APNs, and TestFlight. **Not** needed to run on your own iPhone from a
  Mac: [`../ios/DEVICE-TESTING.md`](../ios/DEVICE-TESTING.md).
- **Keep `ios/Plannit/App/Info.plist` Supabase keys EMPTY** in the repo (demo
  default). Live creds are injected only in `ios-appetize-live.yml` at build time.
