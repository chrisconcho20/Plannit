# 13 — Live updates (two accounts)

**Tests:** whether two people see each other act, via Broadcast, with polling as
the safety net.
**Needs:** 06. Also `supabase db push` (0006).
**Time:** 10 minutes.

You need **two accounts side by side**. Easiest is two simulators: in Xcode,
pick a different simulator model and run again, so both stay open. Alternatively
use the live Appetize preview in a browser as the second one.

---

1. **Simulator A: launch the app and sign in as yourself.**

2. **Simulator B: launch and sign in as** `maya@plannit.test`.

3. **Both: open the same plan.** A finds it under "You're going" in Plans;
   B finds it under "Are you in?".
   - [ ] Both show the same date and the same going count.

4. **On B (Maya), tap Going.**
   - [ ] **On A, the going count rises within a second or two**, with no
         interaction.
   - [ ] A's console shows `sync realtime: joined group topic` from earlier, and
         the events refresh.
   - [ ] B's own row moves to "You're going" **instantly** (before the network).

5. **On B, open the event and tap Remove → Remove from my calendar.**
   - [ ] B's calendar loses it immediately.
   - [ ] A's going count comes back **down** on its own.

6. **On A, delete the plan** (open it, ⋯ → Delete event).
   - [ ] It disappears from B's group and calendar without B doing anything.

7. **On A, share an event with a group Maya is in.**
   - [ ] It appears on B's calendar without B doing anything.

8. **Background simulator B for a minute** (press Home), then return to it.
   - [ ] It catches up immediately. The socket is dropped on background by
         design; the foreground reconcile covers it.

9. **Turn the Mac's wi-fi off, answer an invitation on B, turn it back on.**
   - [ ] The row moved when you tapped, then **reverted** with an error when the
         write failed. An answer that didn't reach the server must not keep
         looking like it did.

---

## How to tell which mechanism is working

- Updates arriving in **1-2 seconds**: Broadcast is working.
- Updates arriving in **10-30 seconds**: the socket isn't connecting and the
  polling fallback is carrying it. The app still works, but tell me. Check 0006
  is applied and that the channel is private.
- Updates only on pull-to-refresh: both mechanisms are down. Paste A's console.

## If it fails

- Nothing arrives at all: `select proname from pg_proc where proname = 'topic_group_id';`
  If that's empty, 0006 isn't applied.
