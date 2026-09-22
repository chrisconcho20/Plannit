# plannittogether.com

The public surfaces Plannit needs outside the app: what the product is, the
privacy policy the App Store requires, a support page reviewers look for, and
the Apple App Site Association file that lets invite links open the app.

Static HTML with one stylesheet. No build step, no framework, no JavaScript.

| File | Purpose |
|---|---|
| `index.html` | What Plannit is, and the fallback for an invite link opened without the app |
| `privacy.html` | Privacy policy — required for App Store review, and linked from the listing |
| `support.html` | Support URL — also required by App Store Connect |
| `styles.css` | Design-system colours and type, copied as plain CSS |
| `.well-known/apple-app-site-association` | Declares that `/invite/*` belongs to the app (Universal Links) |
| `_headers` | Serves the association file as `application/json`, which Apple requires |
| `_redirects` | Sends `/invite/<token>` to the invite Edge Function for anyone without the app |

## Deploying

Cloudflare Pages, since the domain's DNS is already there and the free tier
covers this entirely.

1. Cloudflare dashboard → **Workers & Pages → Create → Pages → Connect to Git**
2. Select the `Plannit` repository
3. Build settings: **no framework preset**, leave the build command empty, set
   the output directory to `web`
4. Deploy, then **Custom domains → Set up a domain** → `plannittogether.com`

Pushes to `main` redeploy the site.

## Email addresses

The pages publish `privacy@plannittogether.com` and
`support@plannittogether.com`. Cloudflare **Email Routing** (free) forwards both
to a real inbox without hosting a mail server; it coexists with the Resend
records already on the sending subdomain.

## Universal Links

Both halves are in place since 2026-09-22: the association file here, and
`applinks:plannittogether.com` in `ios/Plannit/App/Plannit.entitlements`. The app
shares invite links as `https://plannittogether.com/invite/<token>`, so iOS opens
the app directly and `_redirects` serves everyone else the invite page.

iOS fetches the association file **when the app is installed**, so the site has
to be deployed before the build that carries the entitlement is installed. If a
link opens Safari instead of the app, reinstall from TestFlight — that is what
makes iOS look again.
