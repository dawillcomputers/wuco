import { newId } from './auth';
import { parseJson, str } from './http';

/**
 * Programme registration.
 *
 * The defining behaviour: a returning applicant is never asked again for
 * anything WEA already holds. The account *is* the profile, so registration
 * collects only the programme-specific answers that are missing, and records a
 * snapshot of the applicant as they were at submission.
 */

export interface ApplicantProfile {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  phone: string | null;
  country: string | null;
}

/** Human-readable, non-guessable-in-sequence-per-year application reference. */
export async function nextReference(db: D1Database, prefix = 'WEA') {
  const result = await db
    .prepare('INSERT INTO registration_sequence DEFAULT VALUES')
    .run();
  const sequence = Number(result.meta.last_row_id ?? Date.now());
  const year = new Date().getUTCFullYear();
  return `${prefix}-${year}-${String(sequence).padStart(5, '0')}`;
}

/**
 * What the registration form should ask this applicant.
 *
 * `known` is everything already on file — the client shows it as confirmed
 * rather than as empty inputs. `missing` drives the questions actually asked.
 */
export async function registrationContext(
  db: D1Database,
  user: ApplicantProfile,
  programmeId: string,
) {
  const fields = await db
    .prepare(
      `SELECT * FROM registration_fields
        WHERE programme_id IS NULL OR programme_id = ?1
        ORDER BY sort_order, label`,
    )
    .bind(programmeId)
    .all();

  // Answers this applicant has already given on any earlier registration are
  // reused as defaults, so the second application is materially shorter.
  const previous = await db
    .prepare(
      `SELECT answers FROM registrations WHERE user_id = ?1 ORDER BY created_at DESC LIMIT 5`,
    )
    .bind(user.id)
    .all<{ answers: string }>();

  const remembered: Record<string, unknown> = {};
  for (const row of [...previous.results].reverse()) {
    Object.assign(remembered, parseJson<Record<string, unknown>>(row.answers, {}));
  }

  const known = {
    first_name: user.first_name,
    last_name: user.last_name,
    email: user.email,
    phone: user.phone ?? '',
    country: user.country ?? '',
  };

  const missingProfile = Object.entries(known)
    .filter(([, value]) => str(value) === '')
    .map(([key]) => key);

  return {
    known,
    missing_profile: missingProfile,
    remembered_answers: remembered,
    fields: fields.results.map((field) => ({
      ...field,
      options: parseJson<string[]>(field.options, []),
      required: field.required === 1,
      // Pre-filled from a previous application where one exists.
      prefill: remembered[field.field_key as string] ?? null,
    })),
    // True when nothing but programme-specific questions remain.
    profile_complete: missingProfile.length === 0,
  };
}

export interface SubmitResult {
  ok: boolean;
  code?: string;
  message?: string;
  registration?: Record<string, unknown>;
}

export async function submitRegistration(
  db: D1Database,
  user: ApplicantProfile,
  body: Record<string, unknown>,
): Promise<SubmitResult> {
  const programmeId = str(body.programme_id);
  if (!programmeId) return { ok: false, code: 'INVALID_REQUEST' };

  const programme = await db
    .prepare(
      `SELECT id, title, tuition_amount, tuition_currency, registration_open, status
         FROM programmes WHERE (id = ?1 OR slug = ?1)`,
    )
    .bind(programmeId)
    .first<{
      id: string;
      title: string;
      tuition_amount: number | null;
      tuition_currency: string;
      registration_open: number;
      status: string;
    }>();

  if (!programme || programme.status !== 'PUBLISHED') {
    return { ok: false, code: 'NOT_FOUND' };
  }
  if (programme.registration_open !== 1) {
    return { ok: false, code: 'REGISTRATION_CLOSED' };
  }

  const existing = await db
    .prepare(
      'SELECT id, reference FROM registrations WHERE user_id = ?1 AND programme_id = ?2',
    )
    .bind(user.id, programme.id)
    .first<{ id: string; reference: string }>();
  if (existing) {
    return { ok: false, code: 'ALREADY_REGISTERED', message: existing.reference };
  }

  // Required questions are enforced server-side; the client's own validation is
  // a convenience, not the control.
  const fields = await db
    .prepare(
      `SELECT field_key, label, required FROM registration_fields
        WHERE programme_id IS NULL OR programme_id = ?1`,
    )
    .bind(programme.id)
    .all<{ field_key: string; label: string; required: number }>();

  const answers = (body.answers ?? {}) as Record<string, unknown>;
  for (const field of fields.results) {
    if (field.required === 1 && str(answers[field.field_key]) === '') {
      return { ok: false, code: 'MISSING_ANSWER', message: field.label };
    }
  }

  const paymentMethodId = str(body.payment_method_id) || null;
  let prefix = 'WEA';
  if (paymentMethodId) {
    const method = await db
      .prepare('SELECT reference_prefix FROM payment_methods WHERE id = ?1 AND is_active = 1')
      .bind(paymentMethodId)
      .first<{ reference_prefix: string }>();
    if (!method) return { ok: false, code: 'INVALID_PAYMENT_METHOD' };
    prefix = method.reference_prefix || 'WEA';
  }

  const reference = await nextReference(db, prefix);
  const id = `reg-${newId()}`;

  await db
    .prepare(
      `INSERT INTO registrations
         (id, reference, user_id, programme_id, status, payment_method_id,
          payment_reference, amount, currency, answers, applicant_snapshot)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)`,
    )
    .bind(
      id,
      reference,
      user.id,
      programme.id,
      programme.tuition_amount && programme.tuition_amount > 0
        ? 'AWAITING_PAYMENT'
        : 'SUBMITTED',
      paymentMethodId,
      reference,
      programme.tuition_amount,
      programme.tuition_currency,
      JSON.stringify(answers),
      JSON.stringify({
        first_name: user.first_name,
        last_name: user.last_name,
        email: user.email,
        phone: user.phone,
        country: user.country,
      }),
    )
    .run();

  const row = await db
    .prepare(
      `SELECT r.*, p.title AS programme_title, p.slug AS programme_slug
         FROM registrations r JOIN programmes p ON p.id = r.programme_id
        WHERE r.id = ?1`,
    )
    .bind(id)
    .first();

  return { ok: true, registration: row as Record<string, unknown> };
}

