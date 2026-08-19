# 16 — Try to break it

**Tests:** the edges. Run this last, once you know what "working" looks like.
**Needs:** everything else.
**Time:** as long as you like.

---

1. **A group of one.** Make a group with no other members, run the date-finder
   on it.
   - [ ] It works. No "0 of 0", no divide-by-zero, no crash.

2. **Very long text.** A group name of 60 characters, and an event title of 60.
   - [ ] Text wraps or truncates cleanly. Nothing overflows a card or pushes a
         button off screen.

3. **Emoji and accents.** Set your display name to `Chris (party emoji) Unicode`
   with a real emoji and an accented letter.
   - [ ] It renders in the You header, in member lists, and in avatars (which
         should show sensible initials).

4. **Double-tap everything.** Rapidly double-tap Send to group, Vote, Lock in.
   - [ ] One plan, one vote, one event. Buttons disable while saving.

5. **Background mid-save.** Start creating an event, press Home immediately, come
   back.
   - [ ] No duplicate rows, in the app or the database.

6. **Interrupt the date-finder.** Start a search, back out of the sheet at once.
   - [ ] No crash, and no stuck spinner when you reopen it.

7. **Timezone shift.** Simulator: Settings, General, Date & Time, turn off "Set
   Automatically", move the timezone several hours.
   - [ ] Events stay on the day they belong to.
   - [ ] The date-finder's "afternoon" still means afternoon **locally**.
   - [ ] Put it back afterwards.

8. **Rotate** (Cmd plus left/right arrow) on a few screens.
   - [ ] Nothing is cut off; sheets stay usable.

9. **Delete a group that has an open plan in it.**
   - [ ] The plan goes with it. No ghost entry in Plans.

10. **Sign out with a sheet open.**
    - [ ] You land on the sign-in screen, not a broken half-state.

11. **Two devices, one account.** Sign in as yourself on both simulators, change
    something on one.
    - [ ] The other catches up on refresh or foreground.

---

## Known, don't report these

- A locked plan can't be reopened; cancel and re-run is the workaround.
- Group colour is device-local, so another device shows the name-derived one.
- No push notifications.
- Activity rows aren't tappable.
- Reaching someone new needs their exact sign-up email, or an invite link.

## Anything else

If you find something that isn't on that list, it's worth reporting even if it
seems small. Include what you did, what you expected, what happened, and the
console lines around it.
