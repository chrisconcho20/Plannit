# 06 — Voting and locking in

**Tests:** reading a plan back, voting, changing and removing a vote, the Plans
badge, locking a time in, cancelling.
**Needs:** 05 (you need a plan that exists).
**Time:** 10 minutes.

---

1. **Launch the app, go to the Plans tab.**
   - [ ] The plan you sent in 05 is under **"Awaiting your vote"**.
   - [ ] The row shows the group, the constraint, and the best time.

2. **Look at the tab bar.**
   - [ ] The Plans tab has a badge with a number.
   - [ ] That number equals the plans you haven't voted on. It is **not** a
         permanent "2".

3. **Open the plan.**
   - [ ] Slots are listed best-first, with faces of who's free.
   - [ ] The header says how many of the group have voted.

4. **Tap a slot that isn't the top one, then "Vote for this time".**
   - [ ] The card moves **instantly**, before any network round trip.
   - [ ] It gains a **Your pick** badge and a vote count.
   - [ ] The button now reads "Your pick" and is disabled.

5. **Check the tab badge.**
   - [ ] It dropped by one. You've answered this plan.

6. **Tap a different slot, then "Change my vote".**
   - [ ] The pick moves to the new slot.
   - [ ] The old slot's count goes **down**, the new one's goes **up**.
   - [ ] The total voter count does **not** increase. One vote per person.

7. **Tap "Remove my vote".**
   - [ ] Your pick clears and the count drops.
   - [ ] The tab badge comes **back**.

8. **Vote again, then tap "Lock in this time".**
   - [ ] A toast confirms it.
   - [ ] The plan moves to a **"Locked in"** section.
   - [ ] Voting controls are gone; the locked slot is highlighted and the others
         dimmed.

9. **Go to the Calendar tab.**
   - [ ] The plan is now an event, on the right day, in the group's colour.

10. **Open the group, look at "Shared events".**
    - [ ] The same event is listed there. Locking in shared it with the group.

11. **Go back to Plans, open a plan you have NOT locked, and tap "Cancel plan".**
    - [ ] It warns that the times and everyone's votes go with it.
    - [ ] Confirming removes it from the list entirely.

---

## Verify in the database

```sql
select title, status, finalized_slot_id is not null as locked
  from public.proposals order by created_at desc limit 3;

select count(*) from public.votes;
```

- [ ] The locked plan has `locked = true` and status `finalized`.
- [ ] The vote count matches what you cast (one row per person per plan).

## If it fails

- The Plans tab is empty though 05 succeeded: fetchProposals isn't returning.
  Paste the console `sync loaded:` line, which includes the plan count.
- No Lock-in button: you're not the plan's creator or the group's owner. That's
  correct behaviour, matching the RLS.
- The event doesn't appear on the calendar after locking in: paste the console.
