# 07 — Events: create, edit, delete

**Tests:** making an event, all-day events, editing, deleting, and the calendar
grid reflecting all of it.
**Needs:** 01, and **migration 0009** (`npx supabase db push`). Without it,
creating an event fails with "Couldn't save that" — the insert asks for the row
back, and the old SELECT policy couldn't see a row that didn't exist yet.
**Time:** 10 minutes.

---

1. **Launch the app, go to the Calendar tab.**
   - [ ] The current month is shown, with today circled.
   - [ ] Dots appear only under days that actually have something on them.

2. **Tap the + button in the Calendar header** (not the orange one).
   - [ ] A "New event" sheet opens.
   - [ ] It starts on the selected day at the next whole hour.

3. **Create an event:** name it `Test Dinner`, leave All day off, choose 2h, add
   a place. Tap **Add to calendar**.
   - [ ] It appears in the day's list with the time range and place.
   - [ ] A dot appears on that day in the grid.
   - [ ] It's badged **Private**.

4. **Tap the event.**
   - [ ] The detail shows Time, Place, and **Visibility: "Private, only you"**.

5. **Tap the ... menu (top right), choose "Edit event".**
   - [ ] The sheet is titled "Edit event" and is **pre-filled** with what you
         entered, including the duration chip.

6. **Change the time by two hours, save.**
   - [ ] The card and the day list show the new time.
   - [ ] The dot stays on the same day.

7. **Create a second event with "All day" turned on.**
   - [ ] The duration chips **disappear** when the toggle is on.
   - [ ] The date picker drops the time.
   - [ ] The saved event reads **"All day"** instead of a clock time.

8. **Check the month navigation:** tap the arrows either side of the month name.
   - [ ] The month changes and the dots follow it.
   - [ ] "Today" is only circled in the current month.

9. **Switch the segmented control to Week.**
   - [ ] A **seven-day strip** with dots, not the same list as List view.
   - [ ] The arrows move a week at a time.
   - [ ] Tapping a day filters the list below it.

10. **Switch to List.**
    - [ ] Upcoming events, earliest first.

11. **Open Test Dinner, ... menu, "Delete event", confirm.**
    - [ ] It disappears from the list and the dot goes with it.
    - [ ] Pull to refresh. It stays gone.

---

## Verify in the database

```sql
select title, all_day, start_at, deleted_at from public.events
 order by created_at desc limit 5;
```

- [ ] The all-day event has `all_day = true`.
- [ ] The deleted one has a **`deleted_at` timestamp** rather than being gone.
      That's the tombstone, so the delete can propagate.

## If it fails

- The dot appears on the wrong day: note the event's time and the day it landed
  on. Timezone handling would be the suspect.
- The edit sheet is empty rather than pre-filled: tell me.
