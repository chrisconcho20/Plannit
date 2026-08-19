# 15 — Loading, errors and empty states

**Tests:** what the app shows when it has nothing, when it's fetching, and when
the network fails.
**Needs:** 01.
**Time:** 10 minutes.

---

## Empty states

1. **Sign out, then create a brand-new account** (test 01, step 2, different
   email). Before joining any group:
   - [ ] **Groups:** "No groups yet", explaining what a group *is* and what it
         gets you, with a "Make your first group" button. Not a bare button.
   - [ ] **Plans:** "No plans in the air", explaining what the finder does.
   - [ ] **Calendar**, on an empty day: "Nothing on this day", with a New event
         action.
   - [ ] **Plans, bell:** "All quiet".
   - [ ] **You, Friends:** with auto-friending on you'll have friends already; if
         you turned it off in test 04, "No friends yet" with a way to add one.

2. **Sign back in as your main account.**

## Loading

Skeletons show only on a **first** load with nothing on screen, so you have to
catch a cold start.

3. **Force-quit and relaunch**, watching the Groups tab closely.
   - [ ] Grey placeholder cards appear briefly, pulsing, then real content
         replaces them.
   - [ ] The layout doesn't jump when the real content lands.

4. **Pull to refresh** on a list that already has content.
   - [ ] Content **stays visible** while refreshing. It must not be replaced by
         skeletons. That's deliberate.

## Errors

5. **Turn the Mac's wi-fi off. Pull to refresh on Groups.**
   - [ ] An **amber banner** with a message and a **Retry** button.
   - [ ] The list keeps what it already had rather than blanking.
   - [ ] No sample or demo data appears.

6. **Tap Retry while still offline.**
   - [ ] The banner stays. Nothing crashes.

7. **Turn wi-fi back on, tap Retry.**
   - [ ] The banner clears and content refreshes.

8. **While offline, attempt a write** — rename a group, or remove a member.
   - [ ] A toast says it failed. It doesn't fail silently, and the UI doesn't
         pretend it worked.

---

## If it fails

- Sample data (Soccer, Maya Ellis, "Five-a-side") shows up in live mode after a
  failure: tell me immediately. Live mode starts empty by design.
- A write fails with no message: say which one.
- Skeletons on every refresh: they should only appear on a cold start.
