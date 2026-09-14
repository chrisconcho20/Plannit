# 01 — First run and sign-up

**Tests:** making an account, the confirmation code, password reset, the
profile trigger, beta auto-friending.
**Needs:** nothing. This is the first thing to run.
**Time:** 10 minutes.

Check **Authentication → Sign In / Providers → Email → Confirm email** in the
Supabase dashboard. Steps marked **(confirmation on)** only apply when it is on,
which also requires custom SMTP — see
[`../backend/auth-setup.md`](../backend/auth-setup.md). With it off, step 6 lands
straight in the app.

---

1. **Launch the app** in the simulator.
   - [ ] The first screen shows the Plannit logo, a black **Continue with Apple**
         button, **Continue with Google**, and a **Sign in / Create account**
         toggle below "or use email". If there's no toggle, you're in demo mode —
         stop and add the Supabase keys to `Info.plist`.

2. **Tap "Create account"** on the toggle.
   - [ ] A **Your name** field appears above Email, and a **Confirm password**
         field appears below Password.
   - [ ] Both password fields have an **eye** icon. Tapping it shows the typed
         text; tapping again hides it. The keyboard stays up.
   - [ ] The subtitle changes to "Make plans that actually happen."

3. **Tap "Create account"** (the button) with all fields empty.
   - [ ] Nothing happens — the button is dimmed and disabled.

4. **Enter a name, an email you control, a 3-character password, and the same
   3 characters to confirm.** Tap Create.
   - [ ] "Use at least 6 characters for the password." appears **immediately**,
         with no network delay.

5. **Change the password to 6+ characters and type a different confirmation.**
   - [ ] Once the confirmation is as long as the password, it gets a red outline
         and "The passwords don't match." appears under it.
   - [ ] Tapping Create shows the same message and sends nothing.

6. **Make the confirmation match.** Tap Create.
   - [ ] **(confirmation off)** You land in the app, on the Calendar tab.
   - [ ] **(confirmation on)** The screen changes to **Check your email** and names
         your address. An email titled "Your Plannit code" arrives with 6 digits.
   - [ ] **(confirmation on)** Enter a wrong code: "That code is wrong or has
         expired" appears. Enter the right one: you land in the app.
   - [ ] Console shows `sync loaded: … groups, … events, … friends`.

7. **Go to the You tab.**
   - [ ] Your **real name** and the **email you signed up with** are shown — not
         "You Concho" or a placeholder.
   - [ ] The app version appears at the bottom.

8. **Tap Profile → Friends.**
   - [ ] Maya Ellis, Theo Sand, Ada Kim, Sam Roe and Jo Vane are already listed.
         (Beta auto-friending — a brand new account is friends with everyone.)
   - [ ] The note at the bottom says everyone who joins is added automatically.

9. **Go back, then to the Groups tab.**
   - [ ] You see the groups the seed put you in, each with a member count.

10. **Sign out:** You → Sign out → confirm.
    - [ ] You're returned to the Sign in screen.
    - [ ] Signing back in with the same email and password works, **without** a
          code.
    - [ ] The Sign in form has one password field (no confirmation) with an eye
          icon.

11. **Force-quit the app** (in the simulator: ⌘⇧H twice, swipe up) **and relaunch.**
    - [ ] You land straight in the app, still signed in — no sign-in screen.

12. **Sign out, then tap "Forgot password?"** Enter your email, tap **Send code**.
    - [ ] **Check your email** appears. An email titled "Your Plannit password
          reset code" arrives (needs custom SMTP for non-team addresses).
    - [ ] Enter the code: **New password** appears with two fields, both with eye
          icons.
    - [ ] Save a new password: you land in the app. Signing out and back in works
          with the new password, and not the old one.

13. **Sign-in providers.**
    - [ ] **Continue with Google** opens a system sheet. Cancelling it returns to
          the sign-in screen with no error. With the Google provider configured,
          finishing it lands you in the app, named from your Google account.
    - [ ] **Continue with Apple** on Appetize or a free-Apple-ID build says Sign in
          with Apple isn't available in this build. On a build with the
          entitlement, it signs in and uses the name Apple provides.

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

- No code email arrives → the project is still on Supabase's built-in sender,
  which only delivers to team members. Set up custom SMTP.
- The email contains a link instead of a code → the dashboard templates haven't
  been replaced with `supabase/templates/*.html`.
- "That email already has an account" → use a different address, or sign in.
- Landed in the app but the You tab shows no email → paste the console lines.
