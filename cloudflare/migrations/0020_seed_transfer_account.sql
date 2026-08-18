-- The academy's own bank account, on the events that have none.
--
--   Zenith Bank Plc
--   World United Consumer Organisation
--   1017081110
--
-- These are already held once, on the `pay-bank-transfer` row in
-- `payment_methods`, which is where they are kept for reuse: a creator setting
-- up a new event copies them from there, or types different ones where the
-- money should land somewhere else.
--
-- Seeded from that row rather than written out again, so there is one place
-- the academy's account is recorded and this migration cannot disagree with
-- it. An event that already has an account number keeps it — this fills a gap
-- rather than overwriting a decision.

UPDATE events
   SET manual_account_name = COALESCE(
         (SELECT account_name FROM payment_methods WHERE id = 'pay-bank-transfer'),
         ''
       ),
       manual_bank_name = COALESCE(
         (SELECT bank_name FROM payment_methods WHERE id = 'pay-bank-transfer'),
         ''
       ),
       manual_account_number = COALESCE(
         (SELECT account_number FROM payment_methods WHERE id = 'pay-bank-transfer'),
         ''
       ),
       manual_transfer_enabled = 1,
       manual_proof_required = 1,
       updated_at = CURRENT_TIMESTAMP
 WHERE manual_account_number = ''
   AND status IN ('PUBLISHED', 'DRAFT')
   AND EXISTS (
     SELECT 1 FROM payment_methods
      WHERE id = 'pay-bank-transfer' AND account_number <> ''
   );
