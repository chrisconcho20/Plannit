# Market Research

_Compiled 2026-08-13._

## Summary

This is a **crowded but segmented** market. No single app does all three of Plannit's pillars — true two-way native calendar sync, group-scoped event visibility, and **automated constraint-based date-finding**. The apps that nail the social calendar don't auto-solve for a date; the apps that find a time are mostly web-based polls, not native social calendars. **That gap is the wedge.**

## Competitors

### A. Social shared calendars (closest neighbors)

| App | What it does | Gap vs. Plannit |
|---|---|---|
| **Howbout** | Market leader. Shared social calendar, "see when friends are free / find the gap," time voting, per-plan group chat, live social feed. Free, iOS + Android. **4.8★, 75k+ reviews.** | Biggest competitor. Date-finding is manual (read the gap + vote), not an automated constraint solver. Most-cited weakness: a **forced invite/referral wall** users dislike. |
| **OurCal** | Chat-first, **end-to-end encrypted**, one calendar per group, syncs device calendars. iOS/iPad/Mac/Vision Pro/Android. | Strong on privacy, but per-group siloed rather than "one personal calendar, selectively reveal events." No auto-scheduler. |
| **TimeTree** | Large, established shared calendar for families/couples/groups; syncs Google Calendar. | Mature and reliable but utility-oriented; weaker "social"; no smart date-finding. |
| **Yoller / Hangs** | Social planning; work even if some friends don't have the app; suggest options and let friends vote. | Good onboarding ideas (function without full network); still manual voting. |

### B. Availability pollers / meeting finders

| App | Nature |
|---|---|
| **When2Meet** | Availability grid, no account, **web-only, no native app**, clunky on mobile. |
| **Doodle** | Polished meeting polls, calendar integration, timezone detection — professional/meeting-oriented, not social. |
| **Timeful (formerly Schej), WhenAvailable, Rallly, TimeOverlap** | Free availability polls, calendar sync, link-based, one-off. |
| **Cal.com / Koalendar / Acuity** | Booking-link professional scheduling — adjacent, not our market. |

### C. Built-in / free baseline

- **Apple Family Sharing + iCloud shared calendars** are free and built into iOS. Any paid feature must clearly beat "just share an iCloud calendar."

## What to borrow (influences)

- **Howbout:** social-feed + chat-per-plan loop is what makes planning actually happen.
- **OurCal:** privacy as a selling point (E2E encryption) resonates for calendar data.
- **TimeTree:** reliable device-calendar sync is table stakes.
- **Yoller / Hangs:** link-based participation so the app works before your whole network joins.
- **Doodle / When2Meet / Timeful:** clean availability capture; auto timezone detection.

## What to avoid (anti-patterns)

- **Forced invite/referral walls** — Howbout's #1 complaint. Never gate core value behind recruiting.
- **Cold-start uselessness** — must be useful solo (personal calendar + sync) and support non-users via link.
- **Fighting Howbout on the pure shared-calendar job** — it's free, loved, entrenched. Win on the auto-scheduler + tight native sync instead.
- **Ignoring the free baseline** — beat "just share an iCloud calendar."
- **Web-poll clunkiness** — don't replicate When2Meet's mobile drag grid.
- **Leaking private event details** — share only opaque busy/free blocks for availability.

## Differentiators (the wedge)

1. **Automated constraint-based date-finding is the reason to build Plannit.** No competitor auto-solves "find a weekend afternoon everyone's free." It's a tractable interval-scheduling problem, not a heavy AI problem.
2. **Privacy-granular, per-group visibility over ONE personal calendar** — cleaner than OurCal's siloed calendars, more private than open feeds. Maps onto Postgres Row-Level Security.
3. **Tight, reliable native two-way sync** with the device calendar as a first-class citizen.

## Sources

- Howbout — https://howbout.app/ , https://apps.apple.com/mk/app/howbout-shared-calendar/id1477248221
- Howbout competitors (Product Hunt) — https://www.producthunt.com/products/howbout/alternatives
- OurCal — https://ourcal.com/
- TimeTree — https://apps.apple.com/us/app/timetree-shared-calendar/id952578473
- Timeful (formerly Schej) — https://timeful.app/
- WhenAvailable — https://whenavailable.com/
- Doodle / When2Meet alternatives (Cal.com) — https://cal.com/blog/when2meet-alternatives
- 10 apps to coordinate dates with friends (AutoSuite) — https://www.autosuite.app/10-apps-to-coordinate-dates-with-friends-effortlessly/
- 6 best apps to plan with friends (Flaky) — https://flaky-app.com/blog/best-apps-for-making-plans-with-friends.html
