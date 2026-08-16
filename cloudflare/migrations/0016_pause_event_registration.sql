-- A switch to stop taking registrations without unpublishing the event.
--
-- Publishing an event opens registration. It then stays open until one of
-- three things happens, and now there are three rather than two:
--
--   the closing date passes, the event fills up, or somebody pauses it.
--
-- Pausing existed only as unpublishing before, which took the event page down
-- with it — so an academy that wanted to stop the queue for an afternoon had
-- to hide the event from everyone who had already been sent the link. This
-- keeps the page up, and the announcements and the agenda with it, while the
-- registration form says plainly that bookings are paused.
--
-- `registration_opens_at` remains the other way round: an event published in
-- advance whose bookings open later. Left empty — which is the default and
-- what almost every event should have — publishing opens registration
-- immediately.

ALTER TABLE events ADD COLUMN registration_paused INTEGER NOT NULL DEFAULT 0;
