-- Learner progress, and the rules a lecturer sets about how a course is taken.
--
-- Until now progress existed only in the Flutter application's mock
-- repositories, so nothing survived a refresh and no dashboard could show a
-- real number. This is where it actually lives.
--
-- The gating rules are recorded here rather than in the interface because a
-- rule the client enforces is a rule anybody can skip. The API refuses to
-- open a locked lesson; hiding the button is only a courtesy.

-- ---------------------------------------------------------------------------
-- How a course is taken
-- ---------------------------------------------------------------------------

-- Whether learners may roam or must work through in order.
--
-- FREE is the default so nothing already published changes behaviour: a course
-- becomes sequential because a lecturer chose it, never by upgrade.
ALTER TABLE programmes ADD COLUMN progression_mode TEXT NOT NULL DEFAULT 'FREE'
  CHECK (progression_mode IN ('FREE', 'SEQUENTIAL'));

-- What a module is called in this programme. A short course runs in Modules,
-- an intensive in Days, a summit in Sessions — the same structure, named as
-- the academy names it.
ALTER TABLE programme_modules ADD COLUMN section_type TEXT NOT NULL DEFAULT 'MODULE'
  CHECK (section_type IN ('MODULE', 'SECTION', 'DAY', 'WEEK', 'UNIT'));

-- Per-lesson gating. Both default to off, so an existing lesson is unchanged.
ALTER TABLE programme_lessons
  ADD COLUMN must_complete_to_advance INTEGER NOT NULL DEFAULT 0;

-- For a video: whether it has to be watched through before the lesson counts
-- as complete, and how much of it counts as "through". Ninety percent by
-- default, because credits and a trailing silence should not strand somebody
-- one percent short.
ALTER TABLE programme_lessons ADD COLUMN must_watch_fully INTEGER NOT NULL DEFAULT 0;
ALTER TABLE programme_lessons ADD COLUMN min_watch_percent INTEGER NOT NULL DEFAULT 90;

-- Whether a learner may move on while this is still open. A lesson can be
-- required without being a wall — reading matters, but it need not block.
ALTER TABLE programme_lessons ADD COLUMN is_optional INTEGER NOT NULL DEFAULT 0;

-- ---------------------------------------------------------------------------
-- What a learner has done
-- ---------------------------------------------------------------------------

-- One row per learner per lesson.
--
-- `watched_seconds` is the furthest point reached, not the sum of time spent:
-- scrubbing backwards and watching again must not accumulate progress that was
-- never made, and a learner who rewatches should not be penalised either.
CREATE TABLE IF NOT EXISTS lesson_progress (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lesson_id TEXT NOT NULL REFERENCES programme_lessons(id) ON DELETE CASCADE,
  -- Denormalised so a programme's progress is one query rather than a join
  -- through every module.
  programme_id TEXT NOT NULL REFERENCES programmes(id) ON DELETE CASCADE,

  state TEXT NOT NULL DEFAULT 'NOT_STARTED'
    CHECK (state IN ('NOT_STARTED', 'IN_PROGRESS', 'COMPLETED')),

  /* Furthest position reached in a video, in seconds. */
  watched_seconds INTEGER NOT NULL DEFAULT 0,
  /* Furthest percentage reached, 0–100. What the gate is judged on. */
  watched_percent INTEGER NOT NULL DEFAULT 0,

  first_opened_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_lesson_progress_unique
  ON lesson_progress (user_id, lesson_id);
CREATE INDEX IF NOT EXISTS idx_lesson_progress_programme
  ON lesson_progress (user_id, programme_id);
-- Supports the staff dashboard: everybody's progress on one programme.
CREATE INDEX IF NOT EXISTS idx_lesson_progress_cohort
  ON lesson_progress (programme_id, state);

-- ---------------------------------------------------------------------------
-- Lecturer assignment
-- ---------------------------------------------------------------------------

-- Which programmes a lecturer teaches.
--
-- The same shape as event_managers, and for the same reason: the role grants
-- the verbs, the assignment decides what they apply to. A lecturer with no
-- rows here teaches nothing.
CREATE TABLE IF NOT EXISTS programme_lecturers (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  programme_id TEXT NOT NULL REFERENCES programmes(id) ON DELETE CASCADE,
  -- Whether they may publish, beyond editing their own material.
  can_publish INTEGER NOT NULL DEFAULT 0,
  assigned_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_programme_lecturer
  ON programme_lecturers (user_id, programme_id);
CREATE INDEX IF NOT EXISTS idx_programme_lecturer_programme
  ON programme_lecturers (programme_id);
