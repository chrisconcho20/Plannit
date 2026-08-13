# Plannit — iOS UI kit

A click-through recreation of the Plannit iOS app (SwiftUI, iOS 17+) rendered in HTML at iPhone 14/15 size (390 × 844 inside a device frame).

Open `index.html`. Everything is fake data from `data.js`.

## What you can click

1. **Onboarding** — three panels (calendar sync → per-group privacy → the date-finder), then *Continue with Apple*, then the calendar-permission screen. "I have an account" skips straight in.
2. **Calendar tab** — Month / Week / List segmented control, tap any day in the month grid to filter the list, tap an event to push its detail screen.
3. **Event detail** — group-hue header, time/place/visibility rows, who's going with free/busy badges, *Share* opens the per-group visibility sheet.
4. **Groups tab** — group cards with hue tiles and member stacks; open one for its shared events and people; *Make a group* opens the create sheet (name, hue, people).
5. **Plans tab** — proposals awaiting votes; open one for the slot list and the *Who's free* availability view; *Lock in* fires the confirmation toast.
6. **The wedge flow** — the ＋ button opens *New plan*: pick a group, type a plain-language constraint ("a weekend afternoon"), watch busy blocks come in, get three ranked slots, send them to the group to vote.
7. **You tab** — profile, sync switches, notification settings.

## Files

| File | What's in it |
|---|---|
| `index.html` | Page shell: tokens, bundle, icon base path, keyframes, mounts `<App/>` |
| `App.jsx` | Flow state — onboarding → tabs → pushed screens → sheets → toasts |
| `Chrome.jsx` | Device frame, status bar, scroll container, section label, FAB |
| `Onboarding.jsx` | `Welcome`, `ConnectCalendar` |
| `CalendarScreen.jsx` | `CalendarScreen`, `EventDetail`, `ShareSheet` |
| `GroupsScreen.jsx` | `GroupsScreen`, `GroupDetail`, `NewGroupSheet` |
| `PlansScreen.jsx` | `PlansScreen`, `PlanDetail`, `NewPlanSheet`, `YouScreen` |
| `data.js` | People, groups, events, month marks, proposals |

## Notes

- Screens compose the design-system primitives only (`window.PlannitDesignSystem_ede968`); no component is re-implemented here.
- The repo is pre-development, so these screens are the **first** visual definition of Plannit rather than a recreation of shipped UI. Treat them as a proposal to react to, not a spec to match.
- The three keyframes (`plannit-fade`, `plannit-sheet`, `plannit-toast`) live in the page, not the components — any host page using `Sheet` or `Toast` must declare them.
