# 09 — Sharing

**Tests:** per-group visibility, sharing with one person, un-sharing, and what
someone else sees.
**Needs:** 03, 04, 07.
**Time:** 10 minutes.

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
