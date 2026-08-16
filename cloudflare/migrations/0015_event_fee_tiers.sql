-- Registration fees that vary by when you book and how you attend.
--
--   Early Bird   Physical  ₦150,000    Virtual  ₦100,000
--   Standard     Physical  ₦180,000    Virtual  ₦130,000
--
-- Two dimensions, and they are different kinds of thing, which is why they are
-- modelled differently rather than as a flat grid of four numbers:
--
--   *How you attend* is a choice the registrant makes. It only exists as a
--   choice on a HYBRID event; a PHYSICAL or ONLINE event has one mode and
--   nothing to ask.
--
--   *Which tier you get* is not a choice at all. The date decides it. Nobody
--   picks Early Bird — they either registered in time or they did not, and the
--   server is the only thing entitled to that opinion.
--
-- So a fee row is: a mode it applies to, a window it is available in, and a
-- price in each currency the academy sells in. "Early Bird" is simply the
-- label of a row whose window ends; "Standard" is the row with no end date.
-- Adding a member rate or a late fee later is another row, not a schema change.

CREATE TABLE IF NOT EXISTS event_prices (
  id TEXT PRIMARY KEY NOT NULL,
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,

  -- Shown to the registrant as the name of what they are paying.
  tier_label TEXT NOT NULL DEFAULT 'Standard',

  -- ANY is for an event with only one way to attend, so a PHYSICAL or ONLINE
  -- event needs one row per tier rather than two identical ones.
  attendance_mode TEXT NOT NULL DEFAULT 'ANY'
    CHECK (attendance_mode IN ('ANY', 'PHYSICAL', 'VIRTUAL')),

  -- Currency map, exactly as the `prices` columns elsewhere: {"NGN": 150000}.
  -- WEA never converts, so a currency absent here is one this tier is not
  -- sold in.
  prices TEXT NOT NULL DEFAULT '{}',

  -- The window this fee is available in. Both open by default: a row with
  -- neither is the fallback that always applies, which is what "Standard"
  -- normally is.
  available_from TEXT,
  available_until TEXT,

  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_event_prices_event
  ON event_prices (event_id, sort_order);

-- Which of the two the registrant chose, so a receipt, a badge and a joining
-- link all agree about whether somebody is coming to the room or watching.
--
-- Empty on an event with only one mode: there was nothing to choose, and
-- recording a choice nobody made would be a fiction.
ALTER TABLE event_registrations ADD COLUMN attendance_mode TEXT NOT NULL DEFAULT '';

-- Deliberately no backfill.
--
-- An event with no rows here keeps using `fee_amount` / `fee_currency` /
-- `prices` exactly as before, and is treated as a single unnamed tier
-- available in any mode. So every event that exists today goes on charging
-- what it charges now, and an administrator opts into tiers by adding rows
-- when they want them — rather than by having a migration invent a pricing
-- structure for events nobody has looked at.
