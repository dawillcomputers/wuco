/**
 * Taking a course: what a learner has done, and what they are allowed to open
 * next.
 *
 * The rule that shapes this module is that **the gate is here, not in the
 * interface**. A sequential course that only hides the next button is not
 * sequential — anyone can type the URL. So `openLesson` refuses a locked
 * lesson, and the interface's job is merely to explain why rather than to
 * enforce it.
 *
 * The second rule is that progress is never inflated. A video records the
 * furthest point reached, so scrubbing backwards and watching again adds
 * nothing, and a learner who rewatches loses nothing.
 */

import { newId } from './auth';
import { num, str } from './http';

export interface Learner {
  id: string;
  role: string;
}

export interface LearningResult {
  ok: boolean;
  code?: string;
  message?: string;
  data?: Record<string, unknown>;
}

interface LessonRow {
  id: string;
  module_id: string;
  programme_id: string;
  title: string;
  number: number;
  lesson_type: string;
  duration_minutes: number;
  is_preview: number;
  is_optional: number;
  must_complete_to_advance: number;
  must_watch_fully: number;
  min_watch_percent: number;
  module_sort: number;
  lesson_sort: number;
}

/**
 * Every lesson of a programme in the order it is taken, flattened across
 * modules. The order is what "the previous lesson" means, so it is decided
 * here once rather than in each caller.
 */
async function orderedLessons(
  db: D1Database,
  programmeId: string,
): Promise<LessonRow[]> {
  const rows = await db
    .prepare(
      `SELECT l.id, l.module_id, m.programme_id, l.title, l.number,
              l.lesson_type, l.duration_minutes, l.is_preview, l.is_optional,
              l.must_complete_to_advance, l.must_watch_fully,
              l.min_watch_percent,
              m.sort_order AS module_sort, l.sort_order AS lesson_sort
         FROM programme_lessons l
         JOIN programme_modules m ON m.id = l.module_id
        WHERE m.programme_id = ?1
        ORDER BY m.sort_order, m.number, l.sort_order, l.number`,
    )
    .bind(programmeId)
    .all<LessonRow>();
  return rows.results;
}

async function progressFor(
  db: D1Database,
  userId: string,
  programmeId: string,
): Promise<Map<string, Record<string, unknown>>> {
  const rows = await db
    .prepare(
      `SELECT lesson_id, state, watched_seconds, watched_percent, completed_at
         FROM lesson_progress WHERE user_id = ?1 AND programme_id = ?2`,
    )
    .bind(userId, programmeId)
    .all<Record<string, unknown>>();
  return new Map(rows.results.map((row) => [str(row.lesson_id), row]));
}

/** Whether a lesson counts as done, by its own rules. */
function isComplete(
  lesson: LessonRow,
  progress: Record<string, unknown> | undefined,
): boolean {
  if (!progress) return false;
  if (str(progress.state) !== 'COMPLETED') return false;
  // A video that must be watched through is not complete until it has been,
  // whatever the state column says — the two are written together, and this
  // is the check that survives a bad write.
  if (lesson.must_watch_fully === 1) {
    return (num(progress.watched_percent) ?? 0) >= lesson.min_watch_percent;
  }
  return true;
}

/**
 * Why a lesson is locked, or null when it is open.
 *
 * Only the lesson immediately before matters, and only when it was marked as
 * one that must be completed to advance. A course is not made sequential by
 * locking everything: it is made sequential by each step insisting on the one
 * before it.
 */
