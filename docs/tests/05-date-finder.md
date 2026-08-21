# 05 — The date-finder

**Tests:** the wedge. Constraint building, the everyone-free preference, the
best-turnout fallback, the search window, picking a date, error handling.
**Needs:** 02 (so availability exists) and 03.
**Time:** 15 minutes.

The seeded busy blocks make the answers predictable: **Maya, Theo and Ada are
busy the next two Saturdays. Jo is busy every Sunday for six months.**

---

1. **Launch the app. Tap the orange + button, choose "Find a time that works".**
   - [ ] Step 1 asks you to pick a group and shows each group's size.

2. **Pick a seeded group (6 people), tap Next.**
   - [ ] Step 2 shows Name, Which days, Time of day, How long.
   - [ ] Under the wand icon: the constraint in plain English, plus
         **"Searching the next 6 months for a time everyone can make."**

3. **Set days to Saturday only.** Afternoon, 2h. Tap **Find times**.
   - [ ] A brief "Checking everyone's calendars..." state.
   - [ ] The header now reads **"Pick a date"** — this is a choice, not a list.
   - [ ] Results are grouped under a **date heading** (SATURDAY 5 SEPTEMBER),
         with **at most two times under each**, and at most four dates.
   - [ ] **The first date is the THIRD Saturday from now**, not this weekend and
         not next. Maya, Theo and Ada are busy before then.
   - [ ] Cards read **6 of 6 free** and show real faces.
   - [ ] The best option is **already selected** — a filled tick on the right.
   - [ ] The header shows the constraint with a green tick, no warning.

4. **Go back, set days to Sunday only.** Find times.
   - [ ] An **amber** line: "No time works for all 6 in the next 6 months,
         here's the best turnout."
   - [ ] Cards read **5 of 6**, and Jo is missing from the faces.

5. **Go to You, Date finder, set the window to 1 month.** Repeat step 3.
   - [ ] Fewer results, or none. The preference is genuinely used.
   - [ ] Step 2's sentence now says "the next 1 month".

6. **Set it back to 6 months.**

7. **Ask for something impossible:** one day, 4h, evening, window at 1 month.
   - [ ] "No times work", a real empty state rather than a blank screen.
   - [ ] It suggests more days, a shorter plan, or a longer window.

8. **Test the failure path.** Turn off the Mac's wi-fi, then Find times.
   - [ ] A real error with a **Try again** button.
   - [ ] It does **not** silently show made-up results.
   - [ ] Turn wi-fi back on, Try again, it recovers.

9. **Tap a different time under a different date.**
   - [ ] The tick moves. Only one time is ever selected.
   - [ ] The button at the bottom names the date you chose, e.g.
         **"Send Sat 5 to the group"**.

10. **Tap it.**
    - [ ] A toast confirms it.
    - [ ] You land on the Plans tab, with the plan under **"You're going"** —
          you picked the time, so you're going. Everyone else gets an
          invitation to answer (test 06).

---

## Verify in the database

The finder no longer writes anything (decision D-18): searching is a preview,
and the only thing that survives the sheet is the date you picked. So the check
is that a **plain event** appeared, owned by you and shared with the group:

```sql
select e.title, e.start_at, e.end_at, g.name as shared_with
  from public.events e
  join public.event_shares s on s.event_id = e.id
  join public.groups g       on g.id = s.group_id
 order by e.created_at desc limit 3;

-- and nothing new here, ever again
select count(*) from public.proposals;
```

- [ ] One event, at the time you chose, shared with the group you picked.
- [ ] The proposal count is whatever it was before — the finder stopped writing
      to those tables.

## If it fails

- Results include this Saturday: either the seed didn't run, or find-slots wasn't
  redeployed. Re-run the seed, then `npx supabase functions deploy find-slots`.
- "The scheduler failed (404)": the function isn't deployed.
- No results at all: check `select count(*) from public.busy_blocks;`
