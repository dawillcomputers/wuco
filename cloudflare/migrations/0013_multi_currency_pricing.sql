-- Prices fixed in more than one currency.
--
-- The academy sets what a place costs in each currency it sells in. WEA never
-- converts: an exchange rate we invented would be wrong by the time somebody
-- paid it, and a payer would be charged a number nobody at the academy chose.
-- A currency with no price set is simply not offered.
--
-- Stored as a JSON object of currency to amount, e.g.
--   {"NGN": 250000, "USD": 150}
--
-- `fee_amount` / `fee_currency` and `tuition_amount` / `tuition_currency`
-- remain the base price, and are folded in automatically, so nothing already
-- published loses its price or has to be re-entered.

ALTER TABLE events ADD COLUMN prices TEXT NOT NULL DEFAULT '{}';
ALTER TABLE programmes ADD COLUMN prices TEXT NOT NULL DEFAULT '{}';

-- What the payer chose to be charged in, kept so a receipt and a refund can
-- speak the same currency the payment did.
ALTER TABLE event_registrations ADD COLUMN chosen_currency TEXT NOT NULL DEFAULT '';
ALTER TABLE registrations ADD COLUMN chosen_currency TEXT NOT NULL DEFAULT '';

-- The per-item list of enabled payment methods is no longer consulted.
--
-- Requiring an administrator to enable methods per event and per programme
-- meant a new event silently offered nothing, and it duplicated a decision
-- the Flutterwave account already holds. What a payer may use now follows
-- from the currency they are paying in and what the account supports. The
-- columns are left in place rather than dropped: removing them would rebuild
-- two live tables to delete something that is merely ignored.
