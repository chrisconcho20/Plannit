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

## Client responsibilities (iOS)

1. Register for remote notifications; obtain the APNs device token.
2. Upsert it into `device_tokens` for the signed-in user (RLS lets a user write
   only their own tokens):
   ```swift
   try await client.from("device_tokens")
     .upsert(["token": apnsToken, "environment": isDebug ? "sandbox" : "production"])
     .execute()
   ```
3. Handle taps — the payload includes `proposalId` / `groupId` for deep-linking.

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

## Notification catalog (planned)

| Event | Recipients | Deep link |
|---|---|---|
| A date was found (proposal created) | group members except creator | proposal |
| Event shared to your group | group members | event |
| Friend request / accepted | the other party | friends |
| New vote / proposal finalized | group members | proposal |

Only the "date found" trigger is wired today; the rest are straightforward
webhook additions.
