-- Contact channel between the public and the academy office.
--
-- An enquiry can be sent by anyone, signed in or not. When the sender has a
-- WEA account the message is linked to it, so replies can be shown to them in
-- the application rather than only by email.

CREATE TABLE IF NOT EXISTS contact_messages (
  id TEXT PRIMARY KEY NOT NULL,
  reference TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT NOT NULL DEFAULT '',
  organisation TEXT NOT NULL DEFAULT '',
  subject TEXT NOT NULL DEFAULT '',
  message TEXT NOT NULL,
  -- Set when the sender was signed in. Null for anonymous enquiries; those are
  -- answered by email instead.
  user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  source TEXT NOT NULL DEFAULT 'CONTACT_PAGE',
  status TEXT NOT NULL DEFAULT 'NEW'
    CHECK (status IN ('NEW', 'READ', 'REPLIED', 'CLOSED')),
  handled_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_contact_status
  ON contact_messages (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_contact_user
  ON contact_messages (user_id, created_at DESC);

-- The conversation on an enquiry. Replies are written by staff; the sender's
-- own follow-ups are recorded here too when they are signed in.
CREATE TABLE IF NOT EXISTS contact_replies (
  id TEXT PRIMARY KEY NOT NULL,
  message_id TEXT NOT NULL REFERENCES contact_messages(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  author_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  -- Distinguishes an academy reply from a sender follow-up without having to
  -- infer it from the author's current role, which can change later.
  from_academy INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_contact_replies
  ON contact_replies (message_id, created_at);

-- Monotonic source for enquiry references (WEA-ENQ-00019).
CREATE TABLE IF NOT EXISTS contact_sequence (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT OR IGNORE INTO site_settings (key, value) VALUES
  ('contact_email', 'enquirie@gmail.com'),
  ('contact_intro', 'Send an enquiry and the academy office will respond. If you are signed in, replies appear here as well as by email.'),
  ('contact_response_time', 'We aim to respond within two working days.');
