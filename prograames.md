# WUCO EXECUTIVE ACADEMY — CATALOGUE ARCHITECTURE & INITIAL CATALOGUE

> **Status:** Implemented and live.
> The catalogue described below is seeded into the production database and
> served through the API. Nothing in it is compiled into the Flutter
> application.

---

## 1. THE GOVERNING PRINCIPLE

WEA is not a static course website. It is a dynamic executive education
platform.

A Super Admin can **create, edit, publish, unpublish, archive and manage
unlimited** programme areas, programmes, programme types, certificates,
masterclasses, short courses, short cases, modules, lessons, faculty, pricing,
registration requirements, payment methods, media and schedules **without
modifying application code**.

Existing learner information is reused across registrations.

This is enforced architecturally, not by convention: the public site queries the
API for every piece of catalogue content, and the API serves only rows a Super
Admin has marked `PUBLISHED`.

---

## 2. WHERE CONTENT LIVES

| Layer | Location | Role |
| --- | --- | --- |
| Schema | `cloudflare/migrations/0003_catalogue.sql` | Tables for the whole catalogue |
| Seed | `cloudflare/migrations/0004_seed_catalogue.sql` | The initial catalogue below |
| Contact | `cloudflare/migrations/0005_contact.sql`, `src/contact.ts`, `lib/features/contact/` | Enquiries and replies |
| Events | `cloudflare/migrations/0006_events.sql`, `src/events.ts`, `lib/features/events/` | Paid events — see `EVENTS.md` |
| Seed source | `cloudflare/scripts/catalogue-data.mjs` | Structured data the seed is generated from |
| API | `cloudflare/src/catalogue.ts`, `resources.ts`, `media.ts`, `registrations.ts` | Public reads, admin writes, uploads |
| Client models | `lib/features/catalogue/domain/` | Typed models |
| Public site | `lib/features/catalogue/presentation/` | Catalogue, area, programme, registration |
| Administration | `lib/features/super_admin/presentation/cms/` | The CMS |

The seed is written with `INSERT OR IGNORE` against fixed identifiers, so
re-running migrations never duplicates rows and never overwrites an edit made
through the CMS.

---

## 3. CONTENT MODEL

```
Programme area  (01 International Trade & Investment, …)
  └── Programme            typed by Programme type
        ├── Module
        │     └── Lesson
        ├── Faculty            (many-to-many)
        ├── Live session       (schedule)
        └── Registration question
```

Supporting entities: **Media asset**, **Payment method**, **Registration**,
**Site setting**.

Every content row carries:

- `status` — `DRAFT` · `PUBLISHED` · `ARCHIVED` (only `PUBLISHED` is public)
- `sort_order` — manual ordering
- `image_key` / `image_url` — an uploaded asset, or an external link

---

## 4. PROGRAMME TYPES

Seeded as defaults. A Super Admin may add more at any time.

| Type | Default duration | Default delivery | Award |
| --- | --- | --- | --- |
| Executive Certificate | 12 weeks | Blended | WEA Advanced Executive Certificate |
| Masterclass | 1 day | Live online | Certificate of Participation |
| Short Course | 4 weeks | Online | Certificate of Completion |
| Advanced Executive Programme | 16 weeks | Blended | Advanced Executive Programme Certificate |
| Executive Short Case | 90 minutes | Online | Executive Short Case Record |

---

## 5. THE INITIAL CATALOGUE

**6 areas · 5 types · 131 programmes · 102 modules · 6 faculty profiles.**

### 01 — International Trade & Investment
Trade, AfCFTA, investment, cross-border business and international commercial
practice.

- **Executive Certificate (1)** — Advanced Certificate in International Trade & Investment
- **Masterclasses (7)** — AfCFTA Business Opportunities · Mastering Cross-Border Trade in Africa · Investment Attraction & Investor Relations · International Commercial Negotiation · Trade Finance for Executives · Managing Cross-Border Commercial Risk · Digital Trade & the Future of African Commerce
- **Short Courses (10)** — Understanding AfCFTA · Export Readiness · Import & Export Compliance · International Contract Management · Trade Documentation · Trade Finance Fundamentals · Cross-Border Payments · Investment Promotion · Market Entry Strategy · International Business Negotiation
- **Advanced Executive Programme (1)** — Executive Programme on African Trade, Investment and Cross-Border Business

