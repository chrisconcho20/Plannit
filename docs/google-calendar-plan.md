# Connecting a Google Calendar

_Written 2026-09-27. Scope: what it would take to let someone connect a Google
Calendar and have it behave the way the phone's calendar does today. Read
[`calendar-sync-plan.md`](calendar-sync-plan.md) for how device sync works and
D-17 in [`decisions.md`](decisions.md) for the rule that constrains all of this._

---

## 0. Most of this already works

On iOS, a Google account added under **Settings → Calendar → Accounts** syncs
through CalDAV and its calendars appear in EventKit like any other. Plannit
reads EventKit, so those events are already in the app: they show on the
calendar, they count toward availability, and they can be excluded per calendar
under You → Calendars. Plannit's own plans mirror back into the "Plannit"
calendar on the phone, not into Google.

**Nothing has to be built for that path.** It is worth confirming with a tester
who uses Google Calendar before treating this as a feature request at all: the
likely gap is that people don't know to add the account to iOS, which is a
documentation and onboarding problem, not an integration one.

What the iOS route does not cover:

| Gap | Who hits it |
|---|---|
| Account not added to iOS | Anyone who uses the Google Calendar app instead |
| Plans don't appear in Google Calendar on a laptop | People who live in a browser |
| Availability goes stale while the app is never opened | Rare: a background refresh already runs |
| Android, web | Not platforms Plannit has |

---

## 1. Three readings of "connect Google Calendar"

### A — Guide people to add the account to iOS
No integration. Onboarding gains a line explaining that adding the Google
account to iOS brings those calendars in, and the support page says the same.

### B — Read Google Calendar directly from the app
The app performs its own OAuth, calls the Google Calendar API from the device,
merges those events into the same view and the same availability maths, and
optionally writes Plannit plans into a Google calendar it creates.

Everything stays on the device, so **D-17 holds**: event details still never
reach Plannit's server, and the permission prompt's promise is intact.

### C — Sync Google Calendar on the server
Plannit stores a refresh token per person and syncs from the backend, keeping
availability current with no app running and reflecting changes made anywhere.

**This breaks D-17.** Reading someone's calendar server-side means event
details leave the device by definition, which contradicts
`NSCalendarsFullAccessUsageDescription` ("Event details stay on your device"),
the published privacy policy, and the App Store privacy label. It is a product
decision requiring a new prompt, a new policy and a new label — not a sync
feature. It also makes Plannit a custodian of live Google refresh tokens, which
is a meaningfully larger security surface than anything the app holds today.

---

## 2. Recommendation

**Do A now. Build B only if testers ask for it. Do not do C.**

A costs almost nothing and probably closes most of the gap. B is a real
feature with a real cost, most of it outside the code (§4). C trades the
app's clearest privacy promise for convenience that B already delivers on the
platform Plannit runs on.

---

## 3. What B involves

| Piece | Work |
|---|---|
| OAuth with calendar scope, tokens in the Keychain, refresh handling | 1 session |
| Calendar list, per-calendar opt-out alongside the EventKit list | 1 session |
| Event fetch, paging, `syncToken` incremental updates, recurrence expansion | 2–3 sessions |
| Merge into `DeviceEvent` so one screen shows one truth, and into `Availability` | 1–2 sessions |
| Writing Plannit plans into a Google "Plannit" calendar, keyed like the EventKit mirror | 1–2 sessions |
| Deduplicating an event that arrives through both EventKit and the API | 1 session |
| Failure states: revoked access, expired token, offline, quota | 1 session |
| Tests | 1 session |

**8–12 agent sessions**, plus the testing loops: each behavioural bug needs a
build, an install and a person with a real Google Calendar. Call it a week or
two of evenings, on the pattern the device-calendar work followed.

The deduplication row is the one that looks small and isn't. Someone with the
account added to iOS **and** connected in-app receives every event twice, from
two sources with different identifiers, and matching them by title and time is
the same guess that was rejected for duplicated holiday calendars.

---

## 4. The part that isn't code

**Google OAuth verification.** `calendar.readonly` and `calendar.events` are
**sensitive scopes**: Google reviews the app before any account outside the test
list can grant access. That means a published consent screen, a verified domain,
a privacy policy reachable at that domain, a demonstration video, and a review
that takes days to weeks. `plannittogether.com` and its privacy policy already
exist, which covers part of it.

Sensitive scopes do not require the third-party security assessment that
restricted scopes (Gmail, Drive) do, so there is no CASA audit and no five-figure
cost — but the review is not a formality and it can come back with questions.

**App Store review** will ask why a calendar app needs a second calendar
provider, which is easy to answer, and the privacy label stays as it is under
B, because nothing new leaves the device.

---

## 5. What would have to be decided first

1. **Is this a real gap?** Ask the testers who use Google Calendar whether their
   events already appear. If they do, A is the whole answer.
2. **Does Plannit ever write into Google?** Reading is half the work of reading
   and writing, and a plan already lands on the phone's calendar, which for an
   iOS user is the same calendar.
3. **Is D-17 still absolute?** It is the reason C is refused here. If that ever
   changes it should change deliberately, as a new decision with its own entry,
   not as a consequence of a sync feature.

---

## 6. Sources

- [Choose Google Calendar API scopes](https://developers.google.com/workspace/calendar/api/auth)
- [Sensitive scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)
- [Restricted scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification)
- [OAuth App Verification Help Center](https://support.google.com/cloud/answer/13463073?hl=en)
