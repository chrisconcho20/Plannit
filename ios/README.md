# Plannit — iOS App (SwiftUI)

A native SwiftUI implementation of the Plannit UI, built to the design system in
[`../design-system/`](../design-system). Requires a **Mac with Xcode 15+** to
build and run (iOS 17+).

## Generate the Xcode project

The project is described declaratively so it isn't a committed binary. With
[XcodeGen](https://github.com/yonyz/XcodeGen) installed (`brew install xcodegen`):

```bash
cd ios
xcodegen generate      # creates Plannit.xcodeproj from project.yml
open Plannit.xcodeproj
```

No XcodeGen? Create a new iOS App in Xcode (SwiftUI, iOS 17), delete its stub
files, and drag the `Plannit/` folder in. Set the app icon to `AppIcon` and add
the calendar usage strings + `plannit` URL scheme from `Plannit/App/Info.plist`.

Set your **Team ID** in `project.yml` (`DEVELOPMENT_TEAM`) before signing (not
needed to run in the simulator).

## Run on the iOS Simulator (demo mode)

```bash
cd ios
brew install xcodegen        # once
xcodegen generate
open Plannit.xcodeproj
```

In Xcode pick an **iPhone 15** simulator and press **⌘R**. The app launches in
**demo mode** — no backend, no Apple Developer account, no sign-in required — so
you can click through the entire app (onboarding → calendar → groups → the
date-finder → plans → settings) on sample data immediately.

**Exercise the real calendar (end-to-end in the simulator):**
1. On the "Connect your calendar" onboarding screen, tap **Connect calendar** → **Allow**.
2. Open the Simulator's built-in **Calendar** app and add a couple of events.
3. Back in Plannit, the Calendar tab shows them under **"From your calendar"**.

Prefer the command line?
```bash
xcodebuild -project Plannit.xcodeproj -scheme Plannit \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Live backend (optional, later)
Fill `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `Plannit/App/Info.plist`. Until
both are set the app stays in demo mode. Full data + Sign in with Apple + APNs
wiring is the next milestone.

## Structure

```
Plannit/
├─ App/            PlannitApp, RootView (tabs + flow), Info.plist, entitlements
├─ Theme/          design tokens → Swift: Color, Typography, Metrics, Icon, GroupHue
├─ Components/     the DS component set as SwiftUI views
├─ Models/         UI models + sample data (mirrors the DS data.js)
├─ Features/       screens: Onboarding, Calendar, Groups, Plans (+ the date-finder), You
└─ Assets.xcassets AppIcon (from the design system)
```

## How it maps to the design system

- **Tokens** (`Theme/`) are translated 1:1 from `design-system/tokens/*.css`.
  The DS fonts note says Plannit's real type is Apple **SF Pro / SF Pro Rounded**
  (Figtree was a web stand-in), so display roles use the `.rounded` design and
  no fonts are bundled.
- **Components** (`Components/`) mirror `design-system/components/*` (Button,
  Card, Badge, Avatar, EventCard, SlotCard, AvailabilityBar, MonthGrid, TabBar…).
- **Screens** (`Features/`) recreate `design-system/ui_kits/plannit-ios/*`.
- **Icons** are mapped from the DS's lucide names to native SF Symbols in
  `Theme/Icon.swift`.

## Status & next steps

- **Now:** fully navigable UI on **sample data** (`Models/SampleData.swift`) —
  onboarding, calendar + event detail + share sheet, groups + detail + create,
  plans + plan detail + the date-finder flow, and settings.
- **Next (wiring):** replace sample data with the Supabase Swift client per
  [`../docs/backend/api-contract.md`](../docs/backend/api-contract.md), implement
  EventKit sync per [`../docs/backend/sync-contract.md`](../docs/backend/sync-contract.md),
  add Sign in with Apple, and register APNs tokens.
- Not built on this machine (Windows/no Xcode) — first `xcodegen generate` + build
  on a Mac is the real compile check.