### 02 — Banking, Finance & Financial Services
Banking leadership, regulation, risk and financial innovation.

- **Executive Certificates (3)** — Banking Leadership & Financial Services · Banking Regulation, Compliance & Risk · Digital Banking & Financial Innovation
- **Masterclasses (10)** — Strategic Leadership for Banking Executives · Banking Compliance & Regulatory Risk · Anti-Financial Crime & Risk Management · Digital Banking Transformation · AI in Banking · Cyber Risk for Financial Institutions · Customer Experience in Banking · Financial Consumer Protection · Fintech Partnerships & Open Banking · Executive Decision-Making in Banking
- **Short Courses (12)** — Credit Risk · Operational Risk · Compliance Management · Corporate Governance · Financial Consumer Protection Practice · Digital Payments · Fintech · AI for Banking Professionals · Customer Experience in Financial Services · Data Governance · Fraud Risk Management · Regulatory Technology
- **Advanced Executive Programme (1)** — Executive Programme on the Future of Banking, Fintech, AI and Financial Consumer Protection

### 03 — Retail, Consumer Markets & Customer Experience
Retail strategy, consumer intelligence and customer experience.

- **Executive Certificates (2)** — Retail Management & Consumer Intelligence · Customer Experience & Consumer Protection
- **Masterclasses (10)** — The Future of Retail in Africa · Consumer Intelligence for Business Growth · Customer Experience Transformation · Retail Risk & Compliance · E-Commerce & Consumer Protection · Consumer Data & Personalisation · Managing Difficult Customers and Consumer Disputes · Building Consumer Trust · Retail Leadership · Omnichannel Retail Strategy
- **Short Courses (12)** — Consumer Behaviour · Retail Operations · Customer Experience Fundamentals · Complaint Management · Consumer Data Analytics · E-Commerce · Digital Customer Service · Consumer Rights in Retail · Retail Compliance · Customer Retention · Brand Trust · Social Commerce
- **Advanced Executive Programme (1)** — Executive Programme on Consumer Intelligence, Retail Transformation & Customer Experience

### 04 — Consumer Protection & Consumer Intelligence
WEA's signature area, reflecting the mandate of the World United Consumer
Organisation.

- **Executive Certificates (3)** — Consumer Protection & Regulatory Practice · Consumer Intelligence & Market Analytics · Consumer Affairs Management
- **Masterclasses (9)** — Consumer Protection for Corporate Executives · Consumer Intelligence for Strategic Decision-Making · Managing Consumer Complaints & Disputes · Consumer Protection in Digital Markets · AI and Consumer Rights · E-Commerce Consumer Protection · Building Consumer Trust in Regulated Markets · Consumer Risk Management · Consumer-Centric Business Strategy
- **Short Courses (10)** — Consumer Rights · Consumer Complaint Management · Alternative Dispute Resolution · Consumer Data · Product Safety · Advertising & Consumer Protection · Digital Consumer Protection · Unfair Commercial Practices · Consumer Risk · Consumer Advocacy
- **Advanced Executive Programme (1)** — Executive Programme on Consumer Protection, Intelligence, Digital Markets and Responsible Business

### 05 — Artificial Intelligence, Digital Transformation & Responsible AI
AI strategy, governance and responsible adoption.

- **Executive Certificates (3)** — AI for Business Leaders · AI Governance, Ethics & Regulation · Digital Transformation & AI Strategy
- **Masterclasses (12)** — AI for CEOs and Board Members · AI for Government Executives · Generative AI for Business · AI Risk Management · Responsible AI · AI Governance · AI and Consumer Protection · AI in Banking Operations · AI in Retail · AI in International Trade · AI for Lawyers and Legal Professionals · AI for Public Administration
- **Short Courses (12)** — Generative AI for Professionals · Prompt Engineering for Executives · AI Productivity · AI Research & Intelligence · AI-Assisted Decision-Making · AI and Data Governance · AI Ethics · AI Risk · AI for Customer Service · AI for Marketing · AI for HR · AI for Legal Practice
- **Advanced Executive Programme (1)** — Executive Programme on Artificial Intelligence, Digital Transformation and Responsible Governance

### 06 — Executive Short Case Series
Short, decision-centred cases from real African business and policy situations.