export async function listRegistrations(
  db: D1Database,
  options: { userId?: string; status?: string | null },
) {
  const clauses: string[] = [];
  const binds: unknown[] = [];
  if (options.userId) {
    binds.push(options.userId);
    clauses.push(`r.user_id = ?${binds.length}`);
  }
  if (options.status) {
    binds.push(options.status);
    clauses.push(`r.status = ?${binds.length}`);
  }
  const rows = await db
    .prepare(
      `SELECT r.*, p.title AS programme_title, p.slug AS programme_slug,
              u.email AS applicant_email, u.first_name, u.last_name
         FROM registrations r
         JOIN programmes p ON p.id = r.programme_id
         JOIN users u ON u.id = r.user_id
        ${clauses.length ? `WHERE ${clauses.join(' AND ')}` : ''}
        ORDER BY r.created_at DESC LIMIT 500`,
    )
    .bind(...binds)
    .all();
  return rows.results.map((row) => ({
    ...row,
    answers: parseJson<Record<string, unknown>>(row.answers, {}),
  }));
}

const REVIEWABLE = [
  'SUBMITTED',
  'AWAITING_PAYMENT',
  'PAID',
  'CONFIRMED',
  'WAITLISTED',
  'CANCELLED',
  'DECLINED',
];

/**
 * Gives an applicant their place.
 *
 * Enrolling and promoting are one act, not two: a place that has been paid for
 * but leaves the account an APPLICANT is a place the learner cannot reach.
 * `INSERT OR IGNORE` makes it safe to call again — a payment verified twice,
 * or confirmed by hand after a processor already settled it, must not produce
 * a second enrolment.
 *
 * `granted_by` is null when nobody decided: the payment did.
 */
export async function enrolFromRegistration(
  db: D1Database,
  registration: { user_id: string; programme_id: string },
  grantedBy: string | null,
): Promise<void> {
  await db
    .prepare(
      `INSERT OR IGNORE INTO programme_enrolments
         (id, user_id, programme_id, payment_status, granted_by)
       VALUES (?1, ?2, ?3, 'PAID', ?4)`,
    )
    .bind(
      `enr-${newId()}`,
      registration.user_id,
      registration.programme_id,
      grantedBy,
    )
    .run();

  // An applicant who has been given a place is a learner. Any other role is
  // left alone: a lecturer who enrols on a colleague's programme keeps theirs.
  await db
    .prepare(
      `UPDATE users SET role = 'LEARNER', updated_at = CURRENT_TIMESTAMP
        WHERE id = ?1 AND role = 'APPLICANT'`,
    )
    .bind(registration.user_id)
    .run();
}

/**
 * Super Admin decision on an application. Confirming one — or recording that
 * it has been paid — also enrols the learner and promotes an applicant
 * account, so a place immediately means access.
 */
export async function reviewRegistration(
  db: D1Database,
  reviewerId: string,
  registrationId: string,
  body: Record<string, unknown>,
): Promise<SubmitResult> {
  const status = str(body.status);
  if (!REVIEWABLE.includes(status)) return { ok: false, code: 'INVALID_STATUS' };

  const registration = await db
    .prepare('SELECT * FROM registrations WHERE id = ?1')
    .bind(registrationId)
    .first<{ id: string; user_id: string; programme_id: string }>();
  if (!registration) return { ok: false, code: 'NOT_FOUND' };

  await db
    .prepare(
      `UPDATE registrations
          SET status = ?1, review_note = ?2, reviewed_by = ?3,
              updated_at = CURRENT_TIMESTAMP
        WHERE id = ?4`,
    )
    .bind(status, str(body.review_note), reviewerId, registrationId)
    .run();

  // Paying for a place *is* taking it up. Requiring a separate confirmation
  // after the money has arrived left applicants paid-for but shut out until
  // somebody in the office noticed, so PAID enrols exactly as CONFIRMED does.
  if (status === 'CONFIRMED' || status === 'PAID') {
    await enrolFromRegistration(db, registration, reviewerId);
  }

  const row = await db
    .prepare('SELECT * FROM registrations WHERE id = ?1')
    .bind(registrationId)
    .first();
  return { ok: true, registration: row as Record<string, unknown> };
}
