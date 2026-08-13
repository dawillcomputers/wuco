-- An event's theme.
--
-- A conference or summit is usually convened around a theme — the line that
-- sits under the title on the banner and in the invitation. It was being typed
-- into the subtitle, which is a different thing and is not labelled for it.

ALTER TABLE events ADD COLUMN theme TEXT NOT NULL DEFAULT '';

-- Note on `format`.
--
-- The three ways to attend are named walk-in, online and hybrid. The stored
-- value for walk-in remains 'PHYSICAL': SQLite cannot alter a CHECK constraint
-- in place, and rebuilding a live table with thirty columns to rename one
-- value would risk real registrations to change a word. The label is applied
-- in the interface — see EventFormat in lib/features/events/domain and the
-- format field in the CMS descriptor.
