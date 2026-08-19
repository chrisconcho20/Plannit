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
   - [ ] Your two Saturday events appear under **"Also on your calendar"**.
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
- [ ] No row corresponds to the all-day or "Free" event.

## Then test that it stays current

9. **With Plannit still open**, switch to the simulator's Calendar app and add a
   new event tomorrow at 6:00 PM.

10. **Switch back to Plannit** (don't force-quit).
    - [ ] Within a moment the console shows another `calendar busy:` line with a
          higher count. That's `EKEventStoreChanged` firing.
    - [ ] The new event appears under "Also on your calendar" for tomorrow.

## If it fails

- No permission prompt at all → tell me; that's the bug I fixed on 15 Aug and it
  would mean the fix didn't take.
- `busy: 0 events` → the simulator's Calendar has no events in the next 56 days,
  or access was denied. Check You → Your calendar.
- N too low → we're missing events; say how many you created and what N was.
- M equals N → merging isn't working. Paste both numbers.
