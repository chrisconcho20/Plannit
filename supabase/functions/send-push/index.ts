// send-push — internal-only APNs sender.
//
// Invoked server-to-server (from other Edge Functions or DB webhooks), never
// directly by clients. Protected by a shared INTERNAL_FUNCTION_SECRET rather
// than a user JWT, because it can push to any user's devices.
//
// Body: { userIds?: string[], deviceTokens?: string[], category?: string,
//          notification: {...} }
//
// `category` names one of the switches in the app's You tab. Devices that
// turned it off are skipped here, rather than delivering a push the app would
// have to drop. A category nobody has a switch for reaches every device.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { loadApnsConfig, sendApnsPush, type ApnsNotification } from "../_shared/apns.ts";

type PushCategory = "date_found" | "invites";

interface RequestBody {
  userIds?: string[];
  deviceTokens?: string[];
  category?: PushCategory | string | null;
  notification: ApnsNotification;
}

// Which column a category is gated by. Unlisted categories are ungated.
const CATEGORY_COLUMN: Record<string, string> = {
  date_found: "notify_date_found",
  invites: "notify_invites",
};

const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const secret = Deno.env.get("INTERNAL_FUNCTION_SECRET")!;
  if (req.headers.get("x-internal-secret") !== secret) return json({ error: "forbidden" }, 403);

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (!body.notification?.title || !body.notification?.body) {
    return json({ error: "missing_notification" }, 400);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Resolve device tokens from userIds and/or explicit tokens.
  let tokens: string[] = body.deviceTokens ?? [];
  if (body.userIds?.length) {
    let query = admin.from("device_tokens").select("token").in("user_id", body.userIds);
    const column = body.category ? CATEGORY_COLUMN[body.category] : undefined;
    if (column) query = query.eq(column, true);
    const { data, error } = await query;
    if (error) return json({ error: "tokens_lookup_failed", detail: error.message }, 500);
    tokens = tokens.concat((data ?? []).map((r) => r.token as string));
  }
  tokens = [...new Set(tokens)];
  if (!tokens.length) return json({ sent: 0, results: [] });

  const cfg = loadApnsConfig();
  const nowSec = Math.floor(Date.now() / 1000);
  const results = await Promise.all(
    tokens.map((t) => sendApnsPush(cfg, t, body.notification, nowSec)),
  );

  // Prune tokens APNs reports as gone so we stop pushing to dead devices.
  const dead = results
    .filter((r) => r.status === 410 || r.reason === "BadDeviceToken" || r.reason === "Unregistered")
    .map((r) => r.deviceToken);
  if (dead.length) await admin.from("device_tokens").delete().in("token", dead);

  return json({ sent: results.filter((r) => r.status === 200).length, results });
});
