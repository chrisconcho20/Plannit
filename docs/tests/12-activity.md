# 12 — Activity feed

**Tests:** the feed, the unread dot, and what it does and doesn't show you.
**Needs:** 06. Also `supabase db push` (0008 and 0011).
**Time:** 5 minutes.

The rule the feed follows: **it never tells you what you just did.** Five things
can reach it — someone invited your group to a date, someone said they're going
to a plan of yours, someone shared an event with you personally, someone wants
to be friends, someone joined your group.

---

1. **Launch the app, go to the Plans tab.**
   - [ ] There's a **bell** icon in the top right.
   - [ ] If anything has happened since you last looked, it has a small orange dot.

2. **Tap the bell.**
   - [ ] A list of things that happened, newest first.
   - [ ] Each row has an icon, a sentence, where it happened, and a relative time
         ("2h ago").

3. **Read the entries.**
   - [ ] You see "<someone> wants to plan <title>" for invitations from other
         people, and "<someone> is going to <title>" for answers to your plans.
   - [ ] You do **not** see your own invitations or your own answers echoed back.
   - [ ] You do **not** see anyone's *declines*. Only "going" reaches the feed —
         a feed that announces every no makes saying no expensive.

4. **Go back to Plans.**
   - [ ] The orange dot is **gone**. Opening the screen is what marks it seen.

5. **Have something happen.** Sign in as `maya@plannit.test` in a second
   simulator (or sign out and back in as her), tap **Going** on a plan of yours,
   then return to your own account.
   - [ ] "Maya is going to <plan>" appears in your feed.
   - [ ] The bell's dot is back.
   - [ ] Have Maya **decline** a different plan: nothing appears. That's
         deliberate.

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

- The feed is empty in the app but things have definitely happened: check 0011
  is applied. `select prosrc like '%invited%' from pg_proc where proname =
  'my_activity';` must return `true` — if it's `false` you're still on the 0008
  version, which reads the retired voting tables and will only ever report old
  news.
- You see your own actions listed: tell me which kind.
- A brand-new account sees a wall of old "joined" entries: tell me. There's a
  filter meant to prevent exactly that.
