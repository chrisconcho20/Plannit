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
import { findSlots, type Constraints, type Member } from "../_shared/scheduler.ts";

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
    .lt("start_at", new Date(body.constraints.windowEnd).toISOString())
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

  const slots = findSlots([...byUser.values()], body.constraints, body.maxResults ?? 10);

  // Preview mode — compute without persisting.
  if (body.persist === false) return json({ slots });

  const { data: proposal, error: propErr } = await admin
    .from("proposals")
    .insert({
      group_id: body.groupId,
      created_by: uid,
      title: body.title ?? "",
      constraints: body.constraints,
      window_start: new Date(body.constraints.windowStart).toISOString(),
      window_end: new Date(body.constraints.windowEnd).toISOString(),
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

  return json({ proposal, slots });
});
