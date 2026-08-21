# 06 — Invitations and RSVP

**Tests:** the group half of the wedge. An invitation arriving, answering it,
what that does to your calendar, changing your mind, and the organiser calling
it off.
**Needs:** 05 (you need a plan that was sent to a group).
**Time:** 12 minutes.

Two rules are being tested, and everything below is a consequence of one of
them (decision D-18):

1. **An invitation is not on your calendar until you say yes.**
2. **Taking a group plan off your calendar and declining it are the same act.**

The most useful version of this test uses **two accounts** — you as the
organiser on the simulator, a seeded test user in a second simulator or on your
phone. Steps that need the second account are marked **[2 accounts]**; skip them
if you only have one and note that they were skipped.

---

1. **Launch the app, go to the Plans tab.**
   - [ ] The plan you sent in 05 is under **"You're going"**, not under
         "Are you in?". You picked the time, so you're going by definition.
   - [ ] The row shows the group name, the date, and **"1 going"**.

2. **Go to the Calendar tab, find the date you picked.**
   - [ ] The event is there, in the group's colour.

3. **[2 accounts] On the second account, launch the app and open Plans.**
   - [ ] The plan is under **"Are you in?"** with a **Going** and a
         **Can't make it** button on the row itself.
   - [ ] The Plans tab in the tab bar shows a **badge with 1**.

4. **[2 accounts] Go to that account's Calendar tab, to the same date.**
   - [ ] The plan is **not there**. This is rule 1. An unanswered invitation
         lives in Plans and in the group, nowhere else.

5. **[2 accounts] Back in Plans, tap "Going".**
   - [ ] The row leaves "Are you in?" and appears under "You're going".
   - [ ] The badge on the tab bar clears.
   - [ ] The Calendar tab now shows the event on the right day.

6. **[2 accounts] Open the event from the calendar.**
   - [ ] **Who's going** lists the group's real members with real answers:
         Going, Can't make it, or No answer yet.
   - [ ] The header count reads *n* of *total*.
   - [ ] There is a **Remove** button at the top right (not a ⋯ menu — only the
         owner gets that).

7. **[2 accounts] Tap Remove.**
   - [ ] The warning says it comes off your calendar **and** the group sees you
         as not going. That's rule 2 — no silent stale yes.
   - [ ] Confirm. The Calendar tab no longer shows it.
   - [ ] Plans shows it under neither heading — you answered, and the answer
         was no.

8. **[2 accounts] Open the group, look at "Plans".**
   - [ ] The plan is still listed with its going count. Declining removes it
         from *your calendar*, not from the group.
   - [ ] Tapping it opens the event; the ✓/✗ buttons are there to change your
         mind.

9. **Back on the organiser's account, open the group.**
   - [ ] Under **Plans**, the plan shows the going count, updated within a few
         seconds of the other account answering (Broadcast; polling is the
         backstop, so give it up to 20 seconds).

10. **Open the plan, tap ⋯ → Delete event.**
    - [ ] The warning names how many people are going, e.g. *"The plan is off.
          1 person who's going will be told."*
    - [ ] Confirm.
    - [ ] It's gone from your calendar, from Plans, and from the group.
    - [ ] **[2 accounts]** It disappears from the other account's calendar too.

---

## Verify in the database

```sql
-- who answered what
select e.title, p.display_name, r.response, r.updated_at
  from public.event_rsvps r
  join public.events e   on e.id = r.event_id
  join public.profiles p on p.id = r.user_id
 order by r.updated_at desc limit 10;

-- what a "yes" actually creates: a personal share
select e.title, s.group_id is not null as to_group, s.shared_user_id is not null as to_person
  from public.event_shares s
  join public.events e on e.id = s.event_id
 order by s.created_at desc limit 10;
```

- [ ] One `event_rsvps` row per person per plan — answering twice **updates**,
      it doesn't stack.
- [ ] Everyone who said yes (except the owner) has a row with
      `to_person = true`. That row **is** the thing that puts it on their
      calendar.
- [ ] Whoever declined has **no** such row, and their response is `not_going`.
- [ ] The deleted event has `deleted_at` set rather than being erased:

```sql
select title, deleted_at from public.events order by created_at desc limit 3;
```

## If it fails

- **Going does nothing, or you get "Couldn't save your answer"**: 0010 isn't
  applied. `npx supabase db push`, then try again.
- **"That invitation is not for you"**: the account isn't in the group the plan
  was shared with. Check `group_memberships`.
- **You said yes but the calendar doesn't show it**: the personal share didn't
  land. Run the second query above — if `to_person` is false everywhere, look at
  `rsvp_to_event()`'s owner check.
- **The plan appears on the calendar before anyone answers**: the calendar isn't
  filtering on `isOnCalendar` — that's rule 1 broken, and worth reporting with
  the console output.
