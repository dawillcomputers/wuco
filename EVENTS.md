# WEA EVENTS, PAID REGISTRATION & PROMOTION

> **Status:** Implemented. Schema, API, public pages, registration, payment
> verification, participant dashboard, Super Admin management, campaign links
> and site analytics are all in place. `flutter analyze` is clean and
> `flutter test test/events_test.dart` is green.

---

## 1. THE GOVERNING PRINCIPLES

Three rules decide almost every design choice in this feature.

**An event is configuration, never code.** Its price, currency, dates, format,
capacity, questions, materials, sessions and payment method are all rows a
Super Admin creates. Adding the next summit needs no release, and no event,
price, form field or payment provider is compiled into the Flutter application.

**A registration exists before a payment does.** Somebody who types their name,
address and telephone number and then closes the tab is a lead the academy can
still call. The record is written on the first save and then moved along a
state machine; nothing is ever deleted because a payment did not happen.

**The academy decides what was paid, not the browser.** `payment_status =
'PAID'` is written in exactly one function, after the Worker has asked the
processor itself and checked that the amount and currency match what was owed.
A success callback arriving from a browser is treated as a hint worth checking
and nothing more.

---

## 2. WHERE IT LIVES

| Layer | Location | Role |
| --- | --- | --- |
| Schema | `cloudflare/migrations/0006_events.sql` | Events, registrations, payments, materials, sessions, analytics, share links, social identities |
| Payments | `cloudflare/src/payments.ts` | Provider abstraction, verification, webhooks |
| Events API | `cloudflare/src/events.ts` | Public reads, registration, payment, participant view, administration |
| Analytics | `cloudflare/src/analytics.ts` | Page views, funnel, campaign links |
| Social cards | `cloudflare/src/share.ts` | Open Graph pages for shared links |
| Social sign-in | `cloudflare/src/social.ts` | ID-token verification and account linking |
| Client models | `lib/features/events/domain/` | Typed models |
| Client data | `lib/features/events/data/` | API client, offline backend, guest tokens |
| Public experience | `lib/features/events/presentation/` | Calendar, event page, registration, dashboard |
| Administration | `lib/features/super_admin/presentation/cms/` | Event CMS, registrants, analytics |

The Events feature is a peer of Catalogue and Learner, not a branch of any
dashboard, so paid summits, masterclasses and conferences reuse one
registration system rather than each rebuilding it.

---

## 3. THE REGISTRATION STATE MACHINE

```
STARTED ──► FORM_COMPLETED ──► PAYMENT_PENDING ──► PAYMENT_PROCESSING ──► COMPLETED
   │                                  │                     │
   └──────────► ABANDONED ◄───────────┘                     ▼
                                                     PAYMENT_FAILED
                                                            │
                                                            ▼
                                                     PAYMENT_PENDING
```

Two columns carry the state, because they answer different questions:
`status` is how far the registrant got, `payment_status` is whether the money
arrived. The Worker is their only writer and moves them together, so they
cannot drift into an inconsistent pair.

A free event skips payment entirely: `payment_status` is `NOT_REQUIRED` and the
registration completes at the review step.

**Abandonment.** An hourly cron moves attempts idle for more than 48 hours to
`ABANDONED`. Nothing is removed — that row is precisely the lead the academy
asked to keep, and it is still searchable, filterable and exportable.

---

## 4. THE REGISTRANT'S JOURNEY

```
/events                              The calendar
/events/:slug                        Event page — fee, agenda, share actions
/events/:slug/register               Information → Details → Review → Payment
/events/registration/:reference      Verification, outcome, event dashboard
```

The form is deliberately short: first name, last name and email, then a
telephone number, plus whatever questions the academy configured. Anything WEA
already holds — from the account or from a previous event — is shown as
confirmed rather than asked for again.

**No account is required to start.** Requiring a password before we know a
visitor's name is how registrations are lost. A guest is issued a resume token
whose digest alone is stored, exactly as for a session, so they can return to
their own registration and nobody else can open it. Signing in later with the
same address adopts that registration onto the account rather than creating a
second one.

---

## 5. PAYMENT

`payments.ts` maps a configured payment method to an implementation. Paystack
and Flutterwave are implemented; anything else — bank transfer, invoice,
offline — settles through `MANUAL`, where the academy confirms receipt and the
same audit row is written so revenue reconciles from one table.

A processor is offered only when the deployment holds its key, so an
unconfigured environment shows the academy's own instructions rather than
sending a payer to a checkout that cannot work.

Set the secrets with `wrangler secret put`:

```
PAYSTACK_SECRET_KEY
FLUTTERWAVE_SECRET_KEY
FLUTTERWAVE_WEBHOOK_HASH
```

**Verification.** Three paths converge on `settleEventPayment` — the return
redirect, the processor's webhook and a manual refresh — and all three ask the
processor's API. A webhook signature is checked, and then the only thing taken
from its body is which transaction it concerns. A payment for less than was
owed, or in the wrong currency, is recorded, flagged and left unsettled.

