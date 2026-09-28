# 17 — Quiet plans

A quiet plan is a window nobody is told about. It becomes a real plan only when
enough of the group independently says the same, and every one of those people
allows it. Needs `db push` for `0027` and `0028`, and two accounts in one group.

The failure that matters most here is not "no plan was made". It is **anything
that reveals a window to somebody before a plan exists.** Watch for that first.

## Posting one

| # | Do this | Expect |
|---|---|---|
| 17.1 | ＋ → Make a quiet plan | A sheet that says plainly that nobody will be told |
| 17.2 | Pick a group, a window, save | A toast: "Noted quietly. Nobody has been told." |
| 17.3 | As the other account, look everywhere — Plans, the group, Activity, the calendar | **Nothing.** No plan, no dot, no notification |
| 17.4 | You → Quiet plans | Your own window listed, with Cancel |
| 17.5 | Cancel it, reload | Gone from the list |
| 17.6 | Post a second quiet plan while one is open | The first is gone: one at a time, and the new one replaces it (0030) |
| 17.6b | The calendar, on a day the window covers | An indigo dot and a "Quiet" card. Tap it → "Take this quiet plan back?" → Remove it, and it goes |

## Matching

| # | Do this | Expect |
|---|---|---|
| 17.7 | Set both accounts to "it takes 2", then post overlapping windows from each | A plan appears for both, at the overlap — not at either full window |
| 17.8 | Check the times | The plan covers the shared part only. Two windows of 12–6 and 2–8 make a plan of 2–6 |
| 17.9 | Both accounts | The invitation behaves like any other: going / not going |
| 17.10 | You → Quiet plans, both accounts | The matched windows are no longer listed as open |
| 17.11 | Set "it takes 3" on one account, then repeat 17.7 with two people | No plan. One person's rule stops it, and the other is told nothing |
| 17.12 | Post windows that overlap by 20 minutes, with "an hour together" set | No plan — a 20-minute overlap is a coincidence, not a plan |
| 17.13 | In a group of three, restrict one account to "only match me with" one person, then have the third post an overlapping window | The restricted person is left out; the other two still match if their own rules allow it |

## Expiry

| # | Do this | Expect |
|---|---|---|
| 17.14 | Post a window ending in a few minutes, wait for it to pass, reload You | Not listed |
| 17.15 | In SQL: `select count(*) from quiet_plans where window_end <= now() and status <> 'matched';` | 0 within the hour — the purge runs at 17 past. `select private.purge_expired_quiet_plans();` forces it |
| 17.16 | `select * from cron.job where jobname = 'purge-expired-quiet-plans';` | One row. None means pg_cron wasn't enabled, and expiry only happens when a group is matched |
| 17.17 | A matched plan's row | Still there, with `matched_event_id` set — it explains where the event came from |

## What must never happen

| # | Check | Why |
|---|---|---|
| 17.18 | As account B, `select * from quiet_plans;` through the app's own key | Only B's rows. RLS is the guarantee; the matcher's access is separate |
| 17.19 | An unmatched window mentioned anywhere in the other account's UI | The feature's whole premise |
| 17.20 | A push about a quiet plan before it matched | Same |
