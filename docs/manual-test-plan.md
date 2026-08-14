# Manual test plan — Phase 1

_Last updated 2026-08-14. Run this against the **live** preview:
<https://appetize.io/app/pf2plhtimqqxqku6kdlwyl7p2y> (dev email sign-in). The
demo preview is <https://appetize.io/app/e2mqoojyf4ig4quzphi4p52dwi>._

Phase 1 is "find a date → send it → vote → lock it in → it's on everyone's
calendar", plus the per-group visibility it rests on. This walks that loop and
then tries to break it. Automated coverage lives in `ios/PlannitTests/` and
`supabase/functions/_shared/*.test.ts`; **everything below is the part a machine
can't check** — layout, wording, whether the thing feels right.

## Before you start

1. Run `supabase/seed-test-users.sql` in the SQL editor (idempotent — re-run it
   any time to move the busy blocks back to the next few weekends).
2. Deploy the scheduler if you haven't since the last change:
   `supabase functions deploy find-slots`.
3. Sign in as the email in the seed's first line.

The seeded people are Maya, Theo, Ada, Sam and Jo. Their availability is built
so that **Saturday afternoons** have no all-free date until the *third* Saturday,
and **Sunday afternoons** never have one (Jo is busy every Sunday for six months).

---

## 1. Identity and groups

| # | Do this | Expect |
|---|---|---|
| 1.1 | Open **You** | Your real name and the email you signed in with — not "You Concho" |
| 1.2 | Profile → Display name → change it → Save | The header updates; reopen Groups and your name has changed in the member lists |
| 1.3 | Open **Groups** | Your groups, each showing its real member count and faces |
| 1.4 | Open a group | Five seeded people plus you; you're badged **Owner** |
| 1.5 | ＋ → Make a group, tick two people, create | The new group appears with three members (you + two) |
| 1.6 | In that group, header ＋ (add people) | Only people *not* already in it are listed |
| 1.7 | Remove a member with ✕ → confirm | They disappear; the count drops |
| 1.8 | Swipe a group card across | **Delete** on a group you own, **Leave** on one you don't |
| 1.9 | Delete the throwaway group → confirm | It's gone from the list and doesn't come back on reload |

## 2. The date-finder (the wedge)

| # | Do this | Expect |
|---|---|---|
| 2.1 | ＋ → Find a time that works → pick a group | The constraint step, echoing "Searching the next 6 months for a time everyone can make" |
| 2.2 | Days = **Sat** only, afternoon, 2h → Find times | Results are **the third Saturday from now**, not this one, and the header shows the constraint (no warning) |
| 2.3 | Look at a slot card | "6 of 6 free" and the faces of the people actually free |
| 2.4 | Back, set days = **Sun** only → Find times | The amber line: "No time works for all 6 … here's the best turnout", and cards show 5 of 6 |
| 2.5 | You → Date finder → 1 month, then repeat 2.2 | Fewer/no results — the window preference is really used |
| 2.6 | Pick an impossible ask (one day, 4h, evening, 1 month) | A "No times work" empty state that points at the window setting — never a crash or an empty screen |
| 2.7 | Turn off the network (Appetize: leave it loading) and Find times | A real error with **Try again**, not silent sample data |

## 3. Voting and locking in

| # | Do this | Expect |
|---|---|---|
| 3.1 | From 2.2's results → Send to group to vote | Toast, and the Plans tab shows the plan |
| 3.2 | Plans tab badge | A number equal to the plans awaiting *your* vote — **not** a permanent 2 |
| 3.3 | Open the plan → tap a slot → Vote for this time | The card gets **Your pick**, the count goes up, the button reads "Your pick" |
| 3.4 | Tap another slot → Change my vote | The pick moves; the total doesn't double (one vote per person per plan) |
| 3.5 | Badge again | It drops by one — you've answered that plan |
| 3.6 | Lock in this time | Toast, plan moves to **Locked in**, voting stops |
| 3.7 | Calendar | The event is there on the right day, in the group's colour |
| 3.8 | Group → Shared events | The same event is listed |
| 3.9 | Sign in as `maya@plannit.test` / `plannit123` | She sees the plan, can vote, and has **no** Lock-in button (organiser only) |

## 4. Events and sharing

| # | Do this | Expect |
|---|---|---|
| 4.1 | Calendar ＋ → Add an event myself | Opens on the selected day at the next whole hour |
| 4.2 | Save it | It appears on that day, marked **Private**; the dot on the grid appears too |
| 4.3 | Open it → Visibility | "Private — only you" |
| 4.4 | Share to a group → tick one → Save | Visibility becomes "Shared with <group>"; it shows in that group's Shared events |
| 4.5 | Reopen the share sheet | The group is already ticked (state is read, not guessed) |
| 4.6 | Untick it → Save | Back to Private, and gone from the group |
| 4.7 | Inside a group, ＋ → Add an event myself | "Share with <group>" is offered and on by default |
| 4.8 | As Maya, open an event she doesn't own | No share button — "Shared with you — only the owner can change this" |

## 5. Calendar behaviour

| # | Do this | Expect |
|---|---|---|
| 5.1 | Month grid | Dots **only** on days that have events — the old hard-coded dots are gone |
| 5.2 | ‹ › | The month changes, "today" only rings in the current month, dots follow the month |
| 5.3 | Tap a day with nothing | "No events on this day" with a New event action |
| 5.4 | Cross a month boundary with an event | The event is on its real date, not the same day-number of the wrong month |

## 6. Try to break it

| # | Do this | Expect |
|---|---|---|
| 6.1 | Create a group with **no** members, then find a date | It works (a group of one) — no divide-by-zero, no "0 of 0" |
| 6.2 | Very long group name / event title (50+ chars) | Text wraps or truncates; no layout blowout |
| 6.3 | Emoji + accents in a display name | Renders in avatars and member lists |
| 6.4 | Double-tap Send / Vote / Lock in fast | One plan, one vote, one event — buttons disable while saving |
| 6.5 | Background the app mid-save, come back | No duplicate rows |
| 6.6 | Rotate / small device | Sheets stay usable, footers stay reachable |
| 6.7 | Relaunch the preview | **Known issue:** you're signed out — the session is in memory only (roadmap 5.9) |

---

## Known gaps (don't file these)

- **No realtime** — another person's vote appears on reload, not live.
- **Session isn't persisted** — relaunch signs you out.
- **Week view** is the same list as **List**; it was never built.
- **No event edit/delete**, no "unvote", no reopening a locked plan.
- **Friends don't exist** — you can only add people you already share a group
  with, so a brand-new account sees nobody until it's seeded.
- **Group hue** isn't stored; it's derived from the name, so the colour picker in
  "New group" is cosmetic.
