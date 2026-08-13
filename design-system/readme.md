# Plannit Design System

Plannit is a **native iOS social calendar**. It syncs two-ways with the calendar already on your phone, lets you reveal specific events to specific groups, and — the part no competitor has nailed — **finds a date that works for everyone** from a plain-language constraint like "a weekend afternoon."

The product's own words for its three pillars:

1. **Two-way sync** — the device (Apple) calendar is a first-class citizen; events flow both directions.
2. **Per-group visibility** — one personal calendar; reveal specific events to specific groups (share with Soccer, hide from Family). Enforced in Postgres RLS, not on client trust.
3. **Automated group date-finding (the wedge)** — pick a group, tap the days that could work, get a slot when everyone is free.

Stack, for context on what these designs must be buildable in: Swift + SwiftUI (iOS 17+), EventKit, GRDB, Sign in with Apple, APNs; Supabase (Postgres + Auth + Realtime + Edge Functions + RLS); the scheduler is a sweep-line in a TypeScript Edge Function.

## Sources this system was built from

- **GitHub — [chrisconcho20/Plannit](https://github.com/chrisconcho20/Plannit)** (branch `main`). At the time of writing this repo is **pre-development**: five markdown files, no source code, no assets, no Figma.
  - [`README.md`](https://github.com/chrisconcho20/Plannit/blob/main/README.md) — the three pillars, the strategic bet, the stack.
  - [`docs/market-research.md`](https://github.com/chrisconcho20/Plannit/blob/main/docs/market-research.md) — competitors (Howbout, OurCal, TimeTree, Doodle, When2Meet), what to borrow, what to avoid.
  - [`docs/technical-proposal.md`](https://github.com/chrisconcho20/Plannit/blob/main/docs/technical-proposal.md) — architecture, sync engine, data model, the scheduler, delivery phases.
  - [`docs/decisions.md`](https://github.com/chrisconcho20/Plannit/blob/main/docs/decisions.md) — decision log D-01…D-15 (all Accepted).
  - [`docs/cost-analysis.md`](https://github.com/chrisconcho20/Plannit/blob/main/docs/cost-analysis.md) — infra cost model.
- **Nothing else was provided** — no logo, no fonts, no screenshots, no design file. Read the repo yourself for a fuller picture before making product decisions; the docs are short and worth the ten minutes.

Because there is no prior UI, **this design system is the first visual definition of Plannit**, derived from the product brief and one explicit instruction from the founder: *"I want this app to feel easy to use and inviting for new users."* Everything here is a proposal to react to, not a recreation of shipped screens.

### What is invented vs. sourced

| Sourced from the repo | Invented here (needs your sign-off) |
|---|---|
| Product model: events, groups, per-group shares, busy blocks, proposals, slots, votes | The entire palette (coral "Ember" primary, teal "Free", warm neutrals) |
| Privacy rules — busy blocks only, no titles leave the phone (D-08), private by default (D-09) | Typography (Figtree substituting SF Pro; JetBrains Mono) |
| Flow decisions — Sign in with Apple first (D-03), propose-then-vote (D-12), link-based participation (D-14) | All shape, elevation, motion and layout values |
| Anti-patterns to avoid — no invite walls, no When2Meet-style drag grids | Screen layouts, copy, and the four-tab structure |
| Tone cues — "the wedge", "find a date that works for everyone" | The six group hues and their assignment rule |

---

## CONTENT FUNDAMENTALS

Plannit's voice comes from how the founder writes in the repo: short declaratives, em-dashes, no hedging, no marketing gloss. Product copy carries that plainness and adds warmth, because the brief is "inviting for new users."

**Person.** Talk to the user as **you**. Plannit itself is **we** only when it does work on your behalf ("We'll nudge them", "We found three times"). Never "I". Never "the user".

**Casing.** Sentence case everywhere — buttons, titles, nav, sheet headers, badges. The only uppercase is the 12px section label (`--track-caps`, e.g. `YOUR GROUPS`). No Title Case Buttons, no ALL-CAPS shouting.

**Length.** A screen title is ≤ 5 words. A body line is one sentence. Buttons are 1–3 words and start with a verb: *Find a date · Lock it in · Make a group · Share · Take me in.* Never *Submit*, *Confirm*, *OK*, *Get started*.

**Time is written the way people say it.** `Sat 16 Aug · 2:00–4:00 PM`, `Sun 17 Aug · 1:00 PM`, `10pm – 8am`. Never ISO, never 24h, never "16/08/2026". Relative time for freshness: "Synced a moment ago".

**Numbers are honest and small.** "6 of 6 free", "4 of 6 voted", "2 waiting on the group". No percentages, no fake stats, no progress numbers we can't compute.

**Empty states are the onboarding.** Say what the thing is *for*, then offer exactly one next step:
- ✅ "No groups yet — Groups are how you share the right plans with the right people." + *Make a group*
- ✅ "Nothing on this day — Free all day. Want to see if the others are too?" + *Find a date*
- ❌ "You have no groups." / "No data available."

**Privacy is stated in plain words, repeatedly, without lawyer voice.**
- "Nobody sees your event titles. When we look for a date, your friends only see grey blocks where you're busy."
- "Everyone else keeps seeing a plain busy block — no title, no place."
- "Busy blocks only, no titles."

**Quote the user's own words back to them.** The date-finder is the wedge, so the constraint is echoed verbatim in curly quotes: *You asked for "a weekend afternoon."* Input placeholders are lowercase real examples — `a weekend afternoon`, `Five-a-side at the pitch`, `Sunday runs` — never `Enter a title…`.

**Never gate value.** Howbout's most-cited weakness is its invite wall, so Plannit's copy says the opposite out loud: "Invite a friend — no referral wall, ever." Nothing is ever "unlocked by inviting friends".

**No emoji.** Not in UI, not in empty states, not in notifications — group colour and Lucide glyphs carry that job. (Users' own event titles may contain anything; that's their text, not ours.)

**No exclamation marks** except a genuine celebration, at most one per screen. Warmth comes from short friendly sentences, not punctuation.

**Notification copy** leads with the outcome: "Saturday 2pm works for everyone." / "Ada voted for Sun 17." / "Five-a-side is on your calendar."

---

## VISUAL FOUNDATIONS

The look: **warm paper, one confident coral, teal for "free", and iOS-native shapes**. It should read as a friendly native app, not a web dashboard — no dark chrome, no glassmorphism showpieces, no purple gradients.

### Colour
- **Primary — Ember coral** (`--coral-500 #F76941`, press `--coral-600 #E4501F`). One coral action per screen. Coral is *always* an action or a selection, never decoration and never a status.
- **Free — Teal** (`--teal-500 #14A98F`). Reserved for availability and confirmation: someone is free, a date was found, sync is healthy, a switch is on. Teal never means "primary action" except on the one button that confirms a found date (`variant="free"`).
- **Neutrals are warm** (`--ink-*` toward yellow, `--paper #FFFBF6`). A cool grey (#F5F5F5, #64748B) pasted into Plannit reads as a bug.
- **Six group hues** (`--hue-coral/amber/teal/sky/indigo/rose` + `-soft` tints), assigned round-robin as groups are created. One hue per group, reused everywhere that group appears: chip dot, event tile, day dot, avatar ring, group header tint. Hues are identity, never status.
- **Semantic**: free teal · busy `--ink-300` · success green · warning amber · danger red. Danger is text-and-icon only — Plannit never fills a button red.
- **No gradients** anywhere. Flat fills only; the only multi-stop colour in the system is the scrim.

### Typography
- **Figtree** for everything (400 body, 500 subhead, 600 UI titles, 700 titles, 800 display), **JetBrains Mono** for tokens/specs only. No light weights.
- iOS-derived scale: 11 · 12 · 13 · 15 · 17 · 20 · 22 · 28 · 34 · 44 · 56. **17px is the body floor** — reading text never goes below it; 13px is for meta only.
- Negative tracking as size grows (`--track-hero -.032em` → `--track-body -.006em`). Display sizes are 800 weight, tight (1.08–1.2) line-height; body is 1.5.
- **Tabular numerals** in every calendar surface (month grid, slot dates, times).
- Substitution flagged: the real app would use **SF Pro / SF Pro Rounded**; Figtree is the closest Google Fonts match (see *Open questions*).

### Backgrounds and imagery
- Flat warm paper (`--bg-app`) with white cards. **No photography, no illustration, no pattern, no texture, no noise** — the repo ships none, and inventing an illustration style would be a guess. Where a marketing surface needs an image, use a neutral placeholder and ask.
- Colour blocking is the only "imagery": a group-hue header block on an event detail, a soft tint card for a callout (`--bg-tint-primary`, `--bg-tint-free`, or a group's `-soft`).
- If photography is ever added, it should be warm, daylight, real friends, no filters — matching the paper base rather than fighting it.

### Shape and cards
- Radii: 6 · 10 · **14 controls** · **18 cards** · 24 · **32 sheets** · pill. Buttons and chips are **always pill**, never 8px-rounded rectangles.
- A card is: white surface, 18px radius, **hairline inset ring + soft warm shadow** (`--shadow-1, --ring-inset`), 16px padding. Selected cards get a 2px coral inset ring, not a colour wash.
- Group-coloured events may carry a 4px hue spine on the left edge of a card — that is the *only* left-accent pattern in the system, and only for group identity.
- Grouped lists use **inset hairline separators** between rows (`inset 0 -1px 0 --line-hairline`), dropped on the last row. No full-bleed dividers.

### Elevation and shadows
- Warm-ink shadows (`rgba(26,23,20,…)`), never pure black. Four steps: 0 hairline · 1 resting list card · 2 lifted/selected · 3 sheet/toast. Sheets add an upward `--shadow-sheet`. Coral buttons carry a tinted `--shadow-primary` that disappears on press.
- Inner shadows are used only as hairlines (`--ring-inset`) and field borders — never as a bevel or inset-pressed look.

### Transparency and blur
- Exactly two places: the **NavBar** and **TabBar** (`--bg-chrome` + `--blur-chrome`, 18px blur, saturated), so content scrolls under them; and the **scrim** behind a sheet (`rgba(26,23,20,.44)`). A floating control over content may use the `chrome` IconButton variant. Nothing else is translucent — no frosted cards, no glass panels.
- Protection: chrome bars use blur + a hairline border rather than gradient scrims. Text over a group-hue block is white at 100% / 90% opacity, no gradient needed.

### Layout
- Screen gutter **20px**, card padding **16px**, list gap **12px**, section label 18px above / 8px below. Content max 640px on wide surfaces.
- Fixed elements: sticky translucent NavBar at top; TabBar pinned bottom (56px + 34px safe area); the compose FAB floats 16px above the TabBar, right-aligned; sheets pin to the bottom edge and stop at 90% height.
- **Tap targets are never below 44px** (`--tap-min`). IconButtons default to exactly 44.

### Motion
- `--ease-ios` `cubic-bezier(.32,.72,0,1)` is the default for anything that *moves*: sheets (420ms), pushes, the segmented-control thumb, switch knobs (220ms).
- `--ease-out` 140ms for taps, colour and shadow changes. `--ease-in-out` 340ms for cross-fades.
- `--ease-pop` `cubic-bezier(.34,1.4,.64,1)` — **one small overshoot, confirmations only** (a found date, a saved event, the radio fill). Never on navigation, never on more than one element at a time.
- Fades are 90–220ms and subtle; staggered reveals (busy blocks arriving during a search) step by 140ms.
- No parallax, no scroll-jacking, no looping ambient animation, no spinners other than the hourglass glyph on a loading button.

### States
- **Press**: `scale(.97)` on buttons, `scale(.988)` on cards, plus one shade darker on filled variants; the coral shadow drops away. Press is always felt through scale — never colour alone.
- **Hover** (iPad pointer, marketing web): the same one-shade-darker fill, no lift, no shadow growth, no underline except on inline text links.
- **Focus**: 1.5px coral border + 3px `--ring-focus` halo. Never remove focus rings.
- **Disabled**: 42% opacity, no colour change, cursor not-allowed.
- **Selected**: coral fill (segmented thumb, day cell, chip) or a 2px coral inset ring (slot card). Free/available states switch to teal.
- **Loading**: the hourglass glyph replaces the leading icon and the label says what's happening ("Checking six calendars…").

---

## ICONOGRAPHY

- **Set:** [Lucide](https://lucide.dev) — 54 SVGs copied into [`assets/icons/`](assets/icons). 24×24 box, 2px stroke, rounded caps and joins, no fills.
- **Substitution flagged:** Plannit is a SwiftUI app, so its real icons would be **SF Symbols**, which cannot be redistributed on the web. Lucide is the closest match in box size, stroke weight and terminal shape. If these designs move into Xcode, swap each glyph for its SF Symbol equivalent (`calendar`, `calendar.badge.plus`, `person.2`, `wand.and.stars`, `checkmark.circle.fill`, …).
- **How to render:** the `Icon` component masks the SVG file and fills it with `currentColor`, so a glyph always matches its text. Never inline SVG paths in a screen, never use an `<img>` that can't inherit colour.
- **Sizes:** 12–13 inside badges and meta lines · 16 in captions · 18 in list rows and buttons · 20 default · 22 in group/event tiles · 24 in nav and tab bars · 28+ only inside a tinted glyph tile (empty states, onboarding).
- **Icon tiles:** a glyph on a solid group hue in a 44px `--r-md` square (events, groups), or on a soft tint in a 32px `--r-sm` square (list rows), or on `--bg-tint-primary` in a 64–76px `--r-xl/2xl` square (empty states, onboarding).
- **No emoji as iconography**, no unicode symbols standing in for glyphs (no ✓ ★ →), no icon fonts, no PNG icons, no hand-drawn one-offs. The only non-Lucide vector art in the system is the device frame's status bar bars.
- **Activity glyphs** give events personality without illustration: `dumbbell` (sport), `utensils` (food), `cake` (birthday), `film` (film night), `coffee`, `beer`, `plane` (trips), `party-popper`, `house`, `clock` (appointments). Pick by event type; fall back to `calendar`.
- **Logo:** none exists. The repo ships no mark, so nothing has been drawn. Everywhere a logo would go, **Plannit is set in Figtree 800 at `--track-display`** in coral, paper, or white (see the *Wordmark (placeholder)* card). Ask the founder for artwork before any public surface.

---

## Index — what's in this system

| Path | What it is |
|---|---|
| [`styles.css`](styles.css) | The one stylesheet consumers link; `@import`s everything below |
| [`tokens/`](tokens) | `fonts` · `colors` · `typography` · `spacing` · `radius` · `elevation` · `motion` · `base` |
| [`guidelines/`](guidelines) | 21 foundation specimen cards (Colors, Type, Spacing, Shape & Depth, Brand) |
| [`components/`](components) | 27 React primitives in five groups, each with `.d.ts` + `.prompt.md` |
| [`ui_kits/plannit-ios/`](ui_kits/plannit-ios) | Click-through iOS app kit — onboarding, calendar, groups, the date-finder ([README](ui_kits/plannit-ios/README.md)) |
| [`assets/icons/`](assets/icons) | 54 Lucide SVGs |
| [`assets/app-icon/`](assets/app-icon) | iOS app icon — "The found day": 1024 + every device size, plus a drop-in `AppIcon.appiconset` ([how to install](assets/app-icon/README.md)) |
| [`thumbnail.html`](thumbnail.html) | Homepage tile for this system |
| [`SKILL.md`](SKILL.md) | Agent-skill entry point |
| [`github.md`](github.md) | Source-repo association and last sync |

### Components

**core/** — `Button` · `IconButton` · `Icon` · `Card` · `Badge` · `Tag` · `Avatar` · `AvatarStack`

**forms/** — `Input` · `Select` · `DayOfWeekPicker` · `Checkbox` · `Radio` · `Switch` · `SegmentedControl`

**feedback/** — `Sheet` · `Toast` · `Tooltip` · `EmptyState` · `ProgressDots`

**navigation/** — `NavBar` · `TabBar` · `ListRow`

**calendar/** — `EventCard` · `MonthGrid` · `SlotCard` · `AvailabilityBar`

Import them from the compiled bundle: `const { Button, EventCard } = window.PlannitDesignSystem_ede968`. Set `window.PLANNIT_ICON_BASE` to the relative path of `assets/icons` on every page. Pages that use `Sheet` or `Toast` must declare the `plannit-fade`, `plannit-sheet` and `plannit-toast` keyframes (copy them from `ui_kits/plannit-ios/index.html`).

### Intentional additions

No source defined a component inventory, so the set above is authored from scratch: the standard primitives Plannit's screens actually need, plus five the product cannot be drawn without — `DayOfWeekPicker` (the structured constraint input that replaced free text) and four calendar-specific ones — `EventCard`, `MonthGrid`, `SlotCard` (a date-finder proposal) and `AvailabilityBar` (the privacy-safe busy-block view from decision D-08). Deliberately **not** built, because nothing in the repo calls for them: Tabs (the segmented control is the tab pattern), Accordion, Table, Breadcrumb, Stepper, Pagination, Dropdown menu.

### Open questions for the founder

1. **Fonts** — Figtree stands in for SF Pro. Send real font files, or confirm we should design against the system font (in which case web previews keep Figtree as the proxy).
2. **Logo / app icon** — none provided; the wordmark is plain type. Four app-icon directions are sketched in [`guidelines/app-icon-options.html`](guidelines/app-icon-options.html) (CSS-drawn concepts, not final artwork): *The found day*, *Overlap*, *The free gap*, *P dot*. **"The found day" is now the chosen direction** and is exported for Xcode in [`assets/app-icon/`](assets/app-icon). It is generated from proportions rather than hand-drawn, so a designer should still redraw it as a vector master before the App Store listing. A wordmark for marketing surfaces is still missing.
3. **Coral vs. something else** — the palette is a proposal. Howbout and TimeTree both lean blue/green; coral was chosen to sit apart from them and feel warm rather than utilitarian. Say the word and it can be re-hued in one file (`tokens/colors.css`).
4. **Marketing surfaces** — is there a website or App Store presence to design? Right now this system covers the app only.
5. **Imagery** — no photography or illustration exists. If the App Store listing or onboarding should carry imagery, we need direction (or real photos).
