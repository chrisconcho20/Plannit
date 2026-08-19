# 01 — First run and sign-up

**Tests:** making an account, the profile trigger, beta auto-friending.
**Needs:** nothing. This is the first thing to run.
**Time:** 5 minutes.

Before starting, confirm in the Supabase dashboard that **Authentication →
Sign In / Providers → Email → Confirm email** is **off**. With it on, sign-up
cannot complete (the confirmation link points at a deep link, not a web page).

---

1. **Launch the app** in the simulator.
   - [ ] The first screen shows the Plannit logo and a **Sign in / Create account**
         toggle. If it says *Continue with Apple*, you're in demo mode — stop and
         add the Supabase keys to `Info.plist`.

2. **Tap "Create account"** on the toggle.
   - [ ] A **Your name** field appears above Email and Password.
   - [ ] The subtitle changes to "Make plans that actually happen."

3. **Tap "Create account"** (the button) with all fields empty.
   - [ ] Nothing happens — the button is dimmed and disabled.

4. **Enter a name, an email you control, and a 3-character password.** Tap Create.
   - [ ] "Use at least 6 characters for the password." appears **immediately**,
         with no network delay.

5. **Fix the password to 6+ characters.** Tap Create.
   - [ ] You land in the app, on the Calendar tab, within a second or two.
   - [ ] Console shows `sync loaded: … groups, … events, … plans, … friends`.

6. **Go to the You tab.**
   - [ ] Your **real name** and the **email you signed up with** are shown — not
         "You Concho" or a placeholder.
   - [ ] The app version appears at the bottom.

7. **Tap Profile → Friends.**
   - [ ] Maya Ellis, Theo Sand, Ada Kim, Sam Roe and Jo Vane are already listed.
         (Beta auto-friending — a brand new account is friends with everyone.)
   - [ ] The note at the bottom says everyone who joins is added automatically.

8. **Go back, then to the Groups tab.**
   - [ ] You see the groups the seed put you in, each with a member count.

9. **Sign out:** You → Sign out → confirm.
   - [ ] You're returned to the Sign in screen.
   - [ ] Signing back in with the same email and password works.

10. **Force-quit the app** (in the simulator: ⌘⇧H twice, swipe up) **and relaunch.**
    - [ ] You land straight in the app, still signed in — no sign-in screen.

---

## Verify in the database

In the SQL editor:

```sql
select display_name, timezone from public.profiles order by created_at desc limit 3;
select count(*) from public.friendships where status = 'accepted';
```

- [ ] Your new profile has the name you typed and a sensible timezone — the
      trigger built it from the sign-up metadata.
- [ ] The friendship count went up by the number of existing users.

## If it fails

- Stuck on "Check … for a confirmation link" → Confirm email is still on.
- "That email already has an account" → use a different address, or sign in.
- Landed in the app but the You tab shows no email → paste the console lines.
