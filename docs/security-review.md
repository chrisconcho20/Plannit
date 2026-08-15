# Security review — data exposure

_2026-08-15. A read of the whole repo looking for one thing: ways someone could
see data they shouldn't. Not a general audit — no dependency CVEs, no
availability, no App Store compliance._

**Nothing catastrophic.** No credentials in the repo or its history, RLS is on
every table, and the app logs nothing. The real risk is concentrated in one
place: **the combination of a public preview URL, seeded accounts with a
published password, and beta auto-friending means a stranger with a link can be
inside your data in about thirty seconds.** That's finding 1, and it matters
before anyone else's calendar goes in.

Fixed in this pass: 1 (partly), 4, 6. The rest are documented with a
recommendation, because the fixes carry more risk than the findings do.

---

## 1. A stranger with the preview link can sign in as a test user — HIGH

Three safe-on-their-own things combine:

1. `supabase/seed-test-users.sql` created five accounts with the password
   `plannit123`, written in a file in the repo.
2. `ios-appetize-live.yml` builds the app against the **live** Supabase project
   and publishes it at a stable, unauthenticated URL that's in several docs.
3. Those accounts are auto-friended to everyone and added to every group you own.

So anyone with the preview URL could open it, sign in as `maya@plannit.test`,
and read your groups, your shared events (titles, places, times), your plans and
everyone's display names. No exploit required — it's the front door.

**Fixed:** the password is now a `test_password` variable defaulting to
`change-me-before-sharing`, and re-running the seed rotates it, which is how you
revoke a leak.

**Still yours to do:**
- Set a private `test_password` and re-run the seed. `plannit123` should be
  treated as burned.
- Decide what the live preview is for. It runs against real data with real
  accounts; treat that URL as a credential, or point the preview at a separate
  Supabase project.
- Turn `auto_friend_everyone` off before anyone outside your circle has an
  account (see 2).

## 2. Anyone who signs up sees every user's name — MEDIUM (by design, for now)

Sign-up is open, and `auto_friend_everyone` makes each new account friends with
everyone, so `my_friends()` returns the entire user table's display names. That's
the beta behaviour you asked for and it's fine among people you know — but
combined with open sign-up and a public preview URL, "everyone" isn't a set you
control any more.

**Recommendation:** flip the flag off the day a real tester joins:
`update public.app_config set value = 'false' where key = 'auto_friend_everyone';`
Existing friendships survive it.

## 3. `find-slots` could hand over a member's whole free/busy grid — MEDIUM → fixed

Every returned slot carries `availableUserIds`, and nothing bounded the request.
A group member could ask for `maxResults: 100000`, `quorum: 1`,
`stepMinutes: 5` over a year and reconstruct every other member's complete
free/busy calendar at five-minute resolution in one call — while the API
contract describes this data as "aggregate only".

It's within the product's promise (free/busy is what's shared) but far beyond
what a plan being made needs.

**Fixed:** the function now clamps `maxResults` to 20, `stepMinutes` to ≥ 15 and
the window to ~13 months, server-side, before the scheduler sees them. Also
caps the CPU one request can burn.

## 4. Relationship oracles on the RLS helpers — LOW, not fixed

`are_friends(a, b)`, `shares_group(a, b)`, `is_group_member(group, user)`,
`can_view_event(event, user)`, `is_event_owner(event, user)` and
`is_proposal_group_member(proposal, user)` are `SECURITY DEFINER`, take
arbitrary ids, and are executable by any authenticated user (0002 grants execute
on all functions). So a signed-in user can ask "are these two people friends?"
about anyone whose id they know — and with beta auto-friending, they know
everyone's id.

**Why it isn't fixed here:** [policy expressions run with the privileges of the
invoking user](https://www.postgresql.org/docs/current/ddl-rowsecurity.html), so
revoking EXECUTE would break RLS for every table that uses these — the app would
stop working. The correct fix is to narrow the signatures so you can only ask
about yourself (`are_friends_with(other)` using `auth.uid()` internally), which
means rewriting the policies in 0002 and updating `find-slots`, which calls
`is_group_member(p_group, p_user)` directly. That's a migration I can't test
against a database from here, and a mistake in it locks everyone out. Worth
doing deliberately, not as a footnote to a review.

## 5. Email existence oracle — LOW, accepted

`find_profile_by_email` tells any authenticated caller whether a given email has
a Plannit account, with no rate limit, and returns the display name. That's the
deliberate trade for being able to add a friend at all, and it's what most apps
do — but it does mean the account list is testable if you can guess emails.
Invite links (0007) reduce how often anyone needs it.

## 6. Invite tokens travel in a query string — LOW → mitigated

`/functions/v1/invite?t=<token>` puts a live credential in a URL, which lands in
Supabase's Edge Function request logs and in browser history. The token is ~244
bits so guessing is out, but anyone with log access could replay one.

**Mitigated:** tokens expire in 14 days, cap at 25 uses, are burned only by a
real join, stop working when the person who made them leaves the group, and can
be revoked by the group owner. A POST-based exchange would be better if invites
ever carry more weight.

## 7. Refresh token in UserDefaults on unsigned builds — LOW, documented

`Keychain.swift` falls back to `UserDefaults` when the Keychain returns
`errSecMissingEntitlement`, which happens only in an app built without
entitlements — CI and the unsigned simulator builds Appetize runs. On any signed
build (including a free personal team on a real phone) it never triggers. It's
the difference between "the preview can't stay signed in" and "a refresh token
sits in a plist on a simulator nobody owns", and I took the trade knowingly.

## What I checked and found clean

- **No secrets in the repo or its git history** — no JWTs, service-role keys or
  `.p8` files, ever committed. `Info.plist`'s Supabase keys are empty on `main`;
  live credentials are injected at build time from GitHub secrets.
- **RLS is enabled on all 13 tables.** This matters more than usual here: 0002
  grants blanket table access to `authenticated`, so RLS is the *only* gate — a
  future table created without it would be world-readable to any signed-in user.
  Worth a checklist item on every migration.
- **The invite landing page escapes everything.** Group and inviter names go
  through an HTML escaper before they reach the page or the Open Graph tags, so
  a group named `<script>…` can't run anywhere.
- **`send-push` is not publicly callable** despite `verify_jwt = false` — it
  requires `x-internal-secret` and returns 403 without it.
- **The client logs nothing.** No `print`, `NSLog` or `dump` anywhere in the app,
  so no tokens or event titles in the device console.
- **CI never echoes a secret** — the only mentions are error messages naming the
  missing variable.
- **`busy_blocks` is owner-only**, and raw device events are never uploaded at
  all (decision D-17), so event titles genuinely don't leave the phone.
- **Realtime broadcasts carry a hint, not a row** — `{"kind":"proposals"}` — so
  no event or vote detail crosses the socket, and the topic is authorised by
  group membership.
- **The anon key in the published Appetize build is not a leak.** It's designed
  to ship in clients; RLS is what protects the data. It does mean the preview
  build can reach your live project, which is finding 1's real substance.

## If you do one thing

Rotate `test_password`, re-run the seed, and treat the live preview URL as a
credential until the app is pointed at a project with no real data in it.
