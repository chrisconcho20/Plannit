# 08 — Repeating events

**Tests:** the recurrence engine — weekly repeats, the monthly-on-the-31st rule,
editing a series, and how one row becomes many occurrences.
**Needs:** 07.
**Time:** 10 minutes.

The interesting cases here are deliberate: a monthly event on the 31st must
**skip** short months rather than silently moving to the 1st or the 28th.

---

1. **Launch the app, Calendar tab, tap + in the header.**

2. **Create `Five-a-side`** on a **Tuesday**, 1h, and set **Repeats: Every week**.
   Save.
   - [ ] The Repeats row is a menu offering Never, Every day, Every week,
         Every 2 weeks, Every month.

3. **Look at the month grid.**
   - [ ] A dot on **every Tuesday** of the month, not just the first.

4. **Tap next month's arrow.**
   - [ ] Dots continue on every Tuesday there too.

5. **Tap one of the later Tuesdays.**
   - [ ] The event is listed on that day, at the same time as the first one.

6. **Open it and check the detail.**
   - [ ] A **Repeats** row says "Every week".

7. **Switch to List view.**
   - [ ] The event appears **multiple times**, once per upcoming Tuesday, rather
         than once at its original date.

8. **Now the awkward one.** Create `Rent` on the **31st** of a month (pick a
   month that has one), Repeats: **Every month**.

9. **Page forward month by month for four months.**
   - [ ] It appears on the 31st of every month **that has a 31st**.
   - [ ] Months with 30 days or fewer (and February especially) show **nothing**.
         It must not appear on the 1st, the 28th or the 30th.

10. **Edit the series:** open any occurrence of Five-a-side, ... menu, Edit,
    change the time by an hour, save.
    - [ ] **Every** occurrence moves, not just the one you tapped. One row
          covers the whole series.

11. **Change the repeat to Never** on that event and save.
    - [ ] Only the original date keeps the event; the other Tuesdays clear.

---

## Verify in the database

```sql
select title, start_at, recurrence_rule from public.events
 where recurrence_rule is not null order by created_at desc;
```

- [ ] Weekly reads `FREQ=WEEKLY`, fortnightly `FREQ=WEEKLY;INTERVAL=2`,
      monthly `FREQ=MONTHLY`.
- [ ] There is **one row** for the series, not one per occurrence.

## If it fails

- An occurrence appears on the 1st of a month: that's the clamp bug the engine
  is specifically written to avoid. Tell me which month.
- Editing one occurrence changed only that date: tell me, that would mean the
  series id isn't resolving.
- Times drift by an hour after a clock change: note the date it happens. That's
  the daylight-saving case.
