repo: chrisconcho20/Plannit
branch: main

## Last sync

date: 2026-08-13T17:24:12Z

### Updated in this project

- Built the first Plannit design system from the repo's planning docs (no source code exists upstream yet).
- Tokens, 21 foundation cards, and 26 React primitives authored from the product brief.
- Click-through iOS UI kit covering onboarding, calendar, groups and the date-finder wedge.
- Lucide icon set copied in as a flagged stand-in for SF Symbols.

## Screen map

| Project screen / file | Built from |
|---|---|
| `readme.md` (context, content + visual foundations) | `README.md`, `docs/market-research.md`, `docs/decisions.md` |
| `tokens/*`, `guidelines/*` | Product brief — invented; no upstream design source |
| `ui_kits/plannit-ios/Onboarding.jsx` | `README.md` (three pillars), `docs/decisions.md` (D-03, D-05, D-08) |
| `ui_kits/plannit-ios/CalendarScreen.jsx` | `docs/technical-proposal.md` (§2 sync, §4 Event/EventShare), D-06, D-09 |
| `ui_kits/plannit-ios/GroupsScreen.jsx` | `docs/technical-proposal.md` (§4 Group/GroupMembership), D-09, D-14 |
| `ui_kits/plannit-ios/PlansScreen.jsx` | `docs/technical-proposal.md` (§5 the scheduler), D-10, D-11, D-12 |
| `components/calendar/AvailabilityBar.jsx` | `docs/technical-proposal.md` (BusyBlock), D-08 |
