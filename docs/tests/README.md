# Test scripts

One file per area, in the order they should be run — each builds on the state the
previous one left behind. Every file starts from launching the app, so you can
stop and resume anywhere.

| # | File | Needs |
|---|---|---|
| 01 | [First run and sign-up](01-first-run-and-signup.md) | — |
| 02 | [Calendar access and availability](02-calendar-access.md) | 01 |
| 03 | [Groups and members](03-groups.md) | 01 |
| 04 | [Friends](04-friends.md) | 01 |
| 05 | [The date-finder](05-date-finder.md) | 02, 03 |
| 06 | [Voting and locking in](06-voting-and-lock-in.md) | 05 |
| 07 | [Events: create, edit, delete](07-events.md) | 01 |
| 08 | [Repeating events](08-repeating-events.md) | 07 |
| 09 | [Sharing](09-sharing.md) | 03, 04, 07 |
| 10 | [The Plannit calendar](10-plannit-calendar.md) | 06 |
| 11 | [Invite links](11-invite-links.md) | 03 |
| 12 | [Activity feed](12-activity.md) | 06 |
| 13 | [Live updates (two accounts)](13-live-updates.md) | 06 |
| 14 | [Accessibility](14-accessibility.md) | 01 |
| 15 | [Loading, errors, empty states](15-states.md) | 01 |
| 16 | [Try to break it](16-break-it.md) | everything |

## Before you start

- The app must be in **live mode**: the first screen says *Sign in / Create
  account*. If it says *Continue with Apple*, the Supabase keys in
  `ios/Plannit/App/Info.plist` are empty — paste them in and rebuild.
- Keep **Xcode's console visible** while testing. The app logs counts and states
  (never titles or emails). Several tests ask you to read it.
- The Supabase **SQL editor** open in a browser tab is handy for the checks that
  verify what actually landed in the database.

## How to report a failure

Copy the step number, what you expected, what happened, and the console lines
around it. That's usually enough to find the cause without guessing.
