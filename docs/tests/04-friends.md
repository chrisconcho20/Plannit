# 04 — Friends

**Tests:** the friends list, adding by email, requests, removing.
**Needs:** 01.
**Time:** 5 minutes.

While the beta's auto-friend switch is on, everyone is already your friend, so
the request flow is mostly dormant. Step 6 turns it off briefly to test the real
path. Remember to turn it back on.

---

1. **Launch the app, go to You, tap Friends.**
   - [ ] The five seeded people are listed.
   - [ ] A note at the bottom explains everyone who joins is added automatically.

2. **Tap "Add a friend".** Type an email that has no account
   (`nobody@example.com`), tap **Find them**.
   - [ ] "No Plannit account with that email."
   - [ ] It gives no hint about whether the address exists anywhere.

3. **Type a seeded user's email** (`maya@plannit.test`), Find them.
   - [ ] "You're already friends."

4. **Close the sheet. Tap the X next to Sam Roe, choose Remove friend.**
   - [ ] Sam disappears from the list.
   - [ ] The confirmation said they stay in any groups you share.

5. **Open a group Sam was in.**
   - [ ] Sam is **still a member**. Unfriending is not kicking.

6. **Test a real request.** In the SQL editor:

   ```sql
   update public.app_config set value = 'false' where key = 'auto_friend_everyone';
   ```

   Then in the app: **You, Friends, Add a friend,** `sam@plannit.test`,
   Find them, **Send request**.
   - [ ] "Request sent to Sam Roe."
   - [ ] Sam appears under **Asked** with a "Waiting" badge.
   - [ ] The beta note at the bottom is **gone**. The app read the flag.

7. **Turn the switch back on:**

   ```sql
   update public.app_config set value = 'true' where key = 'auto_friend_everyone';
   ```

   - [ ] Pull to refresh in the app. The note returns.

---

## Verify in the database

```sql
select status, count(*) from public.friendships group by status;
```

- [ ] There's a `pending` row from step 6.

## If it fails

- Friends list empty: check `select * from public.app_config;` returns a row. If
  it doesn't, migration 0005 isn't applied.
- "Couldn't send that request": paste the console line.
