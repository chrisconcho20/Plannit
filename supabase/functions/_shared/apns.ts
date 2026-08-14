// apns.ts — token-based (JWT/ES256) Apple Push Notification helper for Deno.
//
// APNs auth uses a provider token (a short-lived ES256 JWT signed with your
// .p8 key), not certificates. We sign with Web Crypto — no external deps.

export interface ApnsConfig {
  keyId: string;          // the .p8 Key ID
  teamId: string;         // Apple Developer Team ID
  privateKeyPem: string;  // full contents of the AuthKey_XXXX.p8 file
  bundleId: string;       // app bundle id -> apns-topic
  environment: "sandbox" | "production";
}

export interface ApnsNotification {
  title: string;
  body: string;
  data?: Record<string, unknown>; // custom keys merged alongside `aps`
  badge?: number;
  sound?: string;
  collapseId?: string;            // apns-collapse-id (coalesce duplicates)
}

export interface ApnsResult {
  deviceToken: string;
  status: number;
  reason?: string;
}

function b64url(input: ArrayBuffer | Uint8Array | string): string {
  let bytes: Uint8Array;
  if (typeof input === "string") bytes = new TextEncoder().encode(input);
  else if (input instanceof Uint8Array) bytes = input;
  else bytes = new Uint8Array(input);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// Returns the ArrayBuffer itself: TS 5.7 made Uint8Array generic over its
// backing buffer, and only an ArrayBuffer-backed view satisfies BufferSource.
function pemToDer(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "");
  const raw = atob(body);
  const buffer = new ArrayBuffer(raw.length);
  const der = new Uint8Array(buffer);
  for (let i = 0; i < raw.length; i++) der[i] = raw.charCodeAt(i);
  return buffer;
}

// APNs recommends reusing a provider token and refreshing it well under 60 min.
let cached: { token: string; iat: number } | null = null;

export async function buildApnsJwt(cfg: ApnsConfig, nowSec: number): Promise<string> {
  if (cached && nowSec - cached.iat < 50 * 60) return cached.token;

  const header = { alg: "ES256", kid: cfg.keyId };
  const payload = { iss: cfg.teamId, iat: nowSec };
  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(cfg.privateKeyPem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );

  const token = `${signingInput}.${b64url(sig)}`;
  cached = { token, iat: nowSec };
  return token;
}

export async function sendApnsPush(
  cfg: ApnsConfig,
  deviceToken: string,
  n: ApnsNotification,
  nowSec: number,
): Promise<ApnsResult> {
  const jwt = await buildApnsJwt(cfg, nowSec);
  const host = cfg.environment === "sandbox"
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";

  const body = JSON.stringify({
    aps: {
      alert: { title: n.title, body: n.body },
      sound: n.sound ?? "default",
      ...(n.badge != null ? { badge: n.badge } : {}),
    },
    ...(n.data ?? {}),
  });

  const res = await fetch(`https://${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": cfg.bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
      ...(n.collapseId ? { "apns-collapse-id": n.collapseId } : {}),
    },
    body,
  });

  let reason: string | undefined;
  if (res.status !== 200) {
    try {
      reason = (await res.json())?.reason;
    } catch {
      // APNs may return an empty body on some statuses.
    }
  }
  return { deviceToken, status: res.status, reason };
}

export function loadApnsConfig(): ApnsConfig {
  return {
    keyId: Deno.env.get("APNS_KEY_ID")!,
    teamId: Deno.env.get("APNS_TEAM_ID")!,
    privateKeyPem: Deno.env.get("APNS_PRIVATE_KEY")!,
    bundleId: Deno.env.get("APNS_BUNDLE_ID")!,
    environment: (Deno.env.get("APNS_ENV") as "sandbox" | "production") ?? "production",
  };
}
