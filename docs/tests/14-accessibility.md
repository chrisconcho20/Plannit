# 14 — Accessibility

**Tests:** Dynamic Type scaling, tap-target sizes, and whether VoiceOver reads
cards as sentences rather than fragments.
**Needs:** 01, plus some events and groups so screens aren't empty.
**Time:** 10 minutes.

---

## Dynamic Type

The fastest route is Xcode's **Environment Overrides** button in the debug bar
(the toggles icon, while the app is running).

1. **Run the app, open Environment Overrides, enable Dynamic Type**, and drag the
   slider up gradually.
   - [ ] Text on every screen grows. Nothing stays a fixed size.
   - [ ] At the largest **non-accessibility** size, Calendar, Groups, Plans and
         You are all still usable.
   - [ ] Buttons grow with their labels rather than clipping them.
   - [ ] The month grid stays a grid; day numbers don't overlap their dots.

2. **Drag it into the accessibility sizes (the largest few).**
   - [ ] Text stops growing at a point (capped at 1.6x deliberately) rather than
         becoming unusable.
   - [ ] Sheets stay scrollable and their bottom buttons stay reachable.

3. **Set it back to default.**

## Tap targets

4. **Tap the small controls at their very edge:** the X to remove a member, the X
   to remove a friend, the month arrows.
   - [ ] Each responds from slightly outside its visible circle. They're 32pt
         circles with 44pt touch areas.

## VoiceOver labels

Don't fight VoiceOver in a simulator. Use **Xcode, Open Developer Tool,
Accessibility Inspector**, point its target at the simulator, and use the
crosshair to inspect elements.

5. **Inspect an event card on the Calendar tab.**
   - [ ] It's **one** element reading something like
         "Five-a-side, 2:00 to 4:00 PM, at Hackney Marshes, shared with Soccer".
   - [ ] Not six separate elements (title, icon, time, dot, pin, place).

6. **Inspect a group card.**
   - [ ] "Soccer, 6 people, Tuesday and weekend games".

7. **Inspect a day cell in the month grid.**
   - [ ] "Saturday 16 August, 2 events", and "today" on today's cell.
   - [ ] Not the bare number "16".

8. **Inspect a slot card inside a plan.**
   - [ ] "SAT 16, 2:00 to 4:00 PM, everyone free, best option", plus "selected"
         when it is.

9. **Inspect an avatar stack.**
   - [ ] "Maya Ellis, Theo Sand and 4 others", not a row of initials.

10. **Catch a loading skeleton** (see test 15) and inspect it.
    - [ ] One element saying "Loading", not five.

---

## If it fails

- Text doesn't scale on some screen: name the screen. Every style is supposed to
  route through the scaling modifier.
- A card reads as many elements: name the card.
- Something is unreachable at large text: a screenshot beats a description.