Card details never reach WEA and are never stored.

---

## 6. THE PARTICIPANT DASHBOARD

Reached at `/events/registration/:reference`. It confirms the payment outcome,
states plainly whether the place is secure, and then serves as the event's own
dashboard: information, agenda, sessions, programme materials and the
registration record.

Participant-only material is **omitted from the payload**, not merely flagged,
when the registration does not entitle it. A live session link is never in the
dashboard at all: it is issued one request at a time, after registration,
payment and whether the host has opened the room are checked again.

`event_sessions.join_url` and `room_name` are the seam a live classroom plugs
into. The access decision is made here whatever provider eventually runs it.

---

## 7. SUPER ADMIN

`/super-admin/content` gains three groups.

**Events** — events, event questions, event materials, event sessions, and
**Event registrations**: everyone who started, with lenses for Everyone,
Confirmed, Awaiting payment and **Leads**. Search by name, email, phone,
organisation or reference; filter by event; confirm a bank transfer with
*Mark paid*; export to CSV.

The overview shows registration attempts, completed, pending, abandoned and
failed, then **verified revenue** — pending and abandoned registrations are
never counted as money — and the conversion funnel from page visitors through
started, completed form, payment attempts and paid.

**Promotion** — campaign links and site analytics.

---

## 8. PROMOTION AND ANALYTICS

**Share actions** on every event page post to LinkedIn, Facebook, X, WhatsApp
or email, each carrying its own campaign source so the analytics can say which
platform produced registrations.

**Social preview cards.** The site paints its pages in the browser, so a
crawler fetching an application URL finds an empty shell. Shared links point at
`GET /share/event/:slug`, which serves that event's title, description and
artwork as Open Graph tags and then sends the visitor on to the real page with
the campaign parameters intact.

**Campaign links.** A Super Admin creates a named short link per channel —
LinkedIn, YouTube, Google, a newsletter — and shares `/s/:code`. Following it
counts the click and attaches the campaign parameters before the visitor
arrives.

**Page analytics.** Views, unique visitors, a daily series, most-visited pages,
referrers, campaigns, devices and countries.

There is **no cookie, no cross-site identifier and no stored IP address**. A
visitor is counted through a salted digest that rotates at midnight UTC —
enough to count a person once a day, useless for following anybody. Set
`ANALYTICS_SALT` per deployment. Rows past the retention window are pruned by
the same cron that sweeps abandoned registrations.

---

## 9. SOCIAL SIGN-IN

`social.ts` verifies a Google or Apple ID token against the provider's
published keys — signature, issuer, audience and expiry, with the audience
check that is the usual thing to get wrong — and then applies the one-person-
one-account rule: an already-linked identity signs in; an address WEA knows is
linked to the existing account rather than duplicated; only a genuinely new
person gets a new account.

`GET /api/auth/providers` reports which providers this deployment can complete,
so nothing is offered that cannot work.

**Not yet connected:** the client-side Google and Apple SDK buttons. Those need
the academy's OAuth client IDs (`GOOGLE_CLIENT_ID`, `APPLE_CLIENT_ID`) and the
matching platform configuration. Until they are supplied, registration uses the
ordinary WEA account path, which is offered but never required.

---

## 10. SECURITY

- A registration is readable by its signed-in owner, by the holder of its
  resume token, or by a Super Admin. There is no fourth way, and an
  unauthorised reference returns the same "not found" a stranger gets, so
  whether a reference exists is not something that can be probed.
- Payment amounts are read from the database, never from the request.
- Processor secrets and webhook hashes live in the Worker environment and are
  never returned to a client.
- Draft and archived events are not selected by any public query, so they
  cannot be reached by guessing a URL — including through the share endpoint.
- Every authorisation decision is made in the API. Nothing depends on the
  Flutter interface hiding a control.

---

## 11. CONFIGURATION

| Key | Kind | Purpose |
| --- | --- | --- |
| `PUBLIC_SITE_URL` | var | Builds share links and payment return URLs |
| `ANALYTICS_SALT` | secret | Salts the rotating visitor digest |
| `PAYSTACK_SECRET_KEY` | secret | Paystack initialisation and verification |
| `FLUTTERWAVE_SECRET_KEY` | secret | Flutterwave initialisation and verification |
| `FLUTTERWAVE_WEBHOOK_HASH` | secret | Authenticates Flutterwave webhooks |
| `GOOGLE_CLIENT_ID` | var | Enables Google sign-in |
| `APPLE_CLIENT_ID` | var | Enables Apple sign-in |

`public_site_url` is also a site setting, editable under Website copy, so the
academy can move the site without a deploy.

Webhook endpoints to register with each processor:

```
POST https://<api-host>/api/payments/webhook/paystack
POST https://<api-host>/api/payments/webhook/flutterwave
```
