# Getting Plannit onto other people's phones

_2026-08-26. The question: is the App Store the only reliable way to let friends
test this? Short answer — **no, but TestFlight is, and TestFlight needs the same
$99/yr membership the App Store does.** Everything free either doesn't reach a
real iPhone, or breaks every seven days._

---

## The one that matters for Plannit

Before comparing anything: **Plannit's whole point is a real calendar.** Any
route that hands a tester a simulator or a fresh empty device tests the UI and
none of the product. That single fact eliminates the option that's otherwise
most attractive.

---

## The options, ranked

### 1. TestFlight — $99/yr, and what you actually want

The Apple Developer Program includes TestFlight at no extra cost. You upload a
build, testers install Apple's TestFlight app, and they get your app plus every
update.

- **Up to 100 internal testers** (people with a role on your App Store Connect
  account) — no review, builds land within minutes of upload.
- **Up to 10,000 external testers**, invited by email or a **public link** you
  can just send to a group chat.
- External builds need **Beta App Review** on the *first* build of each version
  — usually under a day. Later builds of the same version are typically through
  in minutes unless you change entitlements, privacy strings, or the marketing
  copy.
- Builds expire after **90 days**; testers get a nudge to update.

What it costs you beyond the money: a real signing certificate, an App Store
Connect record, and the app's privacy details filled in — including the
calendar-access explanation you already wrote. [`ios/CODEMAGIC.md`](../ios/CODEMAGIC.md)
already has the pipeline mapped out.

**Why this is the answer:** it's the only route where a friend taps a link,
installs, uses their own calendar, and keeps getting updates without you or a
cable being involved.

### 2. Ad-hoc distribution — same $99, more friction

Also part of the paid program. You collect each tester's **UDID**, add it to
your provisioning profile (100 devices per type, per year), build a signed
`.ipa`, and get it onto their phone — via a service like Diawi, or Apple
Configurator.

Strictly worse than TestFlight for your case: you need each device's identifier
up front, there's no update mechanism, and the annual device slot is spent even
if the person tests once. It exists for enterprise QA fleets, not friends.

### 3. Appetize (what you already have) — free, but not for this

A build running in a browser. Genuinely useful, and you're already using it for
the demo preview — but the simulator has **no real calendar**, so the wedge
can't be tested and availability is meaningless. Good for showing someone the
idea; useless for finding out whether the date-finder works on a real life.

Also worth remembering it's a link to *your live database* if you point it
there — see [`security-review.md`](security-review.md).

### 4. AltStore / SideStore — free, and a bad fit for testers

These sideload apps signed with a **free** Apple ID, which carries Apple's
limits: the certificate lasts **7 days** and you can hold **3 sideloaded apps**
at a time. AltStore refreshes over Wi-Fi from a computer that must be awake on
the same network; SideStore refreshes on-device via a local VPN trick.

The killer for testing with friends: it's signed with **their** Apple ID on
**their** computer, so every tester has to install AltServer/SideStore, pair
their phone, and deal with the app dying weekly. You'd spend more time
supporting the installer than reading their feedback.

### 5. Your Mac and a cable — free, and only for people in the room

Exactly what you do today: a personal team, 7-day profile, Developer Mode on.
Works fine for a phone you can physically hold. Doesn't scale past that.

### 6. Apple Developer Enterprise Program — no

$299/yr, requires a legal entity with a D-U-N-S number, and is licensed for
**employees only**. Using it for a public beta is a straightforward way to have
the certificate revoked. Not an option, and worth knowing so it can be dismissed
when someone suggests it.

### 7. The App Store proper — later, not instead

A public release also needs the $99 membership, plus full App Review. It's the
end of the road, not a way to run a beta. TestFlight is the step before it and
uses the same account.

---

## Recommendation

**Pay the $99 and use TestFlight.** Everything else is either the wrong shape
(no real calendar), or a weekly maintenance chore for people doing you a favour.

The membership also unlocks two things Plannit is currently pretending it
doesn't need:

- **Push notifications** — the design already has "someone answered your plan"
  and "the organiser called it off" as things people should learn about without
  opening the app. `0004`'s triggers and the `send-push` function are written
  and idle for want of an APNs key.
- **Real Sign in with Apple** — the entitlement is stripped today because a
  personal team can't sign it.

---

## Before you invite anyone — three things, not optional

These are cheap and the alternative is a bad afternoon:

1. **Rotate the seeded test password and delete the old live preview build.**
   Both are in [`security-review.md`](security-review.md); a working password
   for accounts inside your real groups was public for a while.
2. **Turn off beta auto-friending.** Right now every new account is
   auto-friended to everyone and can see all profiles:
   ```sql
   update public.app_config set value = 'false'::jsonb
    where key = 'auto_friend_everyone';
   ```
   With friends joining, that stops being a convenience and starts being a
   surprise.
3. **Decide what testers see of each other.** A tester's calendar *details*
   never leave their phone (D-17), but their **name**, their groups, and any
   event they share are visible to the people they're grouped with. That's the
   design working — just make sure they know it before they sign in.

Worth adding once real testers exist: a way to report a bug from inside the app.
TestFlight has one built in (screenshot → feedback), which is another point in
its favour.

---

## Sources

- [Apple — TestFlight](https://developer.apple.com/testflight/)
- [App Store Connect Help — Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/)
- [iOS distribution guide 2026](https://foresightmobile.com/blog/ios-app-distribution-guide-2026)
- [Free sideloading tools compared, 2026](https://builds.io/blog/technologies/ios-technologies/altstore-vs-sidestore-vs-livecontainer/)
