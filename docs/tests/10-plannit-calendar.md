# 10 — The Plannit calendar (the mirror)

**Tests:** whether a locked-in plan really lands on your calendar, and whether it
appears exactly once. This is the least-verified code in the project.
**Needs:** 06 (a locked-in plan).
**Time:** 10 minutes.

Plannit writes its own events into a dedicated calendar called **Plannit** and
never touches your existing ones. It also has to *ignore* that calendar when
reading back, or every plan would show twice.

---

1. **Launch the app and lock a plan in** (or use the one from 06).
   - [ ] Console: `calendar mirror: N plannit events, M written`.

2. **Open the Calendar app in the simulator.**
   - [ ] A calendar named **Plannit** exists.
   - [ ] The locked-in plan is in it, on the right day and time.
   - [ ] None of your own events moved or changed.

3. **Go back to Plannit, Calendar tab, that day.**
   - [ ] The plan appears **exactly once**.
   - [ ] It is **not** also listed under "Also on your calendar". If it is, the
         mirror is being read back as a device event, which is the specific bug
         this test exists for.

4. **Create a repeating event in Plannit** (weekly), then check the simulator's
   Calendar app.
   - [ ] It appears as **one repeating event**, not dozens of separate copies.

5. **Delete the locked-in plan's event in Plannit** (Calendar tab, the event,
   ... menu, Delete).
   - [ ] It disappears from the simulator's Calendar app too, within a refresh.

6. **Force-quit Plannit and relaunch.**
   - [ ] Console shows another `mirror:` line.
   - [ ] The number **written** is 0 or very low. It should skip events that
         haven't changed rather than rewriting everything each launch.

7. **In the simulator's Calendar app, drag one of your own (non-Plannit) events
   to a different day.**
   - [ ] Plannit's availability updates (a new `busy:` console line).
   - [ ] Plannit does **not** try to "correct" your event. Device events are
         yours; we only read them.

---

## If it fails

- No Plannit calendar appears: read the console. `mirror skipped: no calendar
  access` or `no writable calendar source` tells you which.
- The plan shows twice in Plannit: paste the console `mirror:` line and say which
  day. That's the duplicate-read bug.
- Every launch writes the same number of events: the change-detection isn't
  working, which would churn your calendar database. Worth reporting.
