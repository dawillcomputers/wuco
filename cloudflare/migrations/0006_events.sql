-- WEA Events: institutional events with paid registration.
--
-- Three things shape this schema.
--
-- 1. An event is configuration, not code. Everything a Super Admin needs to
--    decide — price, currency, dates, format, which payment method, what the
--    form asks — is a column or a row, never a release.
-- 2. A registration record exists *before* payment. Someone who fills in their
--    name and walks away is a lead the academy can still see and follow up,
--    so the record is created as soon as the registrant submits anything
--    meaningful and is then moved through a state machine.
-- 3. Payment is decided by the server. The client is told what happened, but
--    `payment_status = 'PAID'` is only ever written after the Worker has asked
--    the payment processor directly.

-- ---------------------------------------------------------------------------
-- The event
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  subtitle TEXT NOT NULL DEFAULT '',
  event_type TEXT NOT NULL DEFAULT 'CONFERENCE',
  summary TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  why_attend TEXT NOT NULL DEFAULT '',
  who_should_attend TEXT NOT NULL DEFAULT '',
  -- JSON array of {time, title, detail}. Edited as lines in the CMS.
  agenda TEXT NOT NULL DEFAULT '[]',
  image_key TEXT,
  image_url TEXT,

  starts_at TEXT,
  ends_at TEXT,
  timezone TEXT NOT NULL DEFAULT 'Africa/Lagos',
  venue TEXT NOT NULL DEFAULT '',
  format TEXT NOT NULL DEFAULT 'ONLINE'
    CHECK (format IN ('ONLINE', 'PHYSICAL', 'HYBRID')),

  registration_opens_at TEXT,
  registration_closes_at TEXT,
  capacity INTEGER,

  -- The fee the registrant pays. Never editable by the registrant: every
  -- payment amount is read from this row server-side, never from the request.
  fee_amount REAL NOT NULL DEFAULT 0,
  fee_currency TEXT NOT NULL DEFAULT 'NGN',
  -- Which configured method collects it. Null means the event is free.
  payment_method_id TEXT REFERENCES payment_methods(id) ON DELETE SET NULL,
  payment_instructions TEXT NOT NULL DEFAULT '',

  contact_email TEXT NOT NULL DEFAULT '',
  contact_phone TEXT NOT NULL DEFAULT '',
  terms TEXT NOT NULL DEFAULT '',
  success_message TEXT NOT NULL DEFAULT '',

  -- Whether someone may register without first creating a WEA account. They
  -- still get a registration record either way.
  allow_guest_registration INTEGER NOT NULL DEFAULT 1,
  featured INTEGER NOT NULL DEFAULT 0,

  status TEXT NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN (
      'DRAFT', 'PUBLISHED', 'REGISTRATION_CLOSED',
      'COMPLETED', 'CANCELLED', 'ARCHIVED'
    )),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_events_status
  ON events (status, starts_at);
CREATE INDEX IF NOT EXISTS idx_events_featured
  ON events (featured, starts_at);

