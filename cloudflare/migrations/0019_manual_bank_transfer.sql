-- Paying an event fee by bank transfer, into the academy's own account.
--
-- A card is the only way to pay from outside Nigeria, and it is the fastest way
-- from inside it. But a great many Nigerian payers would rather move money
-- between banks than hand a card to a checkout, and refusing that costs
-- registrations the academy would otherwise have.
--
-- Flutterwave has its own bank-transfer rail, and this is deliberately not it.
-- That one creates a temporary virtual account and settles into the processor;
-- this one is a transfer into an account the academy already holds, matched by
-- hand. The two would confuse each other in a list, so only this one is shown.
--
-- The account is per event rather than compiled in, because an academy runs
-- events for different bodies and the money should not always land in the same
-- place. A creator sets it on the event; nothing here is a constant.

-- --------------------------------------------------------------------------
-- What the event creator configures
-- --------------------------------------------------------------------------

ALTER TABLE events ADD COLUMN manual_transfer_enabled INTEGER NOT NULL DEFAULT 0;
ALTER TABLE events ADD COLUMN manual_account_name TEXT NOT NULL DEFAULT '';
ALTER TABLE events ADD COLUMN manual_bank_name TEXT NOT NULL DEFAULT '';
ALTER TABLE events ADD COLUMN manual_account_number TEXT NOT NULL DEFAULT '';
ALTER TABLE events ADD COLUMN manual_transfer_instructions TEXT NOT NULL DEFAULT '';

-- Whether a receipt has to be uploaded before the office will look at it.
--
-- On by default: without a receipt an administrator is matching a name against
-- a bank statement by hand, and the receipt is what makes that a minute's work
-- rather than an investigation.
ALTER TABLE events ADD COLUMN manual_proof_required INTEGER NOT NULL DEFAULT 1;

-- --------------------------------------------------------------------------
-- What the registrant does
-- --------------------------------------------------------------------------

-- Which way they chose to pay. Empty until they choose.
--
-- Kept because the two paths end differently: a card payment is confirmed by
-- the processor, and a transfer is confirmed by somebody at the academy
-- reading a receipt. A registration that does not remember which it was cannot
-- be chased correctly.
ALTER TABLE event_registrations ADD COLUMN payment_choice TEXT NOT NULL DEFAULT ''
  CHECK (payment_choice IN ('', 'CARD', 'TRANSFER'));

-- The receipt, in R2, and when it arrived.
ALTER TABLE event_registrations ADD COLUMN payment_proof_key TEXT;
ALTER TABLE event_registrations ADD COLUMN payment_proof_uploaded_at TEXT;

-- Why a transfer was refused, so the registrant can be told something better
-- than "declined" and can try again.
ALTER TABLE event_registrations ADD COLUMN payment_rejected_reason TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_event_registrations_awaiting_proof
  ON event_registrations (payment_choice, payment_status);

-- A transfer is never treated as paid on the registrant's word.
--
-- `payment_status = 'PAID'` is still written in one place only, and for a
-- transfer that place is an administrator approving it. The system cannot
-- confirm that money arrived in a bank account it cannot see, and pretending
-- otherwise would let anybody claim a place by uploading a picture.
