// invite — the page a non-user lands on when someone texts them an invite link.
//
// SCOPE, deliberately small: this is a landing page and a deep link. It shows
// who invited you and to what, then hands off to `plannit://invite/<token>`,
// which the app redeems with `redeem_invite()` (migration 0007). It is NOT
// decision D-14 — non-user web participation, where someone votes on a plan from
// a browser without ever installing the app. That needs a session model for
// people who have no account and is still unbuilt; nothing here should be read
// as a start on it.
//
// GET /functions/v1/invite?t=<token>
//
// Runs anonymously — the whole point is that the reader has no account — so it
// uses the ANON key and calls `peek_invite`, the one function in the schema
// granted to `anon`. That function returns exactly two strings (group name,
// inviter name) and only for a live invite, so this page cannot be used to probe
// for tokens.
//
// Deploy with JWT verification OFF, or every recipient gets a 401 instead of a
// page. Add to supabase/config.toml:
//
//     [functions.invite]
//     verify_jwt = false

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

// Plannit's palette (ios/Plannit/Theme/Color+Tokens.swift).
const BG = "#FFFBF6";
const INK = "#1A1714";
const PRIMARY = "#F76941";

interface Peek {
  group_name: string;
  inviter_name: string;
  valid: boolean;
}

const esc = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&#39;");

const html = (body: string, status = 200) =>
  new Response(body, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      // These links get pasted into group chats and re-fetched by every
      // previewer that sees them; an invite's validity changes as it's used, so
      // nothing here may be cached.
      "Cache-Control": "no-store",
      "Referrer-Policy": "no-referrer",
      "X-Content-Type-Options": "nosniff",
    },
  });

function page(opts: {
  title: string;
  ogTitle: string;
  ogDescription: string;
  body: string;
}) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${esc(opts.title)}</title>
<meta property="og:type" content="website">
<meta property="og:site_name" content="Plannit">
<meta property="og:title" content="${esc(opts.ogTitle)}">
<meta property="og:description" content="${esc(opts.ogDescription)}">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="${esc(opts.ogTitle)}">
<meta name="twitter:description" content="${esc(opts.ogDescription)}">
<meta name="theme-color" content="${BG}">
<style>
  /* Self-contained: no fonts, no stylesheets, no images. A landing page that
     waits on a CDN is a landing page half of its readers never see. */
  *, *::before, *::after { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; }
  body {
    background: ${BG};
    color: ${INK};
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
                 Helvetica, Arial, sans-serif;
    -webkit-font-smoothing: antialiased;
    line-height: 1.45;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 24px;
  }
  main { width: 100%; max-width: 420px; text-align: center; }
  .mark {
    display: inline-block; font-size: 13px; font-weight: 700;
    letter-spacing: 0.14em; text-transform: uppercase;
    color: ${PRIMARY}; margin-bottom: 28px;
  }
  h1 {
    font-size: 27px; line-height: 1.25; font-weight: 700;
    margin: 0 0 14px; letter-spacing: -0.02em;
  }
  h1 .who { color: ${PRIMARY}; }
  p { margin: 0 0 22px; font-size: 16px; opacity: 0.72; }
  .cta {
    display: block; width: 100%; padding: 17px 20px;
    background: ${PRIMARY}; color: ${BG};
    font-size: 17px; font-weight: 600; text-decoration: none;
    border-radius: 16px;
  }
  .cta:active { opacity: 0.85; }
  .fine { margin: 18px 0 0; font-size: 13px; opacity: 0.5; }
  .card {
    background: rgba(26, 23, 20, 0.04);
    border-radius: 20px; padding: 28px 22px;
  }
</style>
</head>
<body>
<main>
${opts.body}
</main>
</body>
</html>`;
}

function validPage(token: string, inviter: string, group: string) {
  const hasGroup = group.trim().length > 0;
  const headline = hasGroup
    ? `<span class="who">${esc(inviter)}</span> invited you to <strong>${esc(group)}</strong> on Plannit`
    : `<span class="who">${esc(inviter)}</span> wants to plan with you on Plannit`;
  const og = hasGroup
    ? `${inviter} invited you to ${group} on Plannit`
    : `${inviter} wants to plan with you on Plannit`;

  return page({
    title: og,
    ogTitle: og,
    ogDescription:
      "Plannit finds a date everyone can actually make. Tap to join.",
    body: `
  <span class="mark">Plannit</span>
  <h1>${headline}</h1>
  <p>Plannit compares everyone's calendars and finds a date the whole group can
     actually make — without anyone sharing what's in them.</p>
  <a class="cta" href="plannit://invite/${esc(token)}">Open in Plannit</a>
  <p class="fine">Opens the Plannit app if you have it installed.</p>`,
  });
}

// One page for missing, mistyped, expired and exhausted alike. Telling the
// reader which would tell anyone holding a guessed token whether it ever
// existed, and the difference is no use to a person who can't fix it anyway.
const expiredPage = () =>
  page({
    title: "Invite expired · Plannit",
    ogTitle: "This Plannit invite has expired",
    ogDescription: "Ask whoever sent it for a fresh link.",
    body: `
  <span class="mark">Plannit</span>
  <div class="card">
    <h1>This invite has expired or been used up</h1>
    <p style="margin-bottom:0">Ask whoever sent it for a fresh link — invites
       last two weeks.</p>
  </div>`,
  });

// Our own failure, not the reader's. Saying "expired" here would be a lie that
// makes them give up on a perfectly good link.
const troublePage = () =>
  page({
    title: "Something went wrong · Plannit",
    ogTitle: "Plannit invite",
    ogDescription: "Couldn't open this invite just now.",
    body: `
  <span class="mark">Plannit</span>
  <div class="card">
    <h1>We couldn't open this invite</h1>
    <p style="margin-bottom:0">Something went wrong on our side. Try the link
       again in a moment.</p>
  </div>`,
  });

async function peek(token: string): Promise<Peek | null> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/peek_invite`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: ANON_KEY,
      Authorization: `Bearer ${ANON_KEY}`,
    },
    body: JSON.stringify({ p_token: token }),
  });
  if (!res.ok) throw new Error(`peek_invite ${res.status}: ${await res.text()}`);
  const rows = await res.json();
  // peek_invite always returns exactly one row; PostgREST wraps it in an array.
  return Array.isArray(rows) ? (rows[0] ?? null) : (rows as Peek);
}

Deno.serve(async (req) => {
  if (req.method !== "GET" && req.method !== "HEAD") {
    return html(expiredPage(), 405);
  }

  const token = new URL(req.url).searchParams.get("t")?.trim() ?? "";

  // Tokens are 16 random bytes as hex (0007). Anything else can't be one, so
  // answer without troubling the database — this is also what stops the
  // endpoint being used as a general-purpose RPC probe.
  if (!/^[0-9a-f]{32}$/.test(token)) return html(expiredPage(), 404);

  let info: Peek | null;
  try {
    info = await peek(token);
  } catch (err) {
    console.error("peek_invite failed", err);
    return html(troublePage(), 200);
  }

  if (!info?.valid) return html(expiredPage(), 404);

  return html(
    validPage(token, info.inviter_name || "Someone", info.group_name ?? ""),
    200,
  );
});