function lockReason(
  lessons: LessonRow[],
  index: number,
  progress: Map<string, Record<string, unknown>>,
  sequential: boolean,
): string | null {
  if (index === 0) return null;
  const lesson = lessons[index];
  // A free preview is always open; it is what a visitor is shown.
  if (lesson.is_preview === 1) return null;
  if (!sequential) {
    // Even in a free course, a lesson explicitly marked as a gate holds.
    const previous = lessons[index - 1];
    if (previous.must_complete_to_advance !== 1) return null;
    return isComplete(previous, progress.get(previous.id))
      ? null
      : `Finish “${previous.title}” first.`;
  }

  // Sequential: every earlier lesson that is neither optional nor already
  // complete blocks, and the learner is told about the first one.
  for (let earlier = 0; earlier < index; earlier += 1) {
    const step = lessons[earlier];
    if (step.is_optional === 1) continue;
    if (!isComplete(step, progress.get(step.id))) {
      return `Finish “${step.title}” first.`;
    }
  }
  return null;
}

/**
 * A learner's view of a programme: every lesson, what they have done, and
 * what is open to them.
 */
export async function programmeProgress(
  db: D1Database,
  userId: string,
  programmeId: string,
): Promise<Record<string, unknown> | null> {
  const programme = await db
    .prepare('SELECT id, title, slug, progression_mode FROM programmes WHERE id = ?1 OR slug = ?1')
    .bind(programmeId)
    .first<{ id: string; title: string; slug: string; progression_mode: string }>();
  if (!programme) return null;

  const lessons = await orderedLessons(db, programme.id);
  const progress = await progressFor(db, userId, programme.id);
  const sequential = programme.progression_mode === 'SEQUENTIAL';

  const items = lessons.map((lesson, index) => {
    const own = progress.get(lesson.id);
    const locked = lockReason(lessons, index, progress, sequential);
    return {
      lesson_id: lesson.id,
      module_id: lesson.module_id,
      title: lesson.title,
      lesson_type: lesson.lesson_type,
      duration_minutes: lesson.duration_minutes,
      state: str(own?.state) || 'NOT_STARTED',
      watched_seconds: num(own?.watched_seconds) ?? 0,
      watched_percent: num(own?.watched_percent) ?? 0,
      complete: isComplete(lesson, own),
      is_optional: lesson.is_optional === 1,
      is_preview: lesson.is_preview === 1,
      must_watch_fully: lesson.must_watch_fully === 1,
      min_watch_percent: lesson.min_watch_percent,
      locked: locked !== null,
      locked_reason: locked,
    };
  });

  const required = items.filter((item) => !item.is_optional);
  const done = required.filter((item) => item.complete).length;

  return {
    programme_id: programme.id,
    programme_title: programme.title,
    progression_mode: programme.progression_mode,
    lessons: items,
    completed_lessons: done,
    total_lessons: required.length,
    // Derived, never stored: a percentage that can disagree with the lessons
    // it came from is worse than none.
    progress_percent: required.length === 0 ? 0 : Math.round((done / required.length) * 100),
    // The lesson to resume on — the first that is open and unfinished.
    next_lesson_id:
      items.find((item) => !item.complete && !item.locked)?.lesson_id ?? null,
  };
}

/**
 * Opens a lesson, or refuses.
 *
 * This is the gate. A learner who guesses the URL of a locked lesson is
 * refused here, which is the only place refusing it means anything.
 */
