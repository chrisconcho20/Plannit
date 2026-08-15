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

## 0. Making an account

Sign-up needs the project's **Auth → Providers → Email → Confirm email** setting
considered. With it **on** (the Supabase default) a new account has to click a
link, and that link points at your Site URL — which isn't a real page yet, so
the account can't be confirmed. **For the beta, turn Confirm email off.**

| # | Do this | Expect |
|---|---|---|
| 0.1 | Create account → name, email, 6+ char password | Straight into the app, already named |
| 0.2 | You → Friends | Everyone else is already there (beta auto-friend) |
| 0.3 | Someone else's group → they see you | Your real name, not "Member" |
| 0.4 | Create an account with the same email again | "That email already has an account — sign in instead." |
| 0.5 | Try a 3-character password | "Use at least 6 characters" — before any network call |
| 0.6 | With Confirm email ON | "Check <email> for a confirmation link", and it flips back to Sign in |

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
| 3.9 | Sign in as `maya@plannit.test` (password = your `test_password`) | She sees the plan, can vote, and has **no** Lock-in button (organiser only) |

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

## 6. The polish pass (new)

| # | Do this | Expect |
|---|---|---|
| 6.1 | Sign in, force-quit, reopen | Still signed in — no sign-in screen |
| 6.2 | You → Sign out → confirm | Back to sign-in, and your data is gone from the tabs |
| 6.3 | Turn the network off, pull to refresh | An amber banner with **Retry**, not an empty screen |
| 6.4 | Event → ⋯ → Edit, change the time, save | The card and the calendar dot move to the new time |
| 6.5 | Event → ⋯ → Delete | Gone from the calendar and from any group it was shared with |
| 6.6 | Group → Rename or recolour | The name changes everywhere; the colour sticks (this device only) |
| 6.7 | Calendar → **Week** | A real week strip with dots, ‹ › moves weeks, tapping a day filters below |
| 6.8 | Groups → search icon → type a member's name | Groups containing that person |
| 6.9 | Plan → vote → **Remove my vote** | The count drops and the Plans badge comes back |
| 6.10 | Plan → **Cancel plan** (as organiser) | It disappears for everyone |

## 6b. Friends (beta auto-friending)

Needs `supabase db push` for `0005_friends_beta.sql` first.

| # | Do this | Expect |
|---|---|---|
| 6b.1 | You → **Friends** | Everyone seeded is already listed, with the beta note at the bottom |
| 6b.2 | Add a friend → a real email → Find them | The account, with **Send request** |
| 6b.3 | Add a friend → a made-up email | "No Plannit account with that email" — no hint about who exists |
| 6b.4 | Add a friend → someone already a friend | "You're already friends" |
| 6b.5 | Remove a friend, then reopen a group you share | They're still in the group — unfriending isn't kicking |
| 6b.6 | New group → People | Your friends are listed |
| 6b.7 | In the SQL editor: `update public.app_config set value='false' where key='auto_friend_everyone';` then create a new account | The new account starts with **no** friends, and the beta note is gone. Set it back to `'true'` afterwards |

## 6c. Live updates (needs `db push` for 0006)

Two browser sessions, two accounts: yours and `maya@plannit.test` (password = the
`test_password` you set in the seed).

| # | Do this | Expect |
|---|---|---|
| 6c.1 | Open the same plan in both | Both show the same counts |
| 6c.2 | Vote as Maya | **Your** screen updates within a second or two, untouched |
| 6c.3 | Vote as you | Your card moves **instantly** (optimistic), before the network |
| 6c.4 | Lock in as you | Maya's plan moves to Locked in on its own |
| 6c.5 | Share an event with the group | It appears in the other session's group |
| 6c.6 | Background one session for a minute, come back | It catches up immediately (the socket is dropped on background by design) |
| 6c.7 | Turn the network off, vote | The card still moves, then reverts with an error when the write fails |

If nothing arrives live but everything appears within ~20 seconds, the socket
isn't connecting and the polling fallback is carrying it — check that 0006 is
applied and that the channel is private.

## 6d. On a real device only

These can't be checked on Appetize at all — they're the reason for the Mac.

| # | Do this | Expect |
|---|---|---|
| 6d.1 | Grant calendar access with a real, full calendar | The date-finder's answers match reality — no "free" slot you know is booked |
| 6d.2 | Lock a plan in, open Apple Calendar | A **Plannit** calendar exists with the event in it |
| 6d.3 | Back in Plannit, look at the day | The plan appears **once**, not twice (it's in your device calendar now too) |
| 6d.4 | Add an all-day event in Apple Calendar | It shows in Plannit and does **not** block that day in the date-finder |
| 6d.5 | Edit an event in Apple Calendar with Plannit open | Plannit re-syncs within a moment |
| 6d.6 | Delete a locked-in plan in Plannit | It disappears from Apple Calendar too |
| 6d.7 | Settings → Display & Text Size → Larger Text | Every screen scales; nothing clips or overlaps |
| 6d.8 | Turn on VoiceOver, sweep a screen | **Known gap:** cards read as raw text runs; buttons are labelled |

## 6e. Invites, sharing, repeats, activity (needs `db push` for 0007/0008
and `functions deploy invite`)

| # | Do this | Expect |
|---|---|---|
| 6e.1 | Group → Invite with a link → Share | A share sheet with an https link |
| 6e.2 | Open that link in a browser | A page naming the inviter and group, with an "Open in Plannit" button |
| 6e.3 | Tap it with the app installed | Plannit opens, "You're in <group>", and you're friends with the inviter |
| 6e.4 | Tap the same link again | "You're already in <group>" — and no use is burned |
| 6e.5 | Owner removes the inviter, then someone opens the link | Refused — a removed member's link stops working |
| 6e.6 | Open `?t=deadbeef` in a browser | "Expired or used up" — never "no such invite" |
| 6e.7 | Event → Share → tick a person (not a group) | They see it on their calendar; yours says "Shared with <name>" |
| 6e.8 | As them, open it | "Shared with you", no share button |
| 6e.9 | New event → Repeats → Every week | It appears on the grid every week, at the same clock time |
| 6e.10 | Make a monthly event on the 31st | It skips February — it does not land on the 1st or the 28th |
| 6e.11 | Edit next month's occurrence | You're editing the series (one row), and every occurrence moves |
| 6e.12 | Check Apple Calendar | **One** repeating event in the Plannit calendar, not dozens |
| 6e.13 | Plans → bell | Votes, plans, shares and requests, newest first; the dot clears on open |
| 6e.14 | Have Maya vote, wait | It appears in your activity (live via broadcast, or within 30s) |

## 7. Try to break it

| # | Do this | Expect |
|---|---|---|
| 7.1 | Create a group with **no** members, then find a date | It works (a group of one) — no divide-by-zero, no "0 of 0" |
| 7.2 | Very long group name / event title (50+ chars) | Text wraps or truncates; no layout blowout |
| 7.3 | Emoji + accents in a display name | Renders in avatars and member lists |
| 7.4 | Double-tap Send / Vote / Lock in fast | One plan, one vote, one event — buttons disable while saving |
| 7.5 | Background the app mid-save, come back | No duplicate rows |
| 7.6 | Rotate / small device | Sheets stay usable, footers stay reachable |
| 7.7 | Sign in as two accounts on two browsers, vote on both | **Known gap:** neither sees the other until it reloads — no realtime yet |

---

## Known gaps (don't file these)

- **No reopening a locked plan** — cancel it and run the finder again.
- **No invite links** — reaching someone new needs their exact sign-up email.
- **No blocking** — removing a friend just deletes the row.
- **Group colour is device-local** — your teammates see the name-derived one.
