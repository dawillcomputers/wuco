-- OWNER and EVENT_MANAGER roles, and per-event payment configuration.
--
-- Two things here are enforced by the database rather than by the interface,
-- because "the Flutter UI hides the button" is not a security control:
--
--   * the role vocabulary, through a CHECK constraint;
--   * the rule that WEA must never end up with zero owners, through triggers
--     that refuse the write.

-- ---------------------------------------------------------------------------
-- Widening the role vocabulary
-- ---------------------------------------------------------------------------

-- SQLite cannot alter a CHECK constraint, so `users` is rebuilt. The column
-- list is copied exactly; only the CHECK changes. Existing rows carry over
-- unchanged — no role is renamed and none is dropped.
CREATE TABLE users_rebuilt (
  id TEXT PRIMARY KEY NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  password_salt TEXT NOT NULL,
  password_iterations INTEGER NOT NULL DEFAULT 100000,
  first_name TEXT NOT NULL DEFAULT '',
  last_name TEXT NOT NULL DEFAULT '',
  phone TEXT,
  country TEXT,
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'APPLICANT'
    CHECK (role IN (
      'APPLICANT','LEARNER','LECTURER','EVENT_MANAGER','ADMIN',
      'SUPER_ADMIN','OWNER','PROFESSIONAL_MEMBER'
    )),
  status TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (status IN (
      'ACTIVE','PENDING','PENDING_APPROVAL','SUSPENDED','DISABLED'
    )),
  email_verified INTEGER NOT NULL DEFAULT 0,
  must_change_password INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users_rebuilt
  SELECT id, email, password_hash, password_salt, password_iterations,
         first_name, last_name, phone, country, avatar_url, role, status,
         email_verified, must_change_password, created_at, updated_at
    FROM users;

DROP TABLE users;
ALTER TABLE users_rebuilt RENAME TO users;

CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);

-- ---------------------------------------------------------------------------
-- There must always be an owner
-- ---------------------------------------------------------------------------

-- An owner may hand the role on, but the last one cannot put it down: an
-- academy with no owner has nobody who can appoint one, and the only remedy
-- would be direct database surgery.
--
-- RAISE(ABORT) fails the statement, so the API sees an error rather than
-- silently doing nothing.
CREATE TRIGGER IF NOT EXISTS protect_last_owner_update
BEFORE UPDATE OF role ON users
WHEN OLD.role = 'OWNER'
 AND NEW.role <> 'OWNER'
 AND (SELECT COUNT(*) FROM users WHERE role = 'OWNER') <= 1
BEGIN
  SELECT RAISE(ABORT, 'LAST_OWNER');
END;

CREATE TRIGGER IF NOT EXISTS protect_last_owner_delete
BEFORE DELETE ON users
WHEN OLD.role = 'OWNER'
 AND (SELECT COUNT(*) FROM users WHERE role = 'OWNER') <= 1
BEGIN
  SELECT RAISE(ABORT, 'LAST_OWNER');
END;

-- Suspending or disabling the last owner locks the academy out just as
-- surely as demoting them.
CREATE TRIGGER IF NOT EXISTS protect_last_owner_status
BEFORE UPDATE OF status ON users
WHEN OLD.role = 'OWNER'
 AND NEW.status NOT IN ('ACTIVE', 'PENDING')
 AND (SELECT COUNT(*) FROM users WHERE role = 'OWNER' AND status = 'ACTIVE') <= 1
BEGIN
  SELECT RAISE(ABORT, 'LAST_OWNER');
END;

-- ---------------------------------------------------------------------------
-- Event managers
-- ---------------------------------------------------------------------------

-- Which events a manager is responsible for. An EVENT_MANAGER with no rows
-- here manages nothing, which is the safe default: the role does not by
-- itself grant access to every event.
CREATE TABLE IF NOT EXISTS event_managers (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  -- Permissions granted on this event beyond the role's baseline, as a JSON
  -- array. Lets one manager publish while another only handles registrants.
  granted_permissions TEXT NOT NULL DEFAULT '[]',
  assigned_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_event_manager
  ON event_managers (user_id, event_id);
CREATE INDEX IF NOT EXISTS idx_event_manager_event
  ON event_managers (event_id);

-- ---------------------------------------------------------------------------
-- Per-event payment configuration
-- ---------------------------------------------------------------------------

-- Which payment methods this event offers, as a JSON array of method keys.
--
-- Empty means "whatever the deployment has configured", so an event created
-- before this migration keeps working. It is never a promise that a method is
-- available: the API intersects this list with what the Flutterwave account
-- and the deployment's credentials actually support, and only the survivors
-- are shown to a payer.
ALTER TABLE events ADD COLUMN enabled_payment_methods TEXT NOT NULL DEFAULT '[]';

-- The processor's own identifiers, kept so a charge can be reconciled and so
-- a returning payer is not created as a second customer.
ALTER TABLE event_registrations ADD COLUMN provider_customer_id TEXT;
ALTER TABLE event_payments ADD COLUMN payment_method_key TEXT NOT NULL DEFAULT '';
ALTER TABLE event_payments ADD COLUMN provider_order_id TEXT;

-- Instructions the processor returns for an offline-style method — a virtual
-- account to transfer to, or a USSD string to dial. Not sensitive: it is
-- shown to the payer. Card data never appears here, or anywhere in WEA.
ALTER TABLE event_payments ADD COLUMN next_action TEXT NOT NULL DEFAULT '{}';

INSERT OR IGNORE INTO site_settings (key, value) VALUES
  ('payment_pending_note',
   'Your place is held once the academy has received and verified your payment.');
