# 02 — Calendar access and availability

**Tests:** the permission prompt, reading the device calendar, merging busy
blocks, uploading them. This is the feature that only works on real hardware
(or a simulator you've filled in yourself), so take your time here.
**Needs:** 01.
**Time:** 15 minutes.

---

## Set up ground truth first

1. **Open the Calendar app inside the simulator** (not on your Mac).

2. **Add these events**, so you know exactly what the answer should be:
   - [ ] **Saturday afternoon**, 1:00–3:00 PM — call it "Busy Saturday".
   - [ ] The **same Saturday**, 2:00–4:00 PM — "Overlapping" (deliberately
         overlapping the first).
   - [ ] **Any weekday**, 9:00–10:00 AM — "Standup".
   - [ ] **An all-day event** on a different day — "Birthday".
   - [ ] **A multi-day all-day event** — two days or more, call it "Portugal".
   - [ ] **A repeating event** — weekly, any time, called "Weekly standup".
   - [ ] **An event four months from now**, 2:00–4:00 PM — "Far future". This
         one matters: availability used to stop at 8 weeks while the finder
         searched 6 months, so anything out here was invisible and the group
         was told everyone was free.
   - [ ] One event marked **"Show As: Free"** if the simulator's Calendar lets
         you — "Ignore me".

   Write down how many are timed, non-free and non-all-day. With the list above
   that's **3** (Busy Saturday, Overlapping, Standup).

---

## Now the app

3. **Launch Plannit.**
   - [ ] Because you signed out and in during 01, you may see the calendar
         screen. If you already granted access, skip to step 6.

4. If you have **not** yet been asked: **sign out and sign back in** (You → Sign
   out, then sign in).
   - [ ] After signing in you get the **"Connect your calendar"** screen, *not*
         the main app. This is the fix that makes the rest of the feature reachable.
   - [ ] The explanation mentions that event details stay on your device.

5. **Tap "Connect calendar".**
   - [ ] iOS shows the system permission alert.
   - [ ] Allow it. You land in the app.
   - [ ] Console: `calendar access request → granted`.

6. **Read the console for the busy line.**
   - [ ] `calendar busy: N events in 56d → M merged blocks`
   - [ ] **N matches the number of timed, non-free events you created** (3 above).
         The all-day "Birthday" and the "Free" one must NOT be counted.
   - [ ] **M is smaller than N** — Busy Saturday and Overlapping overlap, so
         they merge into one block. With the list above, M should be **2**.

7. **Go to the Calendar tab and tap that Saturday.**
   - [ ] Your two Saturday events are in the day's list, in time order, with
         a muted colour and a **Private** badge.
   - [ ] They are **not** listed under any other day.

8. **Tap a day with nothing on it.**
   - [ ] "Nothing on this day" with a **New event** action.

---

## Verify the upload

```sql
select start_at, end_at from public.busy_blocks
 where user_id = (select id from auth.users where email = 'YOUR@EMAIL')
 order by start_at;
```

- [ ] The number of rows equals **M** from step 6.
- [ ] The Saturday row spans **1:00 PM to 4:00 PM** — the two events merged into
      one range, not two rows.
- [ ] No row corresponds to the single-day "Birthday" or the "Free" event.
- [ ] **There IS a row covering "Portugal"** — a multi-day all-day event blocks
      its whole span, where a birthday doesn't.
- [ ] **There IS a row for "Far future"**, four months out. Check the last row:

```sql
select max(end_at) from public.busy_blocks
 where user_id = (select id from auth.users where email = 'YOUR@EMAIL');
```

- [ ] That maximum is **at least as far out as your search window** (You → Date
      finder, 6 months by default). If it stops at 8 weeks, the finder is
      guessing past that point.

### Declining an invitation

Only testable with a real invitation (an Exchange/Google account, or a shared
iCloud calendar):

- [ ] Decline an invitation in the Calendar app, then re-sync Plannit.
- [ ] The block for it **disappears**. You told them you're not coming.

### The failure that must not happen

18. **Turn off wi-fi**, edit an event in the Calendar app, return to Plannit,
    wait for the sync to fail, then run the busy_blocks query again.
    - [ ] **The rows are still there.** They may be stale by one edit — that's
          correct. What must never happen is an empty table, because empty
          reads as "free at all times" and the group gets offered your Monday
          morning.
    - [ ] You → Your calendar says it couldn't share your free/busy.
    - [ ] Turn wi-fi back on; within a sync it recovers and the line goes back
          to "Free/busy shared just now".

## The parts that only break on a real calendar

11. **Find the "Weekly standup" in Plannit's calendar list.**
    - [ ] It appears **once per week**, on each of its dates.
    - [ ] Xcode's console has **no** "ID occurs multiple times" warning.
          EventKit gives every occurrence the same identifier, so this is the
          check that we're distinguishing them by start time.

12. **Scroll the month grid forward four months.**
    - [ ] Your own events are still listed, and the grid still shows dots.
          (They used to vanish after ~2 months.)
    - [ ] "Far future" is there, on the right day.

13. **Tap one of your own events** (not a Plannit plan).
    - [ ] It opens a read-only detail saying it's from your calendar.
    - [ ] "Open in Calendar" takes you to that day in the Calendar app.
    - [ ] It does **not** offer to edit or delete — Plannit doesn't touch
          calendars it didn't create.

14. **Everything is in one list.** Look at a day that has both a Plannit plan
    and one of your own events.
    - [ ] They're interleaved **by time**, not split into two sections.
    - [ ] Your own events still read as yours: muted colour, "Private" badge.

## Which calendars count

15. **Go to You → Which calendars.**
    - [ ] Every calendar on the device is listed, grouped by account, each with
          a colour dot and a toggle. All on by default.

16. **Switch one off** — ideally one holding a test event.
    - [ ] Its events disappear from the calendar list within a moment.
    - [ ] The console logs a fresh `calendar busy:` line with a **lower** count.
    - [ ] The busy_blocks query below returns fewer rows. Off means off for
          availability too — that's the point, a subscribed fixtures feed
          shouldn't be able to mark you busy.

17. **Switch it back on** and confirm both come back.

## Then test that it stays current

9. **With Plannit still open**, switch to the simulator's Calendar app and add a
   new event tomorrow at 6:00 PM.

10. **Switch back to Plannit** (don't force-quit).
    - [ ] Within a moment the console shows another `calendar busy:` line with a
          higher count. That's `EKEventStoreChanged` firing.
    - [ ] The new event appears in tomorrow's list.

## If it fails

- No permission prompt at all → tell me; that's the bug I fixed on 15 Aug and it
  would mean the fix didn't take.
- `busy: 0 events` → the simulator's Calendar has no events in the horizon, or
  access was denied, or you've switched every calendar off in You → Which
  calendars.
- `busy: refusing to upload an empty set` in the console → the read came back
  empty while the calendar wasn't. That's the guard working; tell me, because
  the read is broken.
- N too low → we're missing events; say how many you created and what N was.
- M equals N → merging isn't working. Paste both numbers.
