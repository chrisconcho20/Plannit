# Monetization Plan

_Drafted 2026-10-08. Status: **proposal** — not yet accepted into
[`decisions.md`](decisions.md). Prices and partner terms below come from
third-party sources and must be re-checked before anything ships._

Plannit's stated goal is venture scale: grow the network first and build
revenue that grows with it, rather than optimise early for a small profit. This
document sets out what stays free, which revenue streams fit the product, the
order to introduce them, and the measurements that decide when each one starts.

## 1. Constraints

**Free forever.** These three stay free with no caps. They are the product's
reason to exist and the source of its network effects; charging for them would
slow growth.

- Finding a date (the `find-slots` scheduler and the date-finder UI, at any
  search window).
- Group size and group count.
- Two-way device calendar sync.

**Privacy commitments already made.** The current App Store privacy answers
([`app-store-privacy.md`](app-store-privacy.md)) state that no data is used for
tracking or advertising, and D-17 keeps device event details on the device. Any
revenue stream that changes either answer is a product decision, not just a
billing change. It has to be made explicitly, with the privacy label and the
permission-prompt wording updated in the same release.

**Never:** sell or share individual-level data, show third-party ad-network
ads, or gate value behind inviting friends (the most-cited complaint about
Howbout; see [`market-research.md`](market-research.md)).

## 2. What comparable apps do

| App | Core product | How it makes money |
|---|---|---|
| Howbout | Free shared social calendar; ~$8M Series A (Goodwater, 2024) | **Howbout+** subscription: widgets, themes, event colours, multi-add, scan-to-plan. Personal extras only; group features stay free. Price varies by country and isn't published. |
| TimeTree | Free shared calendar | Ads in the free tier since 2017, plus **Premium** (2022, launched at $4.49/mo or $44.99/yr) to remove ads, with a few extra views added later. It also sells date-targeted ad packages to brands. |
| Partiful | Free event invites; $20M Series A (a16z, Nov 2022) | No ads and no subscription. Revenue comes from **commerce add-ons attached to an event**, such as group grocery orders through Instacart with a delivery fee and a take rate. |
| Doodle | Scheduling polls | Ads on the free tier, plus a **Pro** plan to remove them. Reported 2026 prices range from about $7 to $15 a month, and the sources disagree. |