export async function openLesson(
  db: D1Database,
  userId: string,
  lessonId: string,
): Promise<LearningResult> {
  const lesson = await db
    .prepare(
      `SELECT l.*, m.programme_id, p.progression_mode
         FROM programme_lessons l
         JOIN programme_modules m ON m.id = l.module_id
         JOIN programmes p ON p.id = m.programme_id
        WHERE l.id = ?1`,
    )
    .bind(lessonId)
    .first<Record<string, unknown>>();
  if (!lesson) return { ok: false, code: 'NOT_FOUND' };

  const programmeId = str(lesson.programme_id);

  // Enrolment first: a locked lesson and a lesson on somebody else's
  // programme are both refused, and for the stronger reason.
  const enrolled = await db
    .prepare(
      'SELECT id FROM programme_enrolments WHERE user_id = ?1 AND programme_id = ?2',
    )
    .bind(userId, programmeId)
    .first();
  if (!enrolled && lesson.is_preview !== 1) {
    return { ok: false, code: 'NOT_ENROLLED' };
  }

  const lessons = await orderedLessons(db, programmeId);
  const index = lessons.findIndex((row) => row.id === lessonId);
  const progress = await progressFor(db, userId, programmeId);
  const locked = lockReason(
    lessons,
    index,
    progress,
    str(lesson.progression_mode) === 'SEQUENTIAL',
  );
  if (locked) return { ok: false, code: 'LESSON_LOCKED', message: locked };

  // Opening it is itself progress, so the row exists from the first view and
  // "started but not finished" is a state the academy can see.
  await db
    .prepare(
      `INSERT INTO lesson_progress (id, user_id, lesson_id, programme_id, state)
       VALUES (?1, ?2, ?3, ?4, 'IN_PROGRESS')
       ON CONFLICT(user_id, lesson_id) DO UPDATE
         SET last_seen_at = CURRENT_TIMESTAMP,
             state = CASE WHEN state = 'NOT_STARTED' THEN 'IN_PROGRESS' ELSE state END,
             updated_at = CURRENT_TIMESTAMP`,
    )
    .bind(`lp-${newId()}`, userId, lessonId, programmeId)
    .run();

  return {
    ok: true,
    data: {
      lesson_id: lessonId,
      body: str(lesson.body),
      media_key: lesson.media_key,
      resource_url: lesson.resource_url,
      lesson_type: str(lesson.lesson_type),
      must_watch_fully: lesson.must_watch_fully === 1,
      min_watch_percent: num(lesson.min_watch_percent) ?? 90,
      resume_at_seconds: num(progress.get(lessonId)?.watched_seconds) ?? 0,
    },
  };
}

/**
 * Records how far through a lesson somebody has got.
 *
 * Position only ever moves forward: the furthest point reached is what was
 * actually covered, and rewinding to rewatch must neither add progress nor
 * take it away. Completion is decided here from the lesson's own rule, not
 * taken from the client — a player that claims to have finished is exactly
 * what "must be watched fully" exists to disbelieve.
 */
export async function recordProgress(
  db: D1Database,
  userId: string,
  lessonId: string,
  body: Record<string, unknown>,
): Promise<LearningResult> {
  const lesson = await db
    .prepare(
      `SELECT l.id, l.must_watch_fully, l.min_watch_percent, l.lesson_type,
              m.programme_id
         FROM programme_lessons l
         JOIN programme_modules m ON m.id = l.module_id
        WHERE l.id = ?1`,
    )
    .bind(lessonId)
    .first<Record<string, unknown>>();
  if (!lesson) return { ok: false, code: 'NOT_FOUND' };

  const programmeId = str(lesson.programme_id);
  const seconds = Math.max(0, Math.floor(num(body.watched_seconds) ?? 0));
  const percent = Math.min(100, Math.max(0, Math.floor(num(body.watched_percent) ?? 0)));
  const claimsComplete = body.completed === true;

  const mustWatch = lesson.must_watch_fully === 1;
  const threshold = num(lesson.min_watch_percent) ?? 90;

  // The client may say it finished; whether that is accepted depends on the
  // rule the lecturer set.
  const completed = mustWatch ? percent >= threshold : claimsComplete;

  await db
    .prepare(
      `INSERT INTO lesson_progress
         (id, user_id, lesson_id, programme_id, state, watched_seconds,
          watched_percent, completed_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7,
               CASE WHEN ?5 = 'COMPLETED' THEN CURRENT_TIMESTAMP ELSE NULL END)
       ON CONFLICT(user_id, lesson_id) DO UPDATE
         SET watched_seconds = MAX(lesson_progress.watched_seconds, excluded.watched_seconds),
             watched_percent = MAX(lesson_progress.watched_percent, excluded.watched_percent),
             state = CASE
               WHEN lesson_progress.state = 'COMPLETED' THEN 'COMPLETED'
               ELSE excluded.state END,
             completed_at = COALESCE(lesson_progress.completed_at, excluded.completed_at),
             last_seen_at = CURRENT_TIMESTAMP,
             updated_at = CURRENT_TIMESTAMP`,
    )
    .bind(
      `lp-${newId()}`,
      userId,
      lessonId,
      programmeId,
      completed ? 'COMPLETED' : 'IN_PROGRESS',
      seconds,
      percent,
    )
    .run();

  const row = await db
    .prepare(
      `SELECT state, watched_seconds, watched_percent, completed_at
         FROM lesson_progress WHERE user_id = ?1 AND lesson_id = ?2`,
    )
    .bind(userId, lessonId)
    .first();

  return {
    ok: true,
    data: {
      progress: row,
      // Says plainly why a lesson the learner thinks they finished is not
      // complete, rather than leaving them to guess.
      blocked_by_watch_rule: mustWatch && claimsComplete && percent < threshold,
      min_watch_percent: threshold,
    },
  };
}

