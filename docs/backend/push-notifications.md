# Push Notifications (APNs)

Token-based APNs (ES256 provider JWT) via the `send-push` Edge Function. No
certificates, no external libraries.

## Pieces

| Piece | Where |
|---|---|
| Device token storage | `public.device_tokens` (migration `0003`) |
| APNs signer + sender | `supabase/functions/_shared/apns.ts` |
| Internal send endpoint | `supabase/functions/send-push/index.ts` |
| Example trigger | `find-slots` fires a "date found" push to the group |

## Client responsibilities (iOS) — built 2026-09-21

`Services/PushNotifications.swift` (`PushService`), with `AppDelegate` in
`PlannitApp.swift` because APNs hands the token to the delegate and nowhere else.

1. `start()` at launch sets the notification delegate and re-registers silently
   if permission was already granted.
2. `requestAuthorization()` asks, which is what a notification switch in You does
   the first time it is turned on.
3. `syncToken()` upserts the row on `token`: user, token, environment
   (`sandbox` in a debug build, `production` otherwise) and the two category
   preferences.
4. Taps set `PushService.destination`, and `RootView` selects the tab that
   subject lives on. Landing on the exact group or plan needs a navigation path
   the app does not have yet.
5. Sign-out deletes the row **before** the session is dropped, so the next
   person on the phone inherits nothing.

## Per-device preferences (0026)

`device_tokens.notify_date_found` and `notify_invites` mirror the two switches
under You → Notifications. `notify_push()` and `send-push` take a `category`
(`date_found` | `invites`) and skip devices that turned it off — the push is
never sent, rather than sent and dropped. A category with no column reaches
every device. Both default to true, so devices registered before 0026 keep
receiving what they were promised.

The third switch, **Share availability**, is not a notification: off clears the
busy blocks already uploaded and stops further uploads, so the date finder
reports "couldn't check" for that person rather than treating them as free.

## Sending (server-to-server only)

`send-push` is **not** client-callable. It requires the header
`x-internal-secret: <INTERNAL_FUNCTION_SECRET>` and is invoked by:

- **Other Edge Functions** — e.g. `find-slots` after a proposal is created.
- **Database webhooks** — a Supabase webhook / `pg_net` call on
  `insert into event_shares`, `insert into proposals`, friend requests, etc.

Request body:
```jsonc
{
  "userIds": ["…"],            // resolved to device tokens server-side
  "deviceTokens": ["…"],       // optional explicit tokens
  "notification": {
    "title": "Plannit found a date",
    "body": "\"Weekend hang\" — 3 options to vote on",
    "data": { "proposalId": "…", "groupId": "…" },
    "collapseId": "proposal-…"
  }
}
```

Response: `{ "sent": <count>, "results": [{ deviceToken, status, reason }] }`.
Tokens APNs reports as `410 / BadDeviceToken / Unregistered` are auto-pruned.

## Secrets (never committed)

`supabase secrets set` — `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`
(contents of the `.p8`), `APNS_BUNDLE_ID`, `APNS_ENV` (`sandbox`|`production`),
and `INTERNAL_FUNCTION_SECRET` (any long random string shared with callers).

## Notification catalog

| Event | Recipients | Deep link | Where |
|---|---|---|---|
| A date was found (proposal created) | group members except creator | proposal | `find-slots` function (`date_found`) |
| Event shared to a group / user | group (minus owner) or target user | event | trigger (`0004`, `invites`) |
| Friend request sent | addressee | friends | trigger (`0004`, `invites`) |
| Friend request accepted | requester | friends | trigger (`0004`, `invites`) |
| Proposal finalized | all group members | proposal | trigger (`0004`, `date_found`) |
| New vote cast | proposal creator | proposal | _not yet — would be noisy; add if wanted_ |

Triggers fire via `pg_net` (async) and read `internal_function_secret` +
`functions_base_url` from Vault — see the runbook. If Vault isn't configured the
triggers no-op, so they never block a write.
