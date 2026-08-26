# 09 — Sharing

**Tests:** per-group visibility, sharing with one person, un-sharing, sharing
one of your own calendar's events, and what someone else sees.
**Needs:** 03, 04, 07.
**Time:** 15 minutes.

This is the app's second pillar, so it's worth being fussy: the promise is that
an event is private until you say otherwise.

---

1. **Launch the app, Calendar tab, create an event called `Secret Plan`.**
   - [ ] It's badged **Private**.
   - [ ] Its detail says "Private, only you".

2. **Open it, tap "Share to a group".**
   - [ ] Your **real groups** are listed, none ticked.
   - [ ] The text says only you can see it and asks who should.

3. **Tick one group, Save.**
   - [ ] The Private badge is gone.
   - [ ] The detail now reads "Shared with <group>".
   - [ ] The event takes on that group's colour in the calendar.

4. **Open the group, look at "Shared events".**
   - [ ] `Secret Plan` is listed.

5. **Reopen the share sheet.**
   - [ ] The group is **already ticked**. The state was read, not guessed.

6. **Scroll to "Or one person", tick a friend, Save.**
   - [ ] The detail now names both, e.g. "Shared with <group> and Maya Ellis".

7. **Untick the group, leave the person ticked, Save.**
   - [ ] The detail names only the person.
   - [ ] The group's "Shared events" no longer lists it.

8. **Untick everything, Save.**
   - [ ] Back to **Private**.

---

## See it from the other side

9. **Sign out. Sign in as** `maya@plannit.test` (with the password you set in the
   seed).

10. **Share an event with a group Maya is in** — you'll need to do this from your
    own account first, so: sign back in as yourself, share `Secret Plan` with a
    group Maya belongs to, then sign in as Maya again.
    - [ ] Maya sees the event on her calendar.
    - [ ] It's badged **"Shared with you"**, not "Private".

11. **As Maya, open that event.**
    - [ ] There is **no** share button.
    - [ ] It says "Shared with you, only the owner can change this."

12. **Sign back in as yourself.**


## Sharing an event from your own calendar

The promise being tested: nothing from your calendar reaches Plannit until you
tap the button, and after that the phone stays in charge of it.

20. **Calendar tab, tap one of your own events** (muted colour, **Private**
    badge — not a Plannit plan).
    - [ ] Visibility reads **"Only you — Plannit shares free/busy, never this"**.
    - [ ] There's a **Share with a group** button, and a line under it saying it
          copies the title, time and place.

21. **Tap it, tick a group, save.**
    - [ ] The usual share sheet appears — same one as a Plannit event.
    - [ ] Back on the calendar, the event now shows in the **group's colour**,
          and appears **once**, not twice. (It exists in two places now — your
          calendar and Plannit — and only one row should show.)
    - [ ] Opening it again reads **"Shared with <group>"**.

22. **Check what the group sees** (second account, or the SQL below).
    - [ ] It's in the group's plans, with its real title and time.

23. **Now move it on your phone.** Open the Calendar app, change the time by an
    hour, come back to Plannit and let it sync (or background/foreground it).
    - [ ] Plannit shows the **new** time.
    - [ ] The group sees the new time too — this is the point of the link. If it
          still shows the old one, tell me: the copy has gone stale, which is
          worse than not sharing at all.

24. **Delete it in the Calendar app**, then return to Plannit.
    - [ ] It disappears from your calendar **and** from the group.

```sql
select e.title, e.source, e.external_cal_id is not null as linked_to_phone,
       e.deleted_at, g.name as shared_with
  from public.events e
  left join public.event_shares s on s.event_id = e.id
  left join public.groups g       on g.id = s.group_id
 where e.source = 'device'
 order by e.created_at desc limit 5;
```

- [ ] One row per shared device event — **not two** after sharing twice.
- [ ] `linked_to_phone` is true. Without it nothing can keep the copy honest.
- [ ] Events you did **not** share are absent entirely. That's D-17: the rest of
      your calendar never left the phone.


---

## Verify in the database

```sql
select e.title, s.group_id is not null as to_group, s.shared_user_id is not null as to_person
  from public.events e join public.event_shares s on s.event_id = e.id
 order by e.created_at desc;
```

- [ ] Rows match what you ticked, and unticking really deleted them.

## If it fails

- Maya can see an event you never shared: stop and tell me immediately. That's an
  RLS problem, the most serious kind of bug in this app.
- The share sheet is empty of groups: you may be signed in as an account with no
  groups.
