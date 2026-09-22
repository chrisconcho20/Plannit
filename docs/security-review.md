# Security review — data exposure

_2026-08-15, re-checked 2026-08-23 (see the Regression under finding 1). A read
of the whole repo looking for one thing: ways someone could
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

**Fixed:** the password is now a `test_password` variable, and re-running the
seed rotates it, which is how you revoke a leak.

### Regression, found 2026-08-23 — the fix above did not hold

A working password (`tp20`, four characters) was set in the file and committed,
and the seed was run against the live project with it. For some period, the
public repo contained a valid credential for five accounts sitting inside the
owner's real groups, next to a published link to a build pointed at the real
database. Treat `tp20` as burned.

The lesson is about the shape of the mitigation, not the person: a comment
saying *"CHANGE THIS"* is not a control, because the natural workflow —
edit the file, paste it into the SQL editor — saves the secret back into the
file every time. The seed now **refuses to run** unless `test_password` has been
changed from its placeholder and is at least 16 characters, and the live preview
URL has been removed from `AGENTS.md`, `ROADMAP.md` and `manual-test-plan.md`.
Neither control depends on anyone remembering anything.

What still can't be undone: `tp20` is in git history permanently, as is the live
preview URL. Rotation is the only remedy, and rotation is only complete once the
seed has been re-run with a new password **and** the live Appetize build has been
deleted or rebuilt (its old URL keeps working until you do).

**Resolved 2026-09-15.** The five seeded accounts are deleted from the live
project, `auto_friend_everyone` is off, the project is marked
`app_config.environment = 'production'` so the seed refuses to run there, and
the live Appetize build is deleted (its URL returns 404) along with the workflow
that built it. The burned passwords no longer open anything.

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

## 4. Relationship oracles on the RLS helpers — LOW → fixed (0022)

_2026-09-14:_ worse than described below when checked on the live project: the
helpers were EXECUTE-able by `PUBLIC`, which includes `anon`, so the questions
could be asked with only the publishable key. Migration 0022 moves the checks
into caller-scoped functions in `private` (not exposed by the Data API), drops
`are_friends`, `shares_group`, `can_view_event`, `is_group_owner` and
`is_proposal_group_member`, and narrows `is_group_member`, `is_event_owner` and
`is_event_invitee` to answer only about the caller, callable by `authenticated`
only. Rehearsed on the live project before applying: every table, as seen by
every user, hashed identically under the old and new policies.

The original finding, for the record:

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

## 5. Email existence oracle — LOW → resolved (0019)

`find_profile_by_email` told any authenticated caller whether a given email had
a Plannit account, with no rate limit, and returned the display name.

_2026-09-14:_ dropped. Friends are found by `find_profile_by_handle`, which needs
a username and that account's permanent 6-character code together, so an email
address reveals nothing. What remains is guessing a code for a known username —
about a billion possibilities, still unthrottled; see
[`beta-to-production.md`](beta-to-production.md) §2.

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

## 8. Consent and sharing rules — HIGH → fixed (0024, 2026-09-15)

A second review attempted each of these against the live project as a signed-in
user, in a rolled-back transaction, and all succeeded before 0024:

| | Issue | Severity |
|---|---|---|
| S1 | Anyone could insert themselves into any group whose id they knew, so removing a member didn't hold. | High |
| S2 | A group owner could add any user id, then read that person's free/busy through the date finder. | High |
| S3 | A friendship could be created already accepted, or accepted by the person who sent the request. | High |
| S4 | An event could be shared onto any user's calendar (and so their phone) or into any group. | Medium |
| S5 | Anyone with the publishable key could list the avatars bucket, whose object names are user ids. | Medium |
| S6 | Soft-deleted events stayed readable to everyone they had been shared with. | Low |

0024 limits membership inserts to owners adding themselves or people they're
connected to; requires friendships to start `pending`, lets only the addressee
change the status and revokes UPDATE on every other column; limits shares to
your own groups and connections; replaces the public bucket read with an
owner-only one; and hides tombstones from everyone but the owner. The same
rehearsal confirmed each path now fails with 42501, the app's own flows still
succeed, and what every user can see was otherwise unchanged.

Still open, lower risk: free/busy can be probed through the date finder by a
group's own members (rate limited to 60 searches an hour), invite links are
bearer tokens that can be forwarded, sign-up reveals whether an email is
registered while confirmation is off. The password minimum was 6 and is 8
since 2026-09-22, in `PasswordRules` and in the dashboard.

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

## Before opening sign-up to strangers

Every loosened setting is collected in
[`beta-to-production.md`](beta-to-production.md) — confirmation off,
auto-friending on, the live test accounts, the public preview URL — with what
each has to become.

## If you do one thing

Rotate `test_password`, re-run the seed, and treat the live preview URL as a
credential until the app is pointed at a project with no real data in it.