// ---------------------------------------------------------------------------
// Teaching
// ---------------------------------------------------------------------------

/** The programmes a lecturer is assigned to teach. */
export async function assignedProgrammes(db: D1Database, userId: string) {
  const rows = await db
    .prepare(
      `SELECT p.id, p.title, p.slug, p.status, p.progression_mode,
              pl.can_publish,
              (SELECT COUNT(*) FROM programme_enrolments e
                WHERE e.programme_id = p.id) AS learners
         FROM programme_lecturers pl
         JOIN programmes p ON p.id = pl.programme_id
        WHERE pl.user_id = ?1
        ORDER BY p.title`,
    )
    .bind(userId)
    .all();
  return rows.results;
}

/** Whether this lecturer may edit a programme's teaching content. */
export async function canTeach(
  db: D1Database,
  actor: Learner,
  programmeId: string,
  publishing = false,
): Promise<boolean> {
  // An owner, super admin or administrator may act on any programme.
  if (['OWNER', 'SUPER_ADMIN', 'ADMIN'].includes(actor.role)) return true;
  if (actor.role !== 'LECTURER') return false;

  const assignment = await db
    .prepare(
      'SELECT can_publish FROM programme_lecturers WHERE user_id = ?1 AND programme_id = ?2',
    )
    .bind(actor.id, programmeId)
    .first<{ can_publish: number }>();
  if (!assignment) return false;
  return publishing ? assignment.can_publish === 1 : true;
}

/**
 * How a cohort is getting on, for the teaching dashboard.
 *
 * One row per learner with their own percentage, so a lecturer can see who has
 * stalled rather than only an average that hides them.
 */
export async function cohortProgress(db: D1Database, programmeId: string) {
  const total = await db
    .prepare(
      `SELECT COUNT(*) AS total
         FROM programme_lessons l
         JOIN programme_modules m ON m.id = l.module_id
        WHERE m.programme_id = ?1 AND l.is_optional = 0`,
    )
    .bind(programmeId)
    .first<{ total: number }>();

  const rows = await db
    .prepare(
      `SELECT u.id, u.first_name, u.last_name, u.email,
              COUNT(CASE WHEN lp.state = 'COMPLETED' THEN 1 END) AS completed,
              MAX(lp.last_seen_at) AS last_seen
         FROM programme_enrolments e
         JOIN users u ON u.id = e.user_id
         LEFT JOIN lesson_progress lp
           ON lp.user_id = u.id AND lp.programme_id = e.programme_id
        WHERE e.programme_id = ?1
        GROUP BY u.id
        ORDER BY completed DESC, u.first_name`,
    )
    .bind(programmeId)
    .all<Record<string, unknown>>();

  const lessons = total?.total ?? 0;
  return {
    total_lessons: lessons,
    learners: rows.results.map((row) => ({
      ...row,
      progress_percent:
        lessons === 0 ? 0 : Math.round(((num(row.completed) ?? 0) / lessons) * 100),
    })),
  };
}
