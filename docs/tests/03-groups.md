# 03 — Groups and members

**Tests:** creating a group with members, adding and removing people, rename,
recolour, delete vs leave, search.
**Needs:** 01.
**Time:** 10 minutes.

---

1. **Launch the app, go to the Groups tab.**
   - [ ] Your seeded groups are listed, each with a member count and faces.

2. **Tap a group.**
   - [ ] Five seeded people plus you.
   - [ ] You have an **Owner** badge; nobody else does.
   - [ ] Each other member has an X to remove them. The owner row has none.

3. **Back out. Tap the orange + button (bottom right).**
   - [ ] A sheet asks what you're making: **Find a time that works**,
         **Add an event myself**, and **Make a group** (the last one appears
         only on the Groups tab).

4. **Choose "Make a group".** Name it `Test Group`, pick a colour that is
   obviously not the default, tick **two** people, tap **Create group**.
   - [ ] It appears in the list with **3 members** (you plus two).
   - [ ] It uses the colour you picked.

5. **Open Test Group, tap "Add people".**
   - [ ] Only people **not already in the group** are listed.
   - [ ] Tick one, tap Add. The member count goes to 4.

6. **Remove someone:** tap the X on a member, confirm.
   - [ ] They disappear and the count drops.
   - [ ] The confirmation named the person.

7. **Tap "Rename or recolour".** Change the name to `Renamed Group`, pick a
   different colour, Save.
   - [ ] The header, the list, and the group's dot all show the new name and colour.
   - [ ] The sheet says the colour is saved on this device only.

8. **Go back to the Groups list. Swipe a group card from right to left.**
   - [ ] A red action is revealed: **Delete** on a group you own.
   - [ ] Tapping it asks for confirmation and warns it removes the group for
         everyone, along with its plans.

9. **Cancel that. Swipe Renamed Group and delete it for real.**
   - [ ] It's gone from the list.
   - [ ] Pull the list down to refresh. It stays gone.

10. **Tap the search icon (top right).** Type part of a **member's** name, e.g. `may`.
    - [ ] Groups containing Maya are listed. Search matches people, not just names.
    - [ ] The section header changes to "Matches".

11. **Type nonsense**, e.g. `zzzz`.
    - [ ] "No one by that name", quoting what you typed.

12. **Tap the X to close search.**
    - [ ] The full list returns.

---

## Verify in the database

```sql
select g.name, count(m.user_id) as members
  from public.groups g
  left join public.group_memberships m on m.group_id = g.id
 group by g.name order by g.name;
```

- [ ] `Renamed Group` is absent. The delete really deleted.
- [ ] Member counts match what the app showed.

## If it fails

- "Couldn't add them, only the group's owner can" means you're not the owner of
  that group. Try one you made.
- The swipe reveals nothing: tell me. The gesture is custom (our lists are cards,
  not a UIKit List) and this is its first run on real hardware.
