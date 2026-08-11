-- Module 06 — dynamic catalogue, media, registration and payment configuration.
--
-- Everything a Super Admin can publish lives here. No catalogue content is
-- compiled into the application: areas, types, programmes, modules, lessons,
-- faculty, schedules, pricing, registration questions and payment methods are
-- all rows, so adding a programme never requires a code change.
--
-- Content tables share three columns by convention:
--   status      DRAFT | PUBLISHED | ARCHIVED  — only PUBLISHED is public
--   sort_order  manual ordering, ascending
--   image_key / image_url  — an uploaded asset, or an external link

-- --------------------------------------------------------------------------
-- Uploaded media
-- --------------------------------------------------------------------------

-- Binary content lives in R2 under `key`; this table is the catalogue of it so
-- the admin UI can list, re-use and attribute uploads.
CREATE TABLE IF NOT EXISTS media_assets (
  id TEXT PRIMARY KEY NOT NULL,
  key TEXT NOT NULL UNIQUE,
  filename TEXT NOT NULL DEFAULT '',
  content_type TEXT NOT NULL DEFAULT 'application/octet-stream',
  size_bytes INTEGER NOT NULL DEFAULT 0,
  alt_text TEXT NOT NULL DEFAULT '',
  uploaded_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_media_created ON media_assets (created_at DESC);

-- --------------------------------------------------------------------------
-- Catalogue structure
-- --------------------------------------------------------------------------

-- A flagship area, e.g. "International Trade & Investment".
CREATE TABLE IF NOT EXISTS programme_areas (
  id TEXT PRIMARY KEY NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  code TEXT NOT NULL DEFAULT '',
  title TEXT NOT NULL,
  tagline TEXT NOT NULL DEFAULT '',
  summary TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  image_key TEXT,
  image_url TEXT,
  status TEXT NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_areas_status ON programme_areas (status, sort_order);

-- A kind of offering: Executive Certificate, Masterclass, Short Course… New
-- types are rows, so the academy can introduce a format without a release.
CREATE TABLE IF NOT EXISTS programme_types (
  id TEXT PRIMARY KEY NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  plural_title TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'PUBLISHED'
    CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_types_status ON programme_types (status, sort_order);

-- A single offering. Certificates, masterclasses, short courses and short cases
-- are all rows here, distinguished by type_id rather than by table.
CREATE TABLE IF NOT EXISTS programmes (
  id TEXT PRIMARY KEY NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  area_id TEXT NOT NULL REFERENCES programme_areas(id) ON DELETE CASCADE,
  type_id TEXT NOT NULL REFERENCES programme_types(id) ON DELETE RESTRICT,
  title TEXT NOT NULL,
  subtitle TEXT NOT NULL DEFAULT '',
  summary TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  image_key TEXT,
  image_url TEXT,
  level TEXT NOT NULL DEFAULT 'Executive',
  duration_label TEXT NOT NULL DEFAULT '',
  delivery_mode TEXT NOT NULL DEFAULT 'Online',
  language TEXT NOT NULL DEFAULT 'English',
  certificate_award TEXT NOT NULL DEFAULT '',
  eligibility TEXT NOT NULL DEFAULT '',
  who_should_attend TEXT NOT NULL DEFAULT '',
  -- JSON array of strings. Kept as a document because outcomes are only ever
  -- read and written whole, never queried across programmes.
  learning_outcomes TEXT NOT NULL DEFAULT '[]',
  start_date TEXT,
  application_deadline TEXT,
  tuition_amount REAL,
  tuition_currency TEXT NOT NULL DEFAULT 'USD',
  tuition_note TEXT NOT NULL DEFAULT '',
  cpd_points INTEGER NOT NULL DEFAULT 0,
  capacity INTEGER,
  registration_open INTEGER NOT NULL DEFAULT 1,
  featured INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_programmes_area ON programmes (area_id, status, sort_order);
CREATE INDEX IF NOT EXISTS idx_programmes_type ON programmes (type_id, status);
CREATE INDEX IF NOT EXISTS idx_programmes_status ON programmes (status, featured DESC, sort_order);

CREATE TABLE IF NOT EXISTS programme_modules (
  id TEXT PRIMARY KEY NOT NULL,
  programme_id TEXT NOT NULL REFERENCES programmes(id) ON DELETE CASCADE,
  number INTEGER NOT NULL DEFAULT 1,
  title TEXT NOT NULL,
  summary TEXT NOT NULL DEFAULT '',
  duration_label TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_modules_programme ON programme_modules (programme_id, sort_order);

CREATE TABLE IF NOT EXISTS programme_lessons (
  id TEXT PRIMARY KEY NOT NULL,
  module_id TEXT NOT NULL REFERENCES programme_modules(id) ON DELETE CASCADE,
  number INTEGER NOT NULL DEFAULT 1,
  title TEXT NOT NULL,
  lesson_type TEXT NOT NULL DEFAULT 'VIDEO'
    CHECK (lesson_type IN (
      'VIDEO', 'TEXT', 'PDF', 'PRESENTATION', 'AUDIO', 'EXTERNAL',
      'QUIZ', 'ASSIGNMENT', 'CASE_STUDY', 'LIVE_SESSION'
    )),
  duration_minutes INTEGER NOT NULL DEFAULT 0,
  summary TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL DEFAULT '',
  resource_url TEXT,
  media_key TEXT,
  is_preview INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_lessons_module ON programme_lessons (module_id, sort_order);

-- --------------------------------------------------------------------------
-- Faculty and scheduling
-- --------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS faculty (
  id TEXT PRIMARY KEY NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  role_title TEXT NOT NULL DEFAULT '',
  organisation TEXT NOT NULL DEFAULT '',
  bio TEXT NOT NULL DEFAULT '',
  expertise TEXT NOT NULL DEFAULT '[]',
  image_key TEXT,
  image_url TEXT,
  linkedin_url TEXT,
  -- Optional link to a sign-in account, so a lecturer profile and a user can be
  -- the same person without forcing every faculty member to have a login.
  user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_faculty_status ON faculty (status, sort_order);

CREATE TABLE IF NOT EXISTS programme_faculty (
  programme_id TEXT NOT NULL REFERENCES programmes(id) ON DELETE CASCADE,
  faculty_id TEXT NOT NULL REFERENCES faculty(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'Faculty',
  sort_order INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (programme_id, faculty_id)
);

-- Live classes, briefings and intakes.
CREATE TABLE IF NOT EXISTS programme_sessions (
  id TEXT PRIMARY KEY NOT NULL,
  programme_id TEXT NOT NULL REFERENCES programmes(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  session_type TEXT NOT NULL DEFAULT 'LIVE_CLASS'
    CHECK (session_type IN ('LIVE_CLASS', 'MASTERCLASS', 'BRIEFING', 'INTAKE', 'EXAM')),
  starts_at TEXT,
  ends_at TEXT,
  timezone TEXT NOT NULL DEFAULT 'UTC',
  mode TEXT NOT NULL DEFAULT 'Online',
  location TEXT NOT NULL DEFAULT '',
  join_url TEXT,
  faculty_id TEXT REFERENCES faculty(id) ON DELETE SET NULL,
  notes TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'PUBLISHED'
    CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sessions_programme ON programme_sessions (programme_id, starts_at);

-- --------------------------------------------------------------------------
-- Registration and payment
-- --------------------------------------------------------------------------

-- Extra questions asked at registration. A NULL programme_id makes the question
-- global; a set one scopes it to a single programme.
CREATE TABLE IF NOT EXISTS registration_fields (
  id TEXT PRIMARY KEY NOT NULL,
  programme_id TEXT REFERENCES programmes(id) ON DELETE CASCADE,
  field_key TEXT NOT NULL,
  label TEXT NOT NULL,
  field_type TEXT NOT NULL DEFAULT 'TEXT'
    CHECK (field_type IN ('TEXT', 'TEXTAREA', 'SELECT', 'CHECKBOX', 'DATE', 'NUMBER')),
  options TEXT NOT NULL DEFAULT '[]',
  help_text TEXT NOT NULL DEFAULT '',
  required INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_registration_fields ON registration_fields (programme_id, sort_order);

-- How an applicant may pay. Configuration only — no provider is compiled in.
CREATE TABLE IF NOT EXISTS payment_methods (
  id TEXT PRIMARY KEY NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL DEFAULT 'BANK_TRANSFER'
    CHECK (kind IN ('BANK_TRANSFER', 'GATEWAY', 'INVOICE', 'OFFLINE')),
  title TEXT NOT NULL,
  instructions TEXT NOT NULL DEFAULT '',
  bank_name TEXT NOT NULL DEFAULT '',
  account_name TEXT NOT NULL DEFAULT '',
  account_number TEXT NOT NULL DEFAULT '',
  sort_code TEXT NOT NULL DEFAULT '',
  swift_code TEXT NOT NULL DEFAULT '',
  currency TEXT NOT NULL DEFAULT 'USD',
  reference_prefix TEXT NOT NULL DEFAULT 'WEA',
  gateway_provider TEXT NOT NULL DEFAULT '',
  gateway_checkout_url TEXT NOT NULL DEFAULT '',
  gateway_public_key TEXT NOT NULL DEFAULT '',
  is_active INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Monotonic source for human-readable references (WEA-2026-00482). An
-- AUTOINCREMENT rowid is used rather than COUNT(*) so two applications
-- submitted at once cannot receive the same reference.
CREATE TABLE IF NOT EXISTS registration_sequence (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS registrations (
  id TEXT PRIMARY KEY NOT NULL,
  reference TEXT NOT NULL UNIQUE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  programme_id TEXT NOT NULL REFERENCES programmes(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'SUBMITTED'
    CHECK (status IN (
      'SUBMITTED', 'AWAITING_PAYMENT', 'PAID', 'CONFIRMED',
      'WAITLISTED', 'CANCELLED', 'DECLINED'
    )),
  payment_method_id TEXT REFERENCES payment_methods(id) ON DELETE SET NULL,
  payment_reference TEXT NOT NULL DEFAULT '',
  payment_proof_key TEXT,
  amount REAL,
  currency TEXT NOT NULL DEFAULT 'USD',
  -- Answers to registration_fields, keyed by field_key.
  answers TEXT NOT NULL DEFAULT '{}',
  -- Snapshot of the applicant's details at submission, so a later profile edit
  -- does not rewrite what was actually submitted.
  applicant_snapshot TEXT NOT NULL DEFAULT '{}',
  review_note TEXT NOT NULL DEFAULT '',
  reviewed_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (user_id, programme_id)
);

CREATE INDEX IF NOT EXISTS idx_registrations_user ON registrations (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_registrations_status ON registrations (status, created_at DESC);

-- --------------------------------------------------------------------------
-- Editable site configuration
-- --------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS site_settings (
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL DEFAULT '',
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT OR IGNORE INTO site_settings (key, value) VALUES
  ('catalogue_headline', 'Executive programmes for Africa’s leaders'),
  ('catalogue_intro', 'Executive certificates, masterclasses, short courses and executive short cases, developed for professionals who carry real decisions.'),
  ('registration_intro', 'Complete your registration below. Details we already hold on your WEA profile are reused automatically.'),
  ('registration_reference_prefix', 'WEA');