-- Extra questions on an event's registration form. A row with a null event_id
-- is asked on every event. Adding a question is a row, not a release.
CREATE TABLE IF NOT EXISTS event_registration_fields (
  id TEXT PRIMARY KEY NOT NULL,
  event_id TEXT REFERENCES events(id) ON DELETE CASCADE,
  field_key TEXT NOT NULL,
  label TEXT NOT NULL,
  field_type TEXT NOT NULL DEFAULT 'TEXT',
  options TEXT NOT NULL DEFAULT '[]',
  help_text TEXT NOT NULL DEFAULT '',
  required INTEGER NOT NULL DEFAULT 0,
  -- Asked in the first step rather than after the essentials. Kept off by
  -- default: the point of this form is that it is short.
  ask_early INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_event_fields
  ON event_registration_fields (event_id, sort_order);

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------

-- One person's registration for one event.
--
-- Written early and updated as they progress, so an abandoned attempt is still
-- a row the academy can see. Only what the registrant actually typed is stored;
-- nothing is inferred, and no card detail ever reaches this table.
CREATE TABLE IF NOT EXISTS event_registrations (
  id TEXT PRIMARY KEY NOT NULL,
  reference TEXT NOT NULL UNIQUE,
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  -- Set whenever the registrant is, or becomes, a WEA account. Guests start
  -- null and are linked if they sign in later with the same address.
  user_id TEXT REFERENCES users(id) ON DELETE SET NULL,

  first_name TEXT NOT NULL DEFAULT '',
  last_name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  organisation TEXT NOT NULL DEFAULT '',
  job_title TEXT NOT NULL DEFAULT '',
  country TEXT NOT NULL DEFAULT '',
  -- Answers to the event's own questions, keyed by field_key.
  answers TEXT NOT NULL DEFAULT '{}',

  status TEXT NOT NULL DEFAULT 'STARTED'
    CHECK (status IN (
      'STARTED', 'FORM_COMPLETED', 'PAYMENT_PENDING', 'PAYMENT_PROCESSING',
      'PAID', 'PAYMENT_FAILED', 'ABANDONED', 'CANCELLED', 'COMPLETED'
    )),
  -- Kept alongside `status` because the two answer different questions —
  -- "how far did they get" and "has the money arrived". The Worker is the only
  -- writer, and it moves them together, so they cannot drift apart.
  payment_status TEXT NOT NULL DEFAULT 'NOT_REQUIRED'
    CHECK (payment_status IN (
      'NOT_REQUIRED', 'PENDING', 'PROCESSING', 'PAID', 'FAILED', 'REFUNDED'
    )),

  -- Copied from the event at the moment of registration, so a later price
  -- change never rewrites what somebody already agreed to pay.
  amount REAL NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'NGN',
  payment_method_id TEXT REFERENCES payment_methods(id) ON DELETE SET NULL,

  -- SHA-256 of the token handed to a guest so they can return to their own
  -- registration. Only the digest is stored, exactly as for sessions.
  resume_token_hash TEXT,

  -- Attribution for the link that brought them here.
  source TEXT NOT NULL DEFAULT '',
  utm_source TEXT NOT NULL DEFAULT '',
  utm_medium TEXT NOT NULL DEFAULT '',
  utm_campaign TEXT NOT NULL DEFAULT '',

  admin_note TEXT NOT NULL DEFAULT '',
  last_activity_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- One live registration per person per event. Partial so that guests without
-- an account are matched on their address instead.
CREATE UNIQUE INDEX IF NOT EXISTS idx_event_reg_user
  ON event_registrations (event_id, user_id) WHERE user_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_event_reg_email
  ON event_registrations (event_id, email) WHERE email <> '';
CREATE INDEX IF NOT EXISTS idx_event_reg_status
  ON event_registrations (event_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_event_reg_activity
  ON event_registrations (last_activity_at DESC);

-- Monotonic source for event references (WEA-EVT-2026-00123).
CREATE TABLE IF NOT EXISTS event_registration_sequence (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------------
-- Payment
-- ---------------------------------------------------------------------------

-- Every attempt to pay, successful or not.
--
-- Deliberately append-mostly: a failed attempt is evidence, not something to
-- overwrite. `verified_at` is written only by the server-side verification
-- path, so a forged client callback can never produce a verified row.
CREATE TABLE IF NOT EXISTS event_payments (
  id TEXT PRIMARY KEY NOT NULL,
  registration_id TEXT NOT NULL
    REFERENCES event_registrations(id) ON DELETE CASCADE,
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,

  provider TEXT NOT NULL DEFAULT 'MANUAL',
  -- Our reference, sent to the processor and echoed back.
  provider_reference TEXT NOT NULL,
  -- The processor's own identifier for the transaction, once known.
  provider_transaction_id TEXT,
  checkout_url TEXT,

  amount REAL NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'NGN',

  status TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING', 'PROCESSING', 'PAID', 'FAILED', 'CANCELLED', 'REFUNDED')),
  failure_reason TEXT NOT NULL DEFAULT '',
  -- Non-sensitive echo of the processor's verification response, for support.
  -- Card numbers and CVVs never reach WEA and are never written here.
  provider_payload TEXT NOT NULL DEFAULT '{}',

  verified_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_event_payment_reference
  ON event_payments (provider_reference);
CREATE INDEX IF NOT EXISTS idx_event_payment_registration
  ON event_payments (registration_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- What a participant gets
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS event_materials (
  id TEXT PRIMARY KEY NOT NULL,
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  material_type TEXT NOT NULL DEFAULT 'DOCUMENT',
  -- An uploaded asset in R2, or an external link.
  media_key TEXT,
  resource_url TEXT,
  -- PUBLIC material is on the event page; PARTICIPANT material needs a
  -- confirmed registration, checked in the API rather than hidden in the UI.
  visibility TEXT NOT NULL DEFAULT 'PARTICIPANT'
    CHECK (visibility IN ('PUBLIC', 'PARTICIPANT')),
  status TEXT NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_event_materials
  ON event_materials (event_id, status, sort_order);

-- Live sittings of an event.
--
-- `join_url` is the seam the live classroom plugs into: whatever provider runs
-- WEA Live, the access decision — registered, paid, session open — is made here
-- and the participant is handed a link only once it passes.
CREATE TABLE IF NOT EXISTS event_sessions (
  id TEXT PRIMARY KEY NOT NULL,
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  session_type TEXT NOT NULL DEFAULT 'LIVE',
  starts_at TEXT,
  ends_at TEXT,
  timezone TEXT NOT NULL DEFAULT 'Africa/Lagos',
  -- Room identifier for the live provider. Held server-side.
  room_name TEXT NOT NULL DEFAULT '',
  join_url TEXT,
  recording_url TEXT,
  speaker TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  -- Set by the host. Nobody is admitted while this is 0, whatever the clock
  -- says, so a session cannot be joined before the academy opens it.
  is_live INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_event_sessions
  ON event_sessions (event_id, starts_at);

CREATE TABLE IF NOT EXISTS event_attendance (
  id TEXT PRIMARY KEY NOT NULL,
  session_id TEXT NOT NULL REFERENCES event_sessions(id) ON DELETE CASCADE,
  registration_id TEXT NOT NULL
    REFERENCES event_registrations(id) ON DELETE CASCADE,
  joined_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  left_at TEXT,
  minutes INTEGER NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_event_attendance
  ON event_attendance (session_id, registration_id);

-- ---------------------------------------------------------------------------
-- Promotion and analytics
-- ---------------------------------------------------------------------------

-- A named campaign link. The academy creates one per channel — LinkedIn,
-- Facebook, a newsletter — and shares the short URL; the Worker redirects to
-- the real page with the campaign parameters attached and counts the click.
CREATE TABLE IF NOT EXISTS share_links (
  id TEXT PRIMARY KEY NOT NULL,
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL DEFAULT '',
  target_type TEXT NOT NULL DEFAULT 'EVENT'
    CHECK (target_type IN ('EVENT', 'PROGRAMME', 'PAGE')),
  -- Path on the public site, e.g. /events/africa-trade-summit.
  target_path TEXT NOT NULL,
  channel TEXT NOT NULL DEFAULT '',
  campaign TEXT NOT NULL DEFAULT '',
  medium TEXT NOT NULL DEFAULT '',
  clicks INTEGER NOT NULL DEFAULT 0,
  last_click_at TEXT,
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'PUBLISHED'
    CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Page visits.
--
-- Deliberately thin. There is no cookie, no cross-site identifier and no IP
-- address: `visitor_hash` is a salted digest that rotates every day, which is
-- enough to count people once per day and useless for following anybody.
CREATE TABLE IF NOT EXISTS page_views (
  id TEXT PRIMARY KEY NOT NULL,
  path TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  event_id TEXT REFERENCES events(id) ON DELETE SET NULL,
  programme_id TEXT REFERENCES programmes(id) ON DELETE SET NULL,
  referrer TEXT NOT NULL DEFAULT '',
  referrer_host TEXT NOT NULL DEFAULT '',
  utm_source TEXT NOT NULL DEFAULT '',
  utm_medium TEXT NOT NULL DEFAULT '',
  utm_campaign TEXT NOT NULL DEFAULT '',
  utm_content TEXT NOT NULL DEFAULT '',
  share_code TEXT NOT NULL DEFAULT '',
  country TEXT NOT NULL DEFAULT '',
  device TEXT NOT NULL DEFAULT '',
  visitor_hash TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_page_views_path
  ON page_views (path, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_page_views_event
  ON page_views (event_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_page_views_created
  ON page_views (created_at DESC);

-- Named progress events, used for the registration funnel. Same privacy rules
-- as page_views: a rotating visitor hash and nothing else about the person.
CREATE TABLE IF NOT EXISTS analytics_events (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  path TEXT NOT NULL DEFAULT '',
  event_id TEXT REFERENCES events(id) ON DELETE SET NULL,
  registration_id TEXT REFERENCES event_registrations(id) ON DELETE SET NULL,
  utm_source TEXT NOT NULL DEFAULT '',
  utm_campaign TEXT NOT NULL DEFAULT '',
  visitor_hash TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_analytics_name
  ON analytics_events (name, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_event
  ON analytics_events (event_id, name, created_at DESC);

-- ---------------------------------------------------------------------------
-- Social sign-in
-- ---------------------------------------------------------------------------

-- Links a WEA account to an external identity provider.
--
-- Its purpose is the rule in §20 of the specification: one person, one account.
-- Signing in with Google using an address WEA already knows attaches to the
-- existing user rather than creating a second one.
CREATE TABLE IF NOT EXISTS social_identities (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL,
  -- The provider's stable identifier for the person ("sub" in an ID token).
  subject TEXT NOT NULL,
  email TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_social_identity
  ON social_identities (provider, subject);
CREATE INDEX IF NOT EXISTS idx_social_identity_user
  ON social_identities (user_id);

-- ---------------------------------------------------------------------------
-- Editable copy
-- ---------------------------------------------------------------------------

INSERT OR IGNORE INTO site_settings (key, value) VALUES
  ('events_intro',
   'Executive conferences, summits, masterclasses and forums convened by WUCO Executive Academy.'),
  ('events_empty_message',
   'The next WEA events will be announced here.'),
  ('event_registration_note',
   'Your place is confirmed once payment has been received and verified.'),
  -- Used to build absolute share links and social preview cards.
  ('public_site_url', 'https://wuco.pages.dev');
