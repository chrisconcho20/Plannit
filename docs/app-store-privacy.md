# App Store privacy labels

_Written 2026-09-30. The answers to App Store Connect's **App Privacy**
questionnaire, each traced to the code or schema that justifies it. Fill the
form from this file rather than from memory, and change this file first if the
app ever starts collecting something new._

Apple's definition decides everything here: data is **collected** when it leaves
the device in a form that is kept or transmitted. Data the app reads on the
device and never sends is not collected, and must not be declared — over-
declaring is as wrong as under-declaring, and it is the version that makes the
app look worse than it is.

---

## The short answer

| Question | Answer |
|---|---|
| Does the app collect data? | **Yes** |
| Is any of it used for tracking? | **No** |
| Is any of it used for advertising? | **No** |
| Is any of it sold or shared with data brokers? | **No** |
| Third parties receiving data | Supabase (hosting), Resend (sending the sign-in codes), Sentry (crash reports) |

---

## What to declare

### Contact Info → Email Address
**Collected · Linked to the user · App Functionality**

The sign-in identity, in `auth.users`, and the address a confirmation or
password-reset code is sent to. Someone who signs in with Apple and chooses
Hide My Email gives a relay address instead, which is still an email address
for this purpose.

### Contact Info → Name
**Collected · Linked to the user · App Functionality**

`profiles.display_name`, shown to the people in your groups so they know who
they are planning with. Chosen by the person, not read from the device.

### User Content → Photos or Videos
**Collected · Linked to the user · App Functionality**

Only a profile photo, only if one is chosen, stored in the `avatars` bucket
(`0013`). No other photo access exists in the app.

### User Content → Other User Content
**Collected · Linked to the user · App Functionality**

Events created **in Plannit**: title, time, location when given, and who they
are shared with. Also the optional one-line description on a quiet plan.

This is the line to read carefully: it covers what people type into Plannit,
**not** what is in their phone's calendar. See "What not to declare".

### Identifiers → User ID
**Collected · Linked to the user · App Functionality**

The account's UUID, and the friend code derived from it that lets someone be
found as `name#ABC123`.

### Identifiers → Device ID
**Collected · Linked to the user · App Functionality**

The APNs device token in `device_tokens` (`0003`), which is what a notification
is addressed to. Deleted at sign-out.

### Diagnostics → Crash Data
**Collected · Not linked to the user · App Functionality**

Sentry, live since 2026-09-30. A report carries a stack trace, device model, OS
and app version. `Services/CrashReporting.swift` disables screenshots, view
hierarchy, network breadcrumbs, failed-request capture and default PII, and
strips the user and request objects from every event before it is sent.

**"Not linked" is only true while those options stay off.** A view hierarchy
contains on-screen text, which in this app means event titles and people's
names. Anyone who turns one back on has changed this answer.

### Other Data → Other Data Types
**Collected · Linked to the user · App Functionality**

Two things with no better category:

- **Busy periods** — a start time and an end time, nothing else, in
  `busy_blocks`. This is what the date finder reads to know when a group is
  free. It is derived from the phone's calendar but carries none of its
  content.
- **Time zone** — `profiles.timezone`, so a plan made across zones shows at the
  right hour.

---

## What not to declare

**The contents of the phone's calendar.** Plannit asks for calendar access and
reads events on the device, but titles, notes, locations, guests and
attachments are never transmitted. What leaves is the merged busy ranges above.
This is decision D-17, it is enforced by what the app is capable of sending,
and the permission prompt promises it in as many words: *"Event details stay on
your device — only free/busy is shared."*

Under Apple's definition that data is not collected, so it is not declared.

**Also absent, so nothing to answer for:** location, contacts, health, financial
information, browsing or search history, purchases, advertising identifiers,
and any usage or product-interaction analytics. The app has no analytics SDK.

---

## Tracking

**No.** Nothing is shared with a data broker, nothing is combined with data
from other companies' apps or websites, and no advertising identifier is read.
Sentry receives crash data for diagnostics only, under its role as a processor.

So App Store Connect's tracking section stays empty and the app needs no App
Tracking Transparency prompt.

---

## Other fields on the listing

| Field | Value |
|---|---|
| Privacy Policy URL | `https://plannittogether.com/privacy.html` |
| Support URL | `https://plannittogether.com/support.html` |
| Age rating | 4+ on content; the privacy policy states the app is not directed at under-13s |
| Account required | Yes — a reviewer needs a demo account in TestFlight's review notes |

---

## When this file is wrong

Any of these changes the answers, and the form has to change with them:

- Switching on any Sentry option that captures content (screenshots, view
  hierarchy, breadcrumbs, PII) → Crash Data stops being "not linked"
- Adding analytics of any kind → a Usage Data section appears
- Uploading device events as rows rather than busy ranges (the B path in
  [`calendar-sync-plan.md`](calendar-sync-plan.md)) → the permission prompt,
  the privacy policy and this file all change together
- A server-side Google Calendar sync ([`google-calendar-plan.md`](google-calendar-plan.md))
  → same
