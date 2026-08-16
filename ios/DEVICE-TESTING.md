# Running Plannit on your own iPhone (no $99 account)

Xcode installs to **your own device** with a free Apple ID — Apple calls it a
*personal team*. You don't need the Developer Program for this; you need it for
TestFlight, other people's phones, push notifications, and real Sign in with
Apple ([`CODEMAGIC.md`](CODEMAGIC.md) covers that route).

This is worth doing: a real phone is the only place the calendar work can
actually be checked. Appetize hands you a fresh, empty simulator every session.

## What you need

- A Mac with **Xcode 16.4 or newer** (App Store). Not negotiable: the Supabase
  Realtime package needs Swift 6.1, and CI runs on exactly 16.4.
- `brew install xcodegen` — the project is generated from
  [`project.yml`](project.yml), there's no `.xcodeproj` in git.
- Your iPhone and its cable. iOS 17 or newer (the deployment target).

## Setup

```bash
git clone https://github.com/chrisconcho20/Plannit.git
cd Plannit/ios
xcodegen generate
open Plannit.xcodeproj
```

First open takes a minute or two: Xcode resolves the Swift package
(`supabase-swift`, pinned at 2.55.1) before it will build. Let it finish —
"Resolving Package Graph" in the toolbar.

Then, in Xcode, three things — all in the **Plannit** target →
**Signing & Capabilities**:

1. **Team** → *Add an Account…* → sign in with your Apple ID → pick
   `<Your Name> (Personal Team)`.
2. **Bundle Identifier** → change `com.plannit.app` to something nobody else has
   registered, e.g. `com.chrisconcho.plannit`. (Bundle ids are global; a
   generic one may already be taken by another team.)
3. **Remove the Sign in with Apple capability.** A personal team can't sign it,
   and the build fails with *"Personal development teams do not support the Sign
   in with Apple capability"*. Nothing calls it yet — live mode signs in with
   dev email — so you lose nothing.

   Do this **before** `xcodegen generate` — change one line in `project.yml`:

   ```yaml
   CODE_SIGN_ENTITLEMENTS: Plannit/App/Plannit-Personal.entitlements
   ```

   then `xcodegen generate` again. (`Plannit-Personal.entitlements` is an empty
   entitlements file kept for exactly this.) Don't commit that line — CI and
   Codemagic want the real one.

Pick your iPhone from the device menu and **⌘R**.

The first run fails on the phone with *"Untrusted Developer"*. On the phone:
**Settings → General → VPN & Device Management → your Apple ID → Trust**. Run
again.

## Live backend vs demo

The app runs in **demo mode** (sample data, no network) whenever the Supabase
keys in `Plannit/App/Info.plist` are empty — which is how they're committed, so
the demo preview stays clickable.

For the live backend, paste your project's values in locally:

```xml
<key>SUPABASE_URL</key>
<string>https://<project-ref>.supabase.co</string>
<key>SUPABASE_ANON_KEY</key>
<string><the anon key from Settings → API></string>
```

The anon key is a *publishable* key — it ships inside every client and RLS is
what protects the data, so this isn't a secret leak. Still **revert Info.plist
before you commit**: committing it flips the demo build to live and breaks the
demo preview. `git checkout ios/Plannit/App/Info.plist` when you're done.

Sign in with the dev email account you seeded
([`../supabase/seed-test-users.sql`](../supabase/seed-test-users.sql)).

## Watching what it's doing

Debug builds log to the console — counts and states only, never event titles,
emails or tokens (`Services/Log.swift`). Xcode's console shows it while the app
runs; Console.app filtered to subsystem `com.plannit.app` catches it when it's
running untethered.

The lines worth watching:

```
calendar  access request → granted
calendar  busy: 143 events in 56d → 38 merged blocks
calendar  creating the Plannit calendar
calendar  mirror: 3 plannit events, 1 written
sync      loaded: 2 groups, 11 events, 1 plans, 5 friends
sync      realtime: joined group topic
```

If availability looks wrong, the `busy:` line tells you whether the problem is
reading (`143 events` looks too low) or merging (`38 merged blocks` looks
wrong). If the Plannit calendar never appears, `mirror skipped:` says why.

## What a real device gets you that Appetize can't

This is the point of the exercise — everything here is unverified today:

- **Your actual calendar.** Availability (`busy_blocks`) computed from a real,
  full calendar rather than an empty simulator: merging, the 8-week horizon, and
  whether the date-finder's answers match reality.
- **The permission prompts.** Full access vs write-only, and what the app does
  when you grant the narrower one.
- **The "Plannit" calendar.** Lock a plan in, then open Apple's Calendar app —
  it should be there, in its own calendar, and disappear if the plan is removed.
- **Live re-sync.** Edit an event in Apple Calendar with Plannit open
  (`EKEventStoreChanged`), and background/foreground the app (full reconcile).
- **Feel.** Scrolling, the swipe-to-delete gesture, sheet heights, Dynamic Type,
  and whether the layout survives a real notch and home indicator.

Follow [`../docs/manual-test-plan.md`](../docs/manual-test-plan.md) — sections 4
and 5 are the ones that only mean something here.

## Limits of a personal team

- **Profiles expire after 7 days.** The app stops launching; re-run from Xcode.
- **No push notifications** (APNs needs the paid program) — not implemented yet
  either, so nothing is lost.
- **No real Sign in with Apple**, per above.
- **Only your own devices**, up to 3 apps installed at once. Other testers need
  TestFlight, which needs the paid program.

## Running the tests on the Mac

While you're there, both suites run locally:

```bash
cd ios
xcodebuild test -project Plannit.xcodeproj -scheme Plannit \
  -destination 'platform=iOS Simulator,name=iPhone 16'   # 33 unit tests

deno test supabase/functions/_shared/                     # 19 scheduler tests
```
