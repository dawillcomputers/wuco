-- Stored country names become ISO codes.
--
-- The country was a free-text field before it became a selector, so some
-- registrations hold "Nigeria" or "France" where the pricing rules expect
-- "NG" and "FR". Those rules read a code: `NG` is naira, `GB` is sterling, a
-- list of European codes is euro, and anything else is dollars.
--
-- A name therefore fell through to "anything else". A registrant in Lagos whose
-- country read "Nigeria" was quoted 185.02 dollars for an event priced at
-- 250,000 naira — the right event, the wrong currency, and a figure nobody at
-- the academy had chosen for them.
--
-- The Worker now normalises names as it reads them, so this is not the fix; it
-- is the tidy-up. Converting the stored values means the rows themselves are
-- right, and a report that groups by country counts one Nigeria rather than
-- two spellings of it.
--
-- Only the names that actually occur are listed. Anything unrecognised is left
-- exactly as it is: a value nobody can interpret is better left visible than
-- quietly replaced with a guess.

UPDATE event_registrations SET country = 'NG' WHERE lower(trim(country)) IN ('nigeria', 'nigerian');
UPDATE event_registrations SET country = 'GH' WHERE lower(trim(country)) = 'ghana';
UPDATE event_registrations SET country = 'FR' WHERE lower(trim(country)) = 'france';
UPDATE event_registrations SET country = 'GB' WHERE lower(trim(country)) IN
  ('united kingdom', 'uk', 'england', 'great britain', 'britain', 'scotland', 'wales');
UPDATE event_registrations SET country = 'US' WHERE lower(trim(country)) IN
  ('united states', 'usa', 'united states of america', 'america');
UPDATE event_registrations SET country = 'KE' WHERE lower(trim(country)) = 'kenya';
UPDATE event_registrations SET country = 'ZA' WHERE lower(trim(country)) = 'south africa';
UPDATE event_registrations SET country = 'CA' WHERE lower(trim(country)) = 'canada';
UPDATE event_registrations SET country = 'DE' WHERE lower(trim(country)) = 'germany';
UPDATE event_registrations SET country = 'IE' WHERE lower(trim(country)) = 'ireland';

-- Users carry a country too, and it is read the same way.
UPDATE users SET country = 'NG' WHERE lower(trim(country)) IN ('nigeria', 'nigerian');
UPDATE users SET country = 'GH' WHERE lower(trim(country)) = 'ghana';
UPDATE users SET country = 'FR' WHERE lower(trim(country)) = 'france';
UPDATE users SET country = 'GB' WHERE lower(trim(country)) IN
  ('united kingdom', 'uk', 'england', 'great britain', 'britain');
UPDATE users SET country = 'US' WHERE lower(trim(country)) IN
  ('united states', 'usa', 'united states of america', 'america');
