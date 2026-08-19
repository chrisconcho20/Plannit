# 12 — Activity feed

**Tests:** the feed, the unread dot, and what it does and doesn't show you.
**Needs:** 06. Also `supabase db push` (0008).
**Time:** 5 minutes.

The rule the feed follows: it never tells you what **you** just did, with one
exception — a plan being locked in, because the organiser is exactly who wants
to know.

---

1. **Launch the app, go to the Plans tab.**
   - [ ] There's a **bell** icon in the top right.
   - [ ] If anything has happened since you last looked, it has a small orange dot.

2. **Tap the bell.**
   - [ ] A list of things that happened, newest first.
   - [ ] Each row has an icon, a sentence, where it happened, and a relative time
         ("2h ago").

3. **Read the entries.**
   - [ ] You see plans **other people** created, votes **other people** cast, and
         events **other people** shared.
   - [ ] You do **not** see your own votes or your own new plans echoed back.
   - [ ] You **do** see "<plan> is locked in" for a plan you locked in yourself.

4. **Go back to Plans.**
   - [ ] The orange dot is **gone**. Opening the screen is what marks it seen.

5. **Have something happen.** Sign in as `maya@plannit.test` in a second
   simulator (or sign out and back in as her), vote on a plan, then return to
   your own account.
   - [ ] Maya's vote appears in your feed.
   - [ ] The bell's dot is back.

6. **Pull the activity list down to refresh.**
   - [ ] It reloads without emptying the screen first.

7. **Leave the screen open for half a minute.**
   - [ ] It refreshes on its own (every 30s) without you doing anything.

---

## Verify in the database

```sql
select kind, actor_name, title, happened_at from public.my_activity(20);
```

Run that in the SQL editor and it will return **nothing** — that's expected, not
a failure. The function scopes everything to `auth.uid()`, and the SQL editor has
no signed-in user. The app is the only place it returns rows.

## If it fails

- The feed is empty in the app but things have definitely happened: check 0008 is
  applied (`select proname from pg_proc where proname = 'my_activity';`).
- You see your own actions listed: tell me which kind.
- A brand-new account sees a wall of old "joined" entries: tell me. There's a
  filter meant to prevent exactly that.