A Nigerian Retailer Faces a Consumer Data Crisis · A Bank Introduces an AI
Credit-Scoring System · A Fintech Company Enters a New African Market · A
Foreign Investor Wants to Enter Nigeria · A Consumer Complaint Goes Viral on
Social Media · An African Exporter Encounters a Cross-Border Trade Barrier · AI
Generates a Discriminatory Business Decision · A Bank Faces a Major
Customer-Trust Crisis · A Retailer Uses Consumer Data Without Adequate
Transparency · Government Must Regulate a New AI-Based Consumer Platform

### Planned areas
Government & Executive Leadership · Corporate Governance & Regulatory Compliance
· Public Policy & Government Capacity Building.

These are added through the CMS when the academy is ready — no release required.

---

## 6. THE PUBLIC JOURNEY

```
/programmes                     Catalogue: flagship areas, then every programme
/programmes/area/:slug          One area, grouped by programme type
/programmes/:slug               Programme page
/register/:slug                 Registration
```

A programme page carries: hero and summary · tuition and a register action ·
duration, delivery, level, language, certificate, start date, application
deadline, CPD points · what you will learn · who should attend · programme
structure · faculty · live executive sessions · certification · eligibility.

---

## 7. INTELLIGENT REGISTRATION

Registration requires a WEA account, because **the account is the applicant
record**.

When a returning applicant registers:

1. The API returns what WEA already holds — name, email, phone, country — plus
   answers given on any previous registration.
2. The form greets them (*"Welcome back, John."*), lists those details as
   confirmed, and does **not** ask for them again.
3. Only programme-specific questions are asked, pre-filled where a previous
   answer exists.
4. A reference is issued in the form `WEA-2026-00482`, from a monotonic sequence
   so two simultaneous applications can never collide.
5. Payment instructions for the chosen method are shown against that reference.

Confirming a registration in the CMS enrols the learner and promotes an
`APPLICANT` account to `LEARNER`, so a confirmed place immediately means access.

---

## 8. PAYMENT

Configuration, never code. A Super Admin defines any number of methods:

- **Bank transfer** — bank name, account name, account number, sort code, SWIFT,
  instructions, reference prefix
- **Gateway** — provider name, checkout URL, public key
- **Invoice** / **Offline** — instructions only

No payment provider is compiled into the application. Adding one is a row.

---

## 9. MEDIA

Images are uploaded through the CMS, stored in Cloudflare R2 and served from
`GET /api/media/:key`. The bucket stays private; there is no public bucket
domain to configure. Uploads accept JPEG, PNG, WebP, GIF, SVG and PDF up to
10 MB.

Replacing a programme image is: open the programme, upload, save. No code, no
deployment.

---

## 10. CONTACT CHANNEL

Enquiries sent from `/contact` go to the academy office through the API, not to
a mailbox the application cannot see.

- **Anyone may send one.** A signed-in sender is identified by their session, so
  the form asks only for the message; their enquiry is linked to their account.
- **The office replies** from `/super-admin/content` → Contact messages, with
  status tracking (New · Read · Replied · Closed).
- **A reply reaches the sender two ways.** If they have an account it appears on
  the contact page under "Your enquiries", where they can also follow up. If not,
  the office answers by email against the reference.
- References are issued as `WEA-ENQ-00019` from a monotonic sequence.
- A sender may only ever read or follow up on **their own** enquiries; the check
  is in the API, not the interface.

The published address is `contact_email` in site settings — currently
`enquirie@gmail.com` — and is editable under Website copy.

---

## 11. ADMINISTRATION

`/super-admin/content` — Super Admin only, enforced by the API on every call.

Manage: programme areas · programme types · programmes · modules · lessons ·
faculty · live sessions · registration questions · payment methods ·
registrations · contact messages · website copy.

Each content type has publish / unpublish / archive, ordering, search, filtering
by parent, and image upload where relevant.

---

## 12. EVENTS

Events are a peer of the catalogue, not part of it: a summit is not a
programme, and its registrant is not an applicant. They share the payment
method configuration above and nothing else.

`/super-admin/content` → Events manages events, their questions, materials and
live sessions, and shows every registration including the ones that were never
finished. Promotion manages campaign links and site analytics.

The whole feature is documented in **`EVENTS.md`**.
