-- Programme tuition through the payment processor.
--
-- Events could already be paid for online; programmes could not, so tuition
-- arrived by transfer and somebody in the office marked it received. This puts
-- both on the same machinery — the same credentials, the same verification,
-- the same webhook — so there is one place where WEA decides money has
-- arrived rather than two that could disagree.

-- Which methods a programme offers. Same meaning as on an event: a permission,
-- not a promise. The API intersects it with what the deployment and the
-- processor actually support before anything is shown to a payer.
ALTER TABLE programmes ADD COLUMN enabled_payment_methods TEXT NOT NULL DEFAULT '[]';

-- The processor's customer, so somebody returning after a failed attempt is
-- not created a second time.
ALTER TABLE registrations ADD COLUMN provider_customer_id TEXT;

-- Every attempt to pay tuition, successful or not.
--
-- Deliberately the same shape as event_payments: a failed attempt is evidence
-- rather than something to overwrite, and `verified_at` is written only by the
-- server-side verification path, so a forged callback can never produce a
-- verified row.
CREATE TABLE IF NOT EXISTS programme_payments (
  id TEXT PRIMARY KEY NOT NULL,
  registration_id TEXT NOT NULL REFERENCES registrations(id) ON DELETE CASCADE,
  programme_id TEXT NOT NULL REFERENCES programmes(id) ON DELETE CASCADE,

  provider TEXT NOT NULL DEFAULT 'MANUAL',
  provider_reference TEXT NOT NULL,
  provider_transaction_id TEXT,
  checkout_url TEXT,
  payment_method_key TEXT NOT NULL DEFAULT '',
  -- Transfer details or a USSD string for the payer to act on. No card data
  -- exists on this path, so none can appear here.
  next_action TEXT NOT NULL DEFAULT '{}',

  amount REAL NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'NGN',

  status TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING', 'PROCESSING', 'PAID', 'FAILED', 'CANCELLED', 'REFUNDED')),
  failure_reason TEXT NOT NULL DEFAULT '',
  provider_payload TEXT NOT NULL DEFAULT '{}',

  verified_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_programme_payment_reference
  ON programme_payments (provider_reference);
CREATE INDEX IF NOT EXISTS idx_programme_payment_registration
  ON programme_payments (registration_id, created_at DESC);
