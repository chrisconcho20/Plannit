# 11 — Invite links

**Tests:** creating a link, the public landing page, redeeming, expiry rules.
**Needs:** 03. Also `supabase db push` (0007) and `functions deploy invite`.
**Time:** 10 minutes.

---

1. **Launch the app, open a group you own, scroll down, tap "Invite with a link".**
   - [ ] The button becomes "Share invite link" once the link is made.

2. **Tap "Share invite link".**
   - [ ] The system share sheet appears with an **https** link (not `plannit://`).
   - [ ] Copy it to the clipboard.

3. **Paste it into a browser on your Mac.**
   - [ ] A page appears naming **who invited you** and **which group**.
   - [ ] There's an "Open in Plannit" button.
   - [ ] It looks like Plannit: cream background, coral button.

4. **Change the last few characters of the token in the URL and reload.**
   - [ ] "This invite has expired or been used up."
   - [ ] It does **not** reveal whether that token ever existed.

5. **Test the deep link.** In a terminal, with the real token:

   ```bash
   xcrun simctl openurl booted "plannit://invite/PASTE_TOKEN_HERE"
   ```

   - [ ] Plannit comes to the front.
   - [ ] A toast says "You're already in <group>" (you're the one who made it).

6. **Now test it as someone else.** Sign out, sign in as `maya@plannit.test`,
   and run the same command.
   - [ ] Toast: "You're in <group>."
   - [ ] The group appears in Maya's Groups tab.
   - [ ] You and Maya are now friends (You, Friends).

7. **Run it a second time as Maya.**
   - [ ] "You're already in <group>."
   - [ ] No second membership is created.

8. **Sign back in as yourself.**

---

## Verify in the database

```sql
select token, uses, max_uses, expires_at from public.invites order by created_at desc limit 3;
```

- [ ] `uses` incremented **only** when Maya actually joined, not when you
      re-opened your own link.
- [ ] The token is long and random, not sequential.

## If it fails

- The browser shows raw JSON or a 401: the function was deployed with JWT
  verification on. Redeploy with
  `npx supabase functions deploy invite --no-verify-jwt`.
- "This invite link is not valid" for a fresh link: check 0007 is applied.
- Nothing happens on the deep link: check the URL scheme is registered
  (`CFBundleURLTypes` in Info.plist) and the app is running.
