-- Module 04 — authentication, identity and access control.
-- Passwords are stored only as PBKDF2-SHA256 digests with a per-user salt.
-- Session and link tokens are stored hashed, so a database leak cannot be
-- replayed against the API.

CREATE TABLE IF NOT EXISTS users (
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
      'APPLICANT','LEARNER','LECTURER','ADMIN','SUPER_ADMIN','PROFESSIONAL_MEMBER'
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

CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);

-- Opaque bearer sessions. token_hash is SHA-256 of the value held by the client.
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expiry ON sessions (expires_at);

-- Single-use links for email verification and password reset.
CREATE TABLE IF NOT EXISTS auth_tokens (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  purpose TEXT NOT NULL CHECK (purpose IN ('EMAIL_VERIFICATION','PASSWORD_RESET')),
  expires_at TEXT NOT NULL,
  used_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_auth_tokens_user ON auth_tokens (user_id, purpose);

-- One account may hold many programme places; the pair is unique so the same
-- programme cannot be joined twice.
CREATE TABLE IF NOT EXISTS programme_enrolments (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  programme_id TEXT NOT NULL,
  payment_status TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (payment_status IN ('PENDING','PAID','WAIVED')),
  granted_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (user_id, programme_id)
);

CREATE INDEX IF NOT EXISTS idx_enrolments_user ON programme_enrolments (user_id);

-- Administrative actions worth being able to answer questions about later.
CREATE TABLE IF NOT EXISTS admin_audit (
  id TEXT PRIMARY KEY NOT NULL,
  actor_id TEXT,
  action TEXT NOT NULL,
  subject_id TEXT,
  detail TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
