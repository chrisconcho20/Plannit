# 04 — Friends

**Tests:** the friends list, your friend code, adding by `username#code`,
requests, removing.
**Needs:** 01, and `supabase db push` (0019).
**Time:** 5 minutes.

Seeded users' codes are random. Look them up first:

```sql
select display_name, friend_code from public.profiles order by display_name;
```

While the beta's auto-friend switch is on, everyone is already your friend, so
the request flow is mostly dormant. Step 6 turns it off briefly to test the real
path. Remember to turn it back on.

---

1. **Launch the app and go to the You tab.**
   - [ ] Your username is shown with `#` and six digits right after it, in a
         smaller, greyer style than the name.
   - [ ] The code appears nowhere else: not in group member lists, the Friends
         list, or the profile editing sheet.

2. **Tap Edit, change your username, save.**
   - [ ] The You tab shows the new username with the **same** six digits.
   - [ ] Typing `#` in the username field does nothing, and the field stops at
         32 characters.

3. **Go to You, tap Friends.**
   - [ ] The five seeded people are listed.
   - [ ] A note at the bottom explains everyone who joins is added automatically.

4. **Tap "Add a friend".** Type `Maya Ellis` with no code, tap **Find them**.
   - [ ] "Add the # and their 6-digit code, like maya#482913." No lookup happens.

5. **Type `Maya Ellis#000000`** (a wrong code), Find them.
   - [ ] "Nobody on Plannit has that username and code."

6. **Type Maya's real handle**, e.g. `maya ellis#` followed by her code from the
   query above (capitals don't matter), Find them.
   - [ ] "You're already friends."

7. **Close the sheet. Tap the X next to Sam Roe, choose Remove friend.**
   - [ ] Sam disappears from the list.
   - [ ] The confirmation said they stay in any groups you share.

8. **Open a group Sam was in.**
   - [ ] Sam is **still a member**. Unfriending is not kicking.

9. **Test a real request.** In the SQL editor:

   ```sql
   update public.app_config set value = 'false' where key = 'auto_friend_everyone';
   ```

   Then in the app: **You, Friends, Add a friend,** `Sam Roe#<Sam's code>`,
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
