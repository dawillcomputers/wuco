-- Richer event information, and the transactional email log.
--
-- Two additions the academy asked for after the first events release: more for
-- a registrant to read before they commit, and a record of what WEA sent them
-- afterwards.

-- --------------------------------------------------------------------------
-- More about an event
-- --------------------------------------------------------------------------

-- A downloadable flier or invitation, separate from the banner image. The
-- banner is artwork for the page; the flier is the thing people forward.
ALTER TABLE events ADD COLUMN flier_key TEXT;
ALTER TABLE events ADD COLUMN flier_url TEXT;

-- JSON arrays, edited as one line per entry in the CMS.
ALTER TABLE events ADD COLUMN highlights TEXT NOT NULL DEFAULT '[]';
ALTER TABLE events ADD COLUMN speakers TEXT NOT NULL DEFAULT '[]';

-- Practicalities a registrant needs and would otherwise have to ask for.
ALTER TABLE events ADD COLUMN what_is_included TEXT NOT NULL DEFAULT '';
ALTER TABLE events ADD COLUMN arrival_information TEXT NOT NULL DEFAULT '';
ALTER TABLE events ADD COLUMN dress_code TEXT NOT NULL DEFAULT '';
ALTER TABLE events ADD COLUMN accreditation TEXT NOT NULL DEFAULT '';
ALTER TABLE events ADD COLUMN cancellation_policy TEXT NOT NULL DEFAULT '';

-- Shown on the registration form itself, where it is actually read.
ALTER TABLE events ADD COLUMN registration_note TEXT NOT NULL DEFAULT '';

-- --------------------------------------------------------------------------
-- Transactional email
-- --------------------------------------------------------------------------

-- What WEA sent, to whom, and whether it left.
--
-- Kept for two reasons: the office needs to answer "did they get it", and a
-- send that failed because the mail provider was briefly down should be
-- visible rather than silent. The body is not stored — only what it was about.
CREATE TABLE IF NOT EXISTS email_log (
  id TEXT PRIMARY KEY NOT NULL,
  template TEXT NOT NULL,
  recipient TEXT NOT NULL,
  subject TEXT NOT NULL DEFAULT '',
  -- What the message concerned, so a receipt can be traced to its payment.
  reference TEXT NOT NULL DEFAULT '',
  user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'QUEUED'
    CHECK (status IN ('QUEUED', 'SENT', 'FAILED', 'SKIPPED')),
  -- Provider response detail on failure. Never a credential.
  detail TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_email_log_recipient
  ON email_log (recipient, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_email_log_status
  ON email_log (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_email_log_reference
  ON email_log (reference);

-- Editable copy for the messages WEA sends. Wording is the academy's, not the
-- developer's, so it is a setting rather than a string in the source.
INSERT OR IGNORE INTO site_settings (key, value) VALUES
  ('email_from_name', 'WUCO Executive Academy'),
  ('email_signature',
   'WUCO Executive Academy\nAfrica''s Executive Academy for Leadership, Trade, Investment and Professional Development'),
  ('email_welcome_intro',
   'Your WUCO Executive Academy account is ready. You can now register for programmes and events, and everything you have told us is reused so you never have to type it twice.'),
  ('email_receipt_intro',
   'Thank you. Your payment has been received and verified, and your place is confirmed.'),
  ('email_registration_intro',
   'We have received your registration. Your place is confirmed once payment has been received and verified.');
