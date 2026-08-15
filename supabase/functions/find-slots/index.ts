// find-slots — the scheduler Edge Function.
//
// POST body: { groupId, constraints, title?, maxResults?, persist? }
//  - Authenticates the caller from their JWT and checks group membership (RLS-safe).
//  - Reads ALL members' busy_blocks with the service role (bypassing RLS) so we can
//    compute combined availability without exposing anyone's raw events.
//  - Returns ranked slots, and (unless persist:false) writes a proposal + slots.
//
// Privacy: only the aggregate available_user_ids ever leaves this function.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { findBestSlots, type Constraints, type Member } from "../_shared/scheduler.ts";

interface RequestBody {
  groupId: string;
  constraints: Constraints;
  title?: string;
  maxResults?: number;
  persist?: boolean;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";

  // Caller-scoped client — authenticate and authorize under the caller's identity.
  const asUser = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await asUser.auth.getUser();
  if (userErr || !userData.user) return json({ error: "unauthorized" }, 401);
  const uid = userData.user.id;

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (!body.groupId || !body.constraints) return json({ error: "missing_fields" }, 400);

  // Authorize: caller must belong to the group.
  const { data: isMember, error: authzErr } = await asUser.rpc("is_group_member", {
    p_group: body.groupId,
    p_user: uid,
  });
  if (authzErr) return json({ error: "authz_check_failed", detail: authzErr.message }, 500);
  if (!isMember) return json({ error: "forbidden" }, 403);

  // Service role — read every member's busy blocks in the window.
  const admin = createClient(supabaseUrl, serviceKey);

  const { data: memberRows, error: memErr } = await admin
    .from("group_memberships")
    .select("user_id")
    .eq("group_id", body.groupId);
  if (memErr) return json({ error: "members_failed", detail: memErr.message }, 500);

  const memberIds = (memberRows ?? []).map((r) => r.user_id as string);

  const { data: busyRows, error: busyErr } = await admin
    .from("busy_blocks")
    .select("user_id,start_at,end_at")
    .in("user_id", memberIds)
    .lt("start_at", new Date(Math.min(
        body.constraints.windowEnd,
        body.constraints.windowStart + 400 * 24 * 60 * 60 * 1000)).toISOString())
    .gt("end_at", new Date(body.constraints.windowStart).toISOString());
  if (busyErr) return json({ error: "busy_failed", detail: busyErr.message }, 500);

  const byUser = new Map<string, Member>();
  for (const id of memberIds) byUser.set(id, { userId: id, busy: [] });
  for (const b of busyRows ?? []) {
    byUser.get(b.user_id as string)?.busy.push({
      start: Date.parse(b.start_at as string),
      end: Date.parse(b.end_at as string),
    });
  }

  // Bounds, before we hand anything to the scheduler.
  //
  // Not paranoia: every returned slot carries `availableUserIds`, so an
  // unbounded request (maxResults: 100000, quorum: 1, stepMinutes: 5, a
  // year-long window) would hand a group member every other member's complete
  // free/busy grid in one call. Free/busy is what the product shares — but a
  // slot at a time, for a plan being made, not the whole calendar on demand.
  // These caps also keep one request from pinning the function's CPU.
  const MAX_RESULTS = 20;
  const MAX_WINDOW_MS = 400 * 24 * 60 * 60 * 1000;   // ~13 months
  const MIN_STEP_MINUTES = 15;

  const constraints = {
    ...body.constraints,
    stepMinutes: Math.max(MIN_STEP_MINUTES, body.constraints.stepMinutes ?? 30),
    windowEnd: Math.min(
      body.constraints.windowEnd,
      body.constraints.windowStart + MAX_WINDOW_MS,
    ),
  };
  const maxResults = Math.min(Math.max(1, body.maxResults ?? 10), MAX_RESULTS);

  // Prefers a date the whole group can make; falls back to the best turnout.
  const search = findBestSlots([...byUser.values()], constraints, maxResults);
  const { slots, everyoneFree, memberCount, quorum } = search;

  // Preview mode — compute without persisting.
  if (body.persist === false) return json({ slots, everyoneFree, memberCount, quorum });

  const { data: proposal, error: propErr } = await admin
    .from("proposals")
    .insert({
      group_id: body.groupId,
      created_by: uid,
      title: body.title ?? "",
      constraints,
      window_start: new Date(constraints.windowStart).toISOString(),
      window_end: new Date(constraints.windowEnd).toISOString(),
    })
    .select()
    .single();
  if (propErr) return json({ error: "proposal_failed", detail: propErr.message }, 500);

  if (slots.length) {
    const rows = slots.map((s) => ({
      proposal_id: proposal.id,
      start_at: new Date(s.start).toISOString(),
      end_at: new Date(s.end).toISOString(),
      score: s.score,
      available_user_ids: s.availableUserIds,
    }));
    const { error: slotErr } = await admin.from("proposal_slots").insert(rows);
    if (slotErr) return json({ error: "slots_failed", detail: slotErr.message }, 500);
  }

  // Best-effort: notify the rest of the group that a date was found. Push is
  // never allowed to fail the proposal, so this is fire-and-forget + guarded.
  try {
    const secret = Deno.env.get("INTERNAL_FUNCTION_SECRET");
    if (secret && slots.length) {
      const recipients = memberIds.filter((id) => id !== uid);
      if (recipients.length) {
        await fetch(`${supabaseUrl}/functions/v1/send-push`, {
          method: "POST",
          headers: { "content-type": "application/json", "x-internal-secret": secret },
          body: JSON.stringify({
            userIds: recipients,
            notification: {
              title: "Plannit found a date",
              body: [
                body.title ? `"${body.title}" — ` : "",
                everyoneFree
                  ? `${slots.length} time${slots.length > 1 ? "s" : ""} everyone can make`
                  : `best turnout ${slots[0].score} of ${memberCount} — vote on ${slots.length} option${slots.length > 1 ? "s" : ""}`,
              ].join(""),
              data: { proposalId: proposal.id, groupId: body.groupId },
              collapseId: `proposal-${proposal.id}`,
            },
          }),
        });
      }
    }
  } catch (_) {
    // Swallow push errors — the proposal already succeeded.
  }

  return json({ proposal, slots, everyoneFree, memberCount, quorum });
});