Two things to take from this. First, the social calendars that have raised
money keep group features free and charge individuals for personal extras.
Second, the most venture-shaped model in the set (Partiful's) earns money at the
moment a plan turns into spending, not from the calendar itself.

## 3. The arithmetic of subscriptions alone

The figures below are an inference built from the sources in section 9.

- Freemium consumer apps convert about **2%** of users to paid. Adapty reports a
  2.18% median, and other sources give 2–5%, or 1–3% for consumer utilities.
- At roughly **$30 a year** and Apple's 15% Small Business Program rate, each
  subscriber is worth about **$25 a year**. Averaged over everyone, that is
  about **$0.50 per monthly active user per year**.
- Infrastructure costs well under **$0.01 per user per month** at 100k MAU (an
  estimated $150–400 a month in [`cost-analysis.md`](cost-analysis.md)).
  A subscription therefore covers hosting from the first few hundred
  subscribers.

| MAU | Subscribers at 2% | Net subscription revenue / yr |
|---:|---:|---:|
| 10,000 | 200 | ~$5k |
| 100,000 | 2,000 | ~$50k |
| 1,000,000 | 20,000 | ~$500k |
| 10,000,000 | 200,000 | ~$5M |

A subscription makes Plannit **profitable early**, but it isn't a venture-scale
business by itself. Reaching that scale needs revenue tied to **what groups do
once a date is found**, which is where section 4's commerce and partnership
streams come in.

## 4. Revenue streams

### 4.1 Plannit+ — personal subscription

A subscription for individuals that adds to the free product but never takes
anything away from groups. One person paying must never make the app worse for
the friends who don't pay.

Candidate features, chosen so that none of them touches the free-forever list:

- **Quiet plans, more of them.** Today each person holds one open window. Plus
  would allow several at once, and windows that repeat ("open every Friday
  evening"). _Judgment call:_ quiet plans aren't the date-finder, but they're
  close to it. If gating them feels like gating the core, move them to the free
  tier and lean on the other items.
- **Advanced personal rules.** More than one never-free schedule, a travel
  mode that shifts your hours with your timezone, and per-group rule presets.
- **Home and Lock Screen widgets**, app icons, themes and event colours, which
  are the core of Howbout+.
- **Plan history and insights**, such as "you've seen this group 9 times this
  year" or "longest gap since you met up". These come from data the server
  already holds about confirmed plans, never from device events.
- **Notice when a quiet window expires unmatched.** This is already a
  roadmap gap.

Proposed price, to test: **$3.99 a month or $29.99 a year**, a little under
TimeTree. Offer a free trial; trials convert far better than a plain freemium
upsell (Adapty reports 18–60% depending on trial type).

### 4.2 Plannit for Groups — organiser tier

A paid upgrade that **one organiser buys for a whole group**. The extra value
reaches every member, so it strengthens the network instead of splitting it.
It's aimed at recurring groups: sports teams, clubs, book clubs, faith groups
and school-parent groups.

- Admin roles, and plans that only admins can post.
- Recurring series with per-session RSVPs and attendance history.
- Per-group minimum turnout (already in the backlog, section 4 of
  [`ROADMAP.md`](ROADMAP.md)).
- Collecting dues or splitting costs, if commerce (4.3) is built.

Group size stays uncapped on the free tier. The paid tier sells organisation
tools, not room for more people.

### 4.3 Commerce at the moment a plan is confirmed

This is the venture-scale stream. When a date is confirmed, Plannit knows that
a specific group of people is free together at a specific time, a few days
before they choose what to do. Partiful earns from the same moment.

Phases:

1. **Suggestions with affiliate booking links.** After a plan is confirmed,
   offer "find a table", "find tickets" and similar actions that deep-link to
   booking partners. Reported affiliate terms are small: OpenTable about
   $0.25–1.00 per seated diner, Ticketmaster about 1–4% of the order, both from
   unverified aggregators. This phase tests intent, not income.
2. **Booking inside the plan.** The group books and, where possible, pays
   together inside the plan, as Partiful's group order does. The take rate is
   negotiated directly with partners rather than set by public affiliate rates.
3. **Venue offers.** Venues pay to put an offer in front of groups that are
   already confirmed for a time and area. Venues see only aggregates and never
   who is in a group. This is a two-sided marketplace and needs real density in
   a city before venues will pay.

What it costs. Venue data isn't free: Google Places (New) charges about
$32 per 1,000 searches after a monthly free allowance, and Yelp's API is paid
only. Commerce therefore needs per-request cost tracking in
[`scaling.md`](scaling.md) from the day it is built.

Privacy. Phase 1 needs no change to the privacy label, provided the links carry
no user identifier. Phases 2 and 3 share purchase data with partners and would
change the label. A venue offer uses a confirmed plan's time and area, which
are facts the group has shared with Plannit, never device calendar contents.

### 4.4 Sponsored suggestions — restricted form of advertising

Ads were considered. **Third-party ad networks are ruled out**: they would add
tracking, an App Tracking Transparency prompt and a changed privacy label to a
product whose wedge includes privacy. They are also low-yield at this scale (one
2026 estimate puts native ads at about $2.50–3.80 per 1,000 impressions).

What's left is **first-party sponsored placements**: a labelled venue or event
shown among the suggestions in 4.3, sold directly, targeted only by the plan's
time and area, with no ad SDK. This is phase 3 of commerce under another name.
It isn't a separate stream and doesn't come before commerce.

## 5. Order and timing

Each stage starts when its gate is met, not on a date. The gate numbers are
proposals to be set once real retention data exists.

| Stage | Starts when | Turns on | Why then |
|---|---|---|---|
| **0. Before launch** (now) | — | The free-forever promise published on the website and in the App Store listing. Server-side counts of the key metrics (section 6). Purchase infrastructure (StoreKit 2 and an Edge Function for App Store Server Notifications). | Promising what stays free before anyone pays means no feature is ever taken away later. |
| **1. Launch** | App Store approval | **Plannit+** with personal extras only, plus a trial. | It touches no group feature, so it can't slow growth. It produces willingness-to-pay data that investors ask for, and it covers hosting early. |
| **2. Traction** | e.g. ≥1,000 weekly active groups and D30 retention ≥25% | **Plannit for Groups**. Phase 1 of commerce: affiliate links, which tests intent. | Organiser features only matter once groups are recurring, and booking clicks show which categories to build into next. |
| **3. Density** | e.g. ≥X confirmed plans a week in one city | Phases 2–3 of commerce: booking inside the plan, then venue offers in that city first. | A marketplace needs both sides. Venues pay only where plans are dense. |

Fundraising is planned for after traction, between stages 2 and 3. Until
then, Plannit is funded by its own revenue. A round raised on retention and
plan-confirmation numbers, with stages 1–2 showing that people will pay, funds
the partnership work in stage 3, which needs people more than code.

Growth before the raise is community-led and organic, with no paid
acquisition. The order of rollout depends on that. Stage 2's organiser tier is
aimed at the people who run communities, and each community brought on becomes
a candidate for the density stage 3 needs.

## 6. Metrics to measure from stage 0

These come from server-side counts over existing tables, so no analytics SDK and
no change to the privacy label are needed.

- **Weekly active groups**: groups with at least one plan created, voted on or
  RSVP'd that week. This is the headline growth number.
- **Confirmed plans per week**, and the median time from creating a plan to
  confirming it. This is the wedge's own metric.
- **D7 and D30 retention** by sign-up week.
- **Invites sent and accepted per active user.** This is the viral loop.
- After stage 1: trial starts, trial-to-paid conversion, and churn.
- After stage 2: booking clicks per confirmed plan, by category.

## 7. Engineering consequences

- **Purchases.** Use StoreKit 2 on the device and verify on the server: App
  Store Server Notifications V2 go to a Supabase Edge Function, which writes an
  `entitlements` row that RLS exposes to its owner. A hosted service such as
  RevenueCat is the alternative, but it adds a third party to the privacy label.
- **Enrol in the App Store Small Business Program** before the first sale. It
  gives a 15% commission instead of 30% for developers under $1M in proceeds a
  year, and the developer has to apply for it. Re-check the exact terms on
  Apple's page; it couldn't be fetched when this was drafted.
- The Paid Apps Agreement, banking and tax forms in App Store Connect must be
  complete before any in-app purchase can be tested in TestFlight.
- **Android** is planned but not scheduled. Howbout and TimeTree ship on both
  platforms, and an iOS-only app loses the members of a friend group who use
  Android. Until an Android app exists, the non-user web link (D-14) is how
  those members take part. Plannit+ will need a Google Play Billing
  counterpart, and the `entitlements` table should be platform-neutral from the
  start so both stores write to it.

## 8. Open questions

- What the stage 2 and stage 3 gate numbers should be, once there are about two
  months of post-launch retention data.
- Whether quiet plans belong in Plannit+ or in the free core (see 4.1).
- Which community to start with: which kind of group (sports, school
  parents, clubs, faith groups) and where.
- When Android ships relative to the raise.

Settled 2026-10-08: outside money is raised after traction, not before. Growth
until then is community-led. Android is in scope eventually.

## 9. Sources

Retrieved 2026-10-08. Most commercial figures come from third-party aggregators
and disagree with each other. They are directional only.

- Howbout+ features: https://howbout.app/get-help/what-is-howbout/
- Howbout funding: https://www.eu-startups.com/?p=236632 ,
  https://tech.eu/2022/11/02/a-ps192-million-raise-for-social-planning-app-howbout-that ,
  https://www.cbinsights.com/company/howbout/financials (totals range from $3.5M to $18M across trackers)
- TimeTree Premium launch: https://timetreeapp.com/intl/en/newsroom/2022-04-19/timetree-premium
- Partiful funding and commerce: https://www.vcbacked.co/company/partiful ,
  https://gappsy.com/tools/partiful/
- Doodle pricing (sources disagree): https://koalendar.com/blog/doodle-pricing ,
  https://costbench.com/changelog/doodle-price-increase-2026-02/
- Freemium conversion: https://adapty.io/state-of-in-app-subscriptions/ ,
  https://www.bolderapps.com/blog-posts/freemium-app-economics-2026 ,
  https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026.md
- Apple Small Business Program: https://developer.apple.com/app-store/small-business-program/ ,
  https://9to5mac.com/2020/11/18/app-store-small-business-program/
- Affiliate terms (unverified): https://uppromote.com/affiliate-directory/opentable/ ,
  https://www.travelpayouts.com/en/offers/ticketmaster-affiliate-program
- Ad yield: https://www.monetizemore.com/blog/how-much-ad-revenue-can-apps-generate/
- Venue data APIs: https://openplacesapi.com/blog/google-places-api-pricing ,
  https://appdevelopermagazine.com/yelp-fusion-api-outrageous-new-pricing/
