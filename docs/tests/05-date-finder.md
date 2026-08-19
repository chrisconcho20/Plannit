# 05 — The date-finder

**Tests:** the wedge. Constraint building, the everyone-free preference, the
best-turnout fallback, the search window, error handling.
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
   - [ ] **The first date is the THIRD Saturday from now**, not this weekend and
         not next. Maya, Theo and Ada are busy before then.
   - [ ] Cards read **6 of 6 free** and show real faces.
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

9. **From a good result, tap "Send to group to vote".**
   - [ ] A toast confirms it.
   - [ ] You land on the Plans tab with the new plan listed.

---

## Verify in the database

```sql
select title, status, window_start, window_end from public.proposals
 order by created_at desc limit 1;

select count(*) from public.proposal_slots
 where proposal_id = (select id from public.proposals order by created_at desc limit 1);
```

- [ ] One proposal, with the window you asked for.
- [ ] **At most 5 slots.** The client asks for 5; the function caps at 20.

## If it fails

- Results include this Saturday: either the seed didn't run, or find-slots wasn't
  redeployed. Re-run the seed, then `npx supabase functions deploy find-slots`.
- "The scheduler failed (404)": the function isn't deployed.
- No results at all: check `select count(*) from public.busy_blocks;`
