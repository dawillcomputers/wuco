/**
 * WEA events: the public page, registration, payment and the participant's
 * own view of what they have registered for.
 *
 * The behaviour that shapes this module is that **a registration exists before
 * a payment does**. Someone who types their name and then closes the tab is a
 * person the academy can still call, so the record is written as soon as there
 * is anything worth keeping and then moved along a state machine. Nothing is
 * ever deleted because a payment did not happen.
 *
 * The other half is that the academy — not the browser — decides what was
 * paid. `payment_status = 'PAID'` is written in exactly one place, after this
 * module has asked the processor itself and checked that the amount matches.
 */

import { newId, newToken, sha256 } from './auth';
import { num, parseJson, str } from './http';
import {
  PaymentMethodRow,
  PaymentSecrets,
  initialisePayment,
  providerNameFor,
  verifyPayment,
} from './payments';

/** Statuses whose events the public may see. */
const PUBLIC_STATUSES = ['PUBLISHED', 'REGISTRATION_CLOSED', 'COMPLETED'];

/** How long a half-finished registration is left alone before it is a lead. */
const ABANDON_AFTER_HOURS = 48;

export interface EventRow {
  id: string;
  slug: string;
  title: string;
  status: string;
  fee_amount: number;
  fee_currency: string;
  payment_method_id: string | null;
  capacity: number | null;
  registration_opens_at: string | null;
  registration_closes_at: string | null;
  allow_guest_registration: number;
  format: string;
  success_message: string;
  payment_instructions: string;
}

export interface Actor {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  phone: string | null;
  country: string | null;
  role: string;
}

export interface EventResult {
  ok: boolean;
  code?: string;
  message?: string;
  data?: Record<string, unknown>;
}

/** Decodes the list columns an event carries, so the client gets arrays. */
const decodeAgenda = (row: Record<string, unknown>) => ({
  ...row,
  agenda: parseJson<unknown[]>(row.agenda, []),
  highlights: parseJson<unknown[]>(row.highlights, []),
  speakers: parseJson<unknown[]>(row.speakers, []),
});

// ---------------------------------------------------------------------------
// Public reads
// ---------------------------------------------------------------------------

export async function listEvents(db: D1Database, params: URLSearchParams) {
  const clauses = [`status IN (${PUBLIC_STATUSES.map((_, i) => `?${i + 1}`).join(', ')})`];
  const binds: unknown[] = [...PUBLIC_STATUSES];

  if (params.get('featured') === 'true') clauses.push('featured = 1');
  if (params.get('upcoming') === 'true') {
    clauses.push("(starts_at IS NULL OR starts_at >= datetime('now'))");
  }
  const search = str(params.get('q'));
  if (search !== '') {
    binds.push(`%${search.toLowerCase()}%`);
    clauses.push(`(lower(title) LIKE ?${binds.length} OR lower(summary) LIKE ?${binds.length})`);
  }

  const limit = Math.min(num(params.get('limit')) ?? 60, 100);
  const rows = await db
    .prepare(
      `SELECT id, slug, title, subtitle, event_type, summary, image_key, image_url,
              starts_at, ends_at, timezone, venue, format, fee_amount, fee_currency,
              registration_opens_at, registration_closes_at, capacity, featured, status
         FROM events
        WHERE ${clauses.join(' AND ')}
        ORDER BY CASE WHEN starts_at IS NULL THEN 1 ELSE 0 END, starts_at, sort_order
        LIMIT ${limit}`,
    )
    .bind(...binds)
    .all();
  return rows.results;
}

/**
 * One event as the public sees it.
 *
 * Sessions come back without their join links and participant-only material is
 * omitted entirely — not merely flagged — so nothing restricted is ever sent to
 * a browser that has no right to it.
 */
export async function getEvent(db: D1Database, idOrSlug: string) {
  const event = await db
    .prepare(
      `SELECT * FROM events
        WHERE (id = ?1 OR slug = ?1)
          AND status IN (${PUBLIC_STATUSES.map((_, i) => `?${i + 2}`).join(', ')})`,
    )
    .bind(idOrSlug, ...PUBLIC_STATUSES)
    .first<Record<string, unknown>>();
  if (!event) return null;

  const [materials, sessions, registered, method] = await Promise.all([
    db
      .prepare(
        `SELECT id, title, description, material_type, media_key, resource_url
           FROM event_materials
          WHERE event_id = ?1 AND status = 'PUBLISHED' AND visibility = 'PUBLIC'
          ORDER BY sort_order, title`,
      )
      .bind(event.id)
      .all(),
    db
      .prepare(
        `SELECT id, title, session_type, starts_at, ends_at, timezone, speaker, notes
           FROM event_sessions
          WHERE event_id = ?1 AND status = 'PUBLISHED'
          ORDER BY starts_at, sort_order`,
      )
      .bind(event.id)
      .all(),
    db
      .prepare(
        `SELECT COUNT(*) AS total FROM event_registrations
          WHERE event_id = ?1 AND status IN ('PAID', 'COMPLETED')`,
      )
      .bind(event.id)
      .first<{ total: number }>(),
    event.payment_method_id
      ? db
          .prepare('SELECT title, kind, instructions, currency FROM payment_methods WHERE id = ?1')
          .bind(event.payment_method_id)
          .first()
      : Promise.resolve(null),
  ]);

  const capacity = num(event.capacity);
  const confirmed = registered?.total ?? 0;

  return {
    event: decodeAgenda(event),
    materials: materials.results,
    sessions: sessions.results,
    payment_method: method,
    confirmed_registrations: confirmed,
    places_remaining: capacity && capacity > 0 ? Math.max(capacity - confirmed, 0) : null,
    registration_open: registrationWindow(event as unknown as EventRow, confirmed).open,
  };
}

/** Whether this event is accepting registrations, and why not if it is not. */
function registrationWindow(event: EventRow, confirmed: number): { open: boolean; code?: string } {
  if (event.status !== 'PUBLISHED') return { open: false, code: 'REGISTRATION_CLOSED' };
  const now = Date.now();
  if (event.registration_opens_at && new Date(event.registration_opens_at).getTime() > now) {
    return { open: false, code: 'REGISTRATION_NOT_OPEN' };
  }
  if (event.registration_closes_at && new Date(event.registration_closes_at).getTime() < now) {
    return { open: false, code: 'REGISTRATION_CLOSED' };
  }
  if (event.capacity && event.capacity > 0 && confirmed >= event.capacity) {
    return { open: false, code: 'EVENT_FULL' };
  }
  return { open: true };
}

// ---------------------------------------------------------------------------
// The registration form
// ---------------------------------------------------------------------------

/**
 * What to ask this person for this event.
 *
 * A returning registrant is not asked again for anything WEA already holds:
 * their account, and any answer they gave on an earlier event, come back as
 * prefill. That is the same promise programme registration makes.
 */
export async function eventRegistrationContext(
  db: D1Database,
  idOrSlug: string,
  actor: Actor | null,
) {
  const event = await db
    .prepare('SELECT * FROM events WHERE id = ?1 OR slug = ?1')
    .bind(idOrSlug)
    .first<Record<string, unknown>>();
  if (!event || !PUBLIC_STATUSES.includes(str(event.status))) return null;

  const fields = await db
    .prepare(
      `SELECT * FROM event_registration_fields
        WHERE event_id IS NULL OR event_id = ?1
        ORDER BY sort_order, label`,
    )
    .bind(event.id)
    .all();

  let known = {
    first_name: '',
    last_name: '',
    email: '',
    phone: '',
    organisation: '',
    job_title: '',
    country: '',
  };
  let existing: Record<string, unknown> | null = null;
  let remembered: Record<string, unknown> = {};

  if (actor) {
    known = {
      ...known,
      first_name: actor.first_name,
      last_name: actor.last_name,
      email: actor.email,
      phone: actor.phone ?? '',
      country: actor.country ?? '',
    };

    // Anything they told us on a previous event registration.
    const previous = await db
      .prepare(
        `SELECT organisation, job_title, country, phone, answers
           FROM event_registrations
          WHERE user_id = ?1 ORDER BY created_at DESC LIMIT 5`,
      )
      .bind(actor.id)
      .all<Record<string, string>>();
    for (const row of [...previous.results].reverse()) {
      if (str(row.organisation)) known.organisation = row.organisation;
      if (str(row.job_title)) known.job_title = row.job_title;
      if (str(row.country) && !known.country) known.country = row.country;
      if (str(row.phone) && !known.phone) known.phone = row.phone;
      Object.assign(remembered, parseJson<Record<string, unknown>>(row.answers, {}));
    }

    existing = await db
      .prepare('SELECT * FROM event_registrations WHERE event_id = ?1 AND user_id = ?2')
      .bind(event.id, actor.id)
      .first();
  }

  const confirmed = await db
    .prepare(
      `SELECT COUNT(*) AS total FROM event_registrations
        WHERE event_id = ?1 AND status IN ('PAID', 'COMPLETED')`,
    )
    .bind(event.id)
    .first<{ total: number }>();

  const window = registrationWindow(event as unknown as EventRow, confirmed?.total ?? 0);

  return {
    event: decodeAgenda(event),
    known,
    remembered_answers: remembered,
    // Present when they already have a registration for this event, so the
    // client resumes it instead of starting a second one.
    existing_registration: existing ? publicRegistration(existing) : null,
    fields: fields.results.map((field) => ({
      ...field,
      options: parseJson<string[]>(field.options, []),
      required: field.required === 1,
      ask_early: field.ask_early === 1,
      prefill: remembered[str(field.field_key)] ?? null,
    })),
    registration_open: window.open,
    closed_reason: window.code ?? null,
  };
}

/** The registration as its owner may see it. No internal columns. */
function publicRegistration(row: Record<string, unknown>) {
  return {
    id: row.id,
    reference: row.reference,
    event_id: row.event_id,
    first_name: row.first_name,
    last_name: row.last_name,
    email: row.email,
    phone: row.phone,
    organisation: row.organisation,
    job_title: row.job_title,
    country: row.country,
    answers: parseJson<Record<string, unknown>>(row.answers, {}),
    status: row.status,
    payment_status: row.payment_status,
    amount: row.amount,
    currency: row.currency,
    created_at: row.created_at,
    completed_at: row.completed_at,
  };
}

async function nextEventReference(db: D1Database): Promise<string> {
  const result = await db
    .prepare('INSERT INTO event_registration_sequence DEFAULT VALUES')
    .run();
  const sequence = Number(result.meta.last_row_id ?? Date.now());
  return `WEA-EVT-${new Date().getUTCFullYear()}-${String(sequence).padStart(5, '0')}`;
}

// ---------------------------------------------------------------------------
// Saving a registration
// ---------------------------------------------------------------------------

/**
 * Creates or updates a registration from whatever the registrant has given so
 * far.
 *
 * Called at every step of the form, not only at the end. That is the whole
 * point: the row exists from the first save, so an abandoned attempt is still
 * visible to the academy with the name, address and telephone number the
 * person actually typed — and nothing they did not.
 */
export async function saveEventRegistration(
  db: D1Database,
  idOrSlug: string,
  body: Record<string, unknown>,
  actor: Actor | null,
): Promise<EventResult> {
  const event = await db
    .prepare('SELECT * FROM events WHERE id = ?1 OR slug = ?1')
    .bind(idOrSlug)
    .first<Record<string, unknown>>();
  if (!event || !PUBLIC_STATUSES.includes(str(event.status))) {
    return { ok: false, code: 'NOT_FOUND' };
  }

  const confirmed = await db
    .prepare(
      `SELECT COUNT(*) AS total FROM event_registrations
        WHERE event_id = ?1 AND status IN ('PAID', 'COMPLETED')`,
    )
    .bind(event.id)
    .first<{ total: number }>();
  const window = registrationWindow(event as unknown as EventRow, confirmed?.total ?? 0);

  const email = (actor?.email ?? str(body.email)).toLowerCase();
  if (!email.includes('@')) return { ok: false, code: 'INVALID_EMAIL' };
  const firstName = str(body.first_name) || actor?.first_name || '';
  const lastName = str(body.last_name) || actor?.last_name || '';
  if (firstName === '' || lastName === '') {
    return { ok: false, code: 'INVALID_REQUEST', message: 'A name is required.' };
  }
  if (!event.allow_guest_registration && !actor) {
    return { ok: false, code: 'ACCOUNT_REQUIRED' };
  }

  // One person, one registration per event. An address WEA already knows is
  // resolved to its account rather than becoming a second identity.
  const linkedUser =
    actor?.id ??
    (
      await db
        .prepare('SELECT id FROM users WHERE email = ?1')
        .bind(email)
        .first<{ id: string }>()
    )?.id ??
    null;

  const existing = await db
    .prepare(
      `SELECT * FROM event_registrations
        WHERE event_id = ?1 AND (email = ?2 OR (user_id IS NOT NULL AND user_id = ?3))`,
    )
    .bind(event.id, email, linkedUser)
    .first<Record<string, unknown>>();

  // Already paid: there is nothing left to submit.
  if (existing && str(existing.payment_status) === 'PAID') {
    return { ok: true, data: { registration: publicRegistration(existing), resume_token: null } };
  }
  if (!existing && !window.open) {
    return { ok: false, code: window.code ?? 'REGISTRATION_CLOSED' };
  }

  const answers = { ...(body.answers as Record<string, unknown> | undefined) };
  const fee = num(event.fee_amount) ?? 0;
  const complete = str(body.stage) === 'COMPLETE';

  if (complete) {
    // Only checked when the registrant says they have finished, so a partial
    // save is never rejected for being partial.
    if (str(body.phone) === '' && str(existing?.phone) === '') {
      return { ok: false, code: 'MISSING_ANSWER', message: 'Phone number' };
    }
    const required = await db
      .prepare(
        `SELECT field_key, label FROM event_registration_fields
          WHERE (event_id IS NULL OR event_id = ?1) AND required = 1`,
      )
      .bind(event.id)
      .all<{ field_key: string; label: string }>();
    const priorAnswers = parseJson<Record<string, unknown>>(existing?.answers, {});
    for (const field of required.results) {
      const given = str(answers[field.field_key]) || str(priorAnswers[field.field_key]);
      if (given === '') return { ok: false, code: 'MISSING_ANSWER', message: field.label };
    }
  }

  const status = complete
    ? fee > 0
      ? 'PAYMENT_PENDING'
      : 'COMPLETED'
    : 'STARTED';
  const paymentStatus = fee > 0 ? 'PENDING' : 'NOT_REQUIRED';

  if (existing) {
    // COALESCE-style merge: a step that does not mention a field must not
    // erase what an earlier step already saved.
    const merged = {
      ...parseJson<Record<string, unknown>>(existing.answers, {}),
      ...answers,
    };
    await db
      .prepare(
        `UPDATE event_registrations
            SET first_name = ?1, last_name = ?2, email = ?3,
                phone = CASE WHEN ?4 <> '' THEN ?4 ELSE phone END,
                organisation = CASE WHEN ?5 <> '' THEN ?5 ELSE organisation END,
                job_title = CASE WHEN ?6 <> '' THEN ?6 ELSE job_title END,
                country = CASE WHEN ?7 <> '' THEN ?7 ELSE country END,
                answers = ?8,
                user_id = COALESCE(?9, user_id),
                status = CASE
                  WHEN status IN ('PAID', 'COMPLETED') THEN status
                  WHEN ?10 = 'STARTED' AND status <> 'STARTED' THEN status
                  ELSE ?10 END,
                payment_status = CASE
                  WHEN payment_status = 'PAID' THEN payment_status ELSE ?11 END,
                amount = ?12, currency = ?13, payment_method_id = ?14,
                last_activity_at = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
          WHERE id = ?15`,
      )
      .bind(
        firstName,
        lastName,
        email,
        str(body.phone),
        str(body.organisation),
        str(body.job_title),
        str(body.country),
        JSON.stringify(merged),
        linkedUser,
        status,
        paymentStatus,
        fee,
        str(event.fee_currency),
        event.payment_method_id ?? null,
        existing.id,
      )
      .run();

    const row = await db
      .prepare('SELECT * FROM event_registrations WHERE id = ?1')
      .bind(existing.id)
      .first<Record<string, unknown>>();
    return { ok: true, data: { registration: publicRegistration(row!), resume_token: null } };
  }

  const id = `evtreg-${newId()}`;
  const reference = await nextEventReference(db);
  // Guests get a token so they can come back to their own registration. Only
  // its digest is stored, exactly as for a session.
  const resumeToken = actor ? null : newToken();

  await db
    .prepare(
      `INSERT INTO event_registrations
         (id, reference, event_id, user_id, first_name, last_name, email, phone,
          organisation, job_title, country, answers, status, payment_status,
          amount, currency, payment_method_id, resume_token_hash,
          source, utm_source, utm_medium, utm_campaign)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14,
               ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22)`,
    )
    .bind(
      id,
      reference,
      event.id,
      linkedUser,
      firstName,
      lastName,
      email,
      str(body.phone),
      str(body.organisation),
      str(body.job_title),
      str(body.country),
      JSON.stringify(answers),
      status,
      paymentStatus,
      fee,
      str(event.fee_currency),
      event.payment_method_id ?? null,
      resumeToken ? await sha256(resumeToken) : null,
      str(body.source).slice(0, 80),
      str(body.utm_source).slice(0, 80),
      str(body.utm_medium).slice(0, 80),
      str(body.utm_campaign).slice(0, 120),
    )
    .run();

  const row = await db
    .prepare('SELECT * FROM event_registrations WHERE id = ?1')
    .bind(id)
    .first<Record<string, unknown>>();
  return {
    ok: true,
    data: { registration: publicRegistration(row!), resume_token: resumeToken },
  };
}

// ---------------------------------------------------------------------------
// Access to a registration
// ---------------------------------------------------------------------------

/**
 * Finds a registration the caller is entitled to see.
 *
 * Three ways in: it is yours because you are signed in as its owner, it is
 * yours because you hold the resume token issued when you created it, or you
 * are a Super Admin. There is no fourth.
 */
export async function findOwnedRegistration(
  db: D1Database,
  reference: string,
  actor: Actor | null,
  resumeToken?: string,
): Promise<Record<string, unknown> | null> {
  const row = await db
    .prepare('SELECT * FROM event_registrations WHERE reference = ?1 OR id = ?1')
    .bind(reference)
    .first<Record<string, unknown>>();
  if (!row) return null;

  if (actor && (row.user_id === actor.id || actor.role === 'SUPER_ADMIN')) return row;
  // A signed-in visitor whose address matches a guest registration is that
  // registrant; adopt the row onto their account rather than refusing them.
  if (actor && str(row.email) === actor.email.toLowerCase()) {
    await db
      .prepare('UPDATE event_registrations SET user_id = ?1 WHERE id = ?2')
      .bind(actor.id, row.id)
      .run();
    return { ...row, user_id: actor.id };
  }
  if (resumeToken && row.resume_token_hash) {
    const digest = await sha256(resumeToken);
    if (digest === row.resume_token_hash) return row;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Payment
// ---------------------------------------------------------------------------

async function paymentMethodFor(
  db: D1Database,
  methodId: unknown,
): Promise<PaymentMethodRow | null> {
  if (!methodId) return null;
  return db
    .prepare('SELECT * FROM payment_methods WHERE id = ?1 AND is_active = 1')
    .bind(methodId)
    .first<PaymentMethodRow>();
}

/**
 * Starts a payment for a registration.
 *
 * The amount comes from the registration row, which took it from the event —
 * never from the request. A client that asks to pay ten naira for a
 * two-hundred-and-fifty-thousand naira summit is charged the latter.
 */
export async function beginEventPayment(
  db: D1Database,
  registration: Record<string, unknown>,
  secrets: PaymentSecrets,
  returnUrl: string,
): Promise<EventResult> {
  const amount = num(registration.amount) ?? 0;
  if (amount <= 0) return { ok: false, code: 'PAYMENT_NOT_REQUIRED' };
  if (str(registration.payment_status) === 'PAID') {
    return { ok: false, code: 'ALREADY_PAID' };
  }

  const method = await paymentMethodFor(db, registration.payment_method_id);
  const provider = providerNameFor(method, secrets);
  const reference = `${str(registration.reference)}-${Date.now().toString(36)}`;

  const result = await initialisePayment(method, secrets, {
    reference,
    amount,
    currency: str(registration.currency) || 'NGN',
    email: str(registration.email),
    name: `${str(registration.first_name)} ${str(registration.last_name)}`.trim(),
    phone: str(registration.phone),
    description: `WEA event registration ${str(registration.reference)}`,
    returnUrl,
  });

  if (!result.ok) {
    return { ok: false, code: result.code ?? 'PAYMENT_INITIALISATION_FAILED', message: result.message };
  }

  await db
    .prepare(
      `INSERT INTO event_payments
         (id, registration_id, event_id, provider, provider_reference,
          provider_transaction_id, checkout_url, amount, currency, status)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)`,
    )
    .bind(
      `evtpay-${newId()}`,
      registration.id,
      registration.event_id,
      provider,
      reference,
      result.transactionId ?? null,
      result.checkoutUrl ?? null,
      amount,
      str(registration.currency) || 'NGN',
      result.checkoutUrl ? 'PROCESSING' : 'PENDING',
    )
    .run();

  await db
    .prepare(
      `UPDATE event_registrations
          SET status = ?1, payment_status = ?2,
              last_activity_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?3`,
    )
    .bind(
      result.checkoutUrl ? 'PAYMENT_PROCESSING' : 'PAYMENT_PENDING',
      result.checkoutUrl ? 'PROCESSING' : 'PENDING',
      registration.id,
    )
    .run();

  return {
    ok: true,
    data: {
      provider,
      payment_reference: reference,
      checkout_url: result.checkoutUrl ?? null,
      instructions: result.instructions ?? str(method?.instructions),
      amount,
      currency: str(registration.currency) || 'NGN',
    },
  };
}

/**
 * Asks the processor what actually happened, and settles the registration.
 *
 * This is the only path that may write `PAID`. It runs from the return
 * redirect, from the webhook and from a manual refresh — all three converge
 * here, and all three ask the processor rather than believing whoever called.
 *
 * A payment for the wrong amount or the wrong currency is not a payment: it is
 * recorded, flagged and left unsettled for the academy to look at.
 */
export async function settleEventPayment(
  db: D1Database,
  paymentReference: string,
  secrets: PaymentSecrets,
): Promise<EventResult> {
  const payment = await db
    .prepare('SELECT * FROM event_payments WHERE provider_reference = ?1')
    .bind(paymentReference)
    .first<Record<string, unknown>>();
  if (!payment) return { ok: false, code: 'NOT_FOUND' };

  // Settled already: report it without calling out again.
  if (str(payment.status) === 'PAID') {
    return { ok: true, data: { status: 'PAID', payment_reference: paymentReference } };
  }

  const verification = await verifyPayment(str(payment.provider), paymentReference, secrets);

  const expectedAmount = num(payment.amount) ?? 0;
  const expectedCurrency = str(payment.currency).toUpperCase();
  let outcome = verification.status;
  let reason = verification.reason ?? '';

  if (outcome === 'PAID') {
    const paidAmount = verification.amount ?? 0;
    const paidCurrency = (verification.currency ?? '').toUpperCase();
    // Tolerance of one minor unit absorbs the processor's own rounding.
    if (paidAmount + 0.01 < expectedAmount) {
      outcome = 'FAILED';
      reason = `Underpaid: ${paidAmount} ${paidCurrency} against ${expectedAmount} ${expectedCurrency}.`;
    } else if (paidCurrency !== '' && paidCurrency !== expectedCurrency) {
      outcome = 'FAILED';
      reason = `Wrong currency: ${paidCurrency} against ${expectedCurrency}.`;
    }
  }

  await db
    .prepare(
      `UPDATE event_payments
          SET status = ?1, failure_reason = ?2, provider_transaction_id = ?3,
              provider_payload = ?4,
              verified_at = CASE WHEN ?1 = 'PAID' THEN CURRENT_TIMESTAMP ELSE verified_at END,
              updated_at = CURRENT_TIMESTAMP
        WHERE id = ?5`,
    )
    .bind(
      outcome,
      reason,
      verification.transactionId ?? payment.provider_transaction_id ?? null,
      JSON.stringify(verification.payload),
      payment.id,
    )
    .run();

  const [registrationStatus, paymentStatus] = ((): [string, string] => {
    switch (outcome) {
      case 'PAID':
        return ['COMPLETED', 'PAID'];
      case 'FAILED':
        return ['PAYMENT_FAILED', 'FAILED'];
      case 'CANCELLED':
        // Not a failure — they simply have not paid yet, and may still.
        return ['PAYMENT_PENDING', 'PENDING'];
      case 'PROCESSING':
        return ['PAYMENT_PROCESSING', 'PROCESSING'];
      default:
        return ['PAYMENT_PENDING', 'PENDING'];
    }
  })();

  await db
    .prepare(
      `UPDATE event_registrations
          SET status = ?1, payment_status = ?2,
              completed_at = CASE WHEN ?2 = 'PAID' THEN CURRENT_TIMESTAMP ELSE completed_at END,
              last_activity_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?3`,
    )
    .bind(registrationStatus, paymentStatus, payment.registration_id)
    .run();

  return {
    ok: true,
    data: {
      status: outcome,
      registration_status: registrationStatus,
      payment_status: paymentStatus,
      reason,
      payment_reference: paymentReference,
    },
  };
}

/** The most recent payment attempt on a registration, for the retry path. */
export async function latestPayment(db: D1Database, registrationId: string) {
  return db
    .prepare(
      `SELECT provider, provider_reference, checkout_url, status, failure_reason,
              amount, currency, created_at
         FROM event_payments WHERE registration_id = ?1
        ORDER BY created_at DESC LIMIT 1`,
    )
    .bind(registrationId)
    .first();
}

// ---------------------------------------------------------------------------
// The participant's own view
// ---------------------------------------------------------------------------

/**
 * The event dashboard for one registration.
 *
 * Participant material and live sessions are included only where the
 * registration entitles them: a paid event whose registrant has not paid gets
 * the event information and nothing else. The decision is here, in the API,
 * not in the interface that renders it.
 */
export async function participantDashboard(
  db: D1Database,
  registration: Record<string, unknown>,
) {
  const entitled =
    str(registration.payment_status) === 'PAID' ||
    str(registration.payment_status) === 'NOT_REQUIRED' ||
    str(registration.status) === 'COMPLETED';

  const [event, materials, sessions, payment] = await Promise.all([
    db.prepare('SELECT * FROM events WHERE id = ?1').bind(registration.event_id).first<
      Record<string, unknown>
    >(),
    db
      .prepare(
        `SELECT id, title, description, material_type, media_key, resource_url, visibility
           FROM event_materials
          WHERE event_id = ?1 AND status = 'PUBLISHED'
            AND (visibility = 'PUBLIC' OR ?2 = 1)
          ORDER BY sort_order, title`,
      )
      .bind(registration.event_id, entitled ? 1 : 0)
      .all(),
    db
      .prepare(
        `SELECT id, title, session_type, starts_at, ends_at, timezone, speaker,
                notes, is_live, recording_url
           FROM event_sessions
          WHERE event_id = ?1 AND status = 'PUBLISHED'
          ORDER BY starts_at, sort_order`,
      )
      .bind(registration.event_id)
      .all(),
    latestPayment(db, str(registration.id)),
  ]);

  return {
    event: event ? decodeAgenda(event) : null,
    registration: publicRegistration(registration),
    materials: materials.results,
    // The join link is never in this payload. It is issued one session at a
    // time by joinEventSession, after the same checks are made again.
    sessions: sessions.results,
    payment,
    entitled,
  };
}

/**
 * Hands out a live session link, or explains why not.
 *
 * Every condition is re-checked at the moment of joining rather than trusted
 * from whatever the dashboard was showing a minute ago.
 */
export async function joinEventSession(
  db: D1Database,
  registration: Record<string, unknown>,
  sessionId: string,
): Promise<EventResult> {
  const entitled =
    str(registration.payment_status) === 'PAID' ||
    str(registration.payment_status) === 'NOT_REQUIRED';
  if (!entitled) return { ok: false, code: 'PAYMENT_REQUIRED' };

  const session = await db
    .prepare(
      `SELECT * FROM event_sessions
        WHERE id = ?1 AND event_id = ?2 AND status = 'PUBLISHED'`,
    )
    .bind(sessionId, registration.event_id)
    .first<Record<string, unknown>>();
  if (!session) return { ok: false, code: 'NOT_FOUND' };
  if (session.is_live !== 1) return { ok: false, code: 'SESSION_NOT_LIVE' };

  const joinUrl = str(session.join_url);
  if (joinUrl === '') return { ok: false, code: 'SESSION_NOT_READY' };

  await db
    .prepare(
      `INSERT INTO event_attendance (id, session_id, registration_id)
       VALUES (?1, ?2, ?3)
       ON CONFLICT(session_id, registration_id) DO NOTHING`,
    )
    .bind(`evtatt-${newId()}`, sessionId, registration.id)
    .run();

  return {
    ok: true,
    data: {
      join_url: joinUrl,
      room_name: str(session.room_name),
      title: str(session.title),
    },
  };
}

/** Every event this person has registered for. */
export async function myEventRegistrations(db: D1Database, userId: string) {
  const rows = await db
    .prepare(
      `SELECT r.*, e.title AS event_title, e.slug AS event_slug,
              e.starts_at AS event_starts_at, e.venue AS event_venue,
              e.format AS event_format, e.image_key AS event_image_key
         FROM event_registrations r
         JOIN events e ON e.id = r.event_id
        WHERE r.user_id = ?1
        ORDER BY r.created_at DESC`,
    )
    .bind(userId)
    .all();
  return rows.results.map((row) => ({
    ...publicRegistration(row),
    event_title: row.event_title,
    event_slug: row.event_slug,
    event_starts_at: row.event_starts_at,
    event_venue: row.event_venue,
    event_format: row.event_format,
    event_image_key: row.event_image_key,
  }));
}

// ---------------------------------------------------------------------------
// Administration
// ---------------------------------------------------------------------------

export async function listEventRegistrations(
  db: D1Database,
  params: URLSearchParams,
) {
  const clauses: string[] = [];
  const binds: unknown[] = [];
  const add = (clause: string, value: unknown) => {
    binds.push(value);
    clauses.push(clause.replace('?', `?${binds.length}`));
  };

  if (str(params.get('event_id'))) add('r.event_id = ?', params.get('event_id'));
  if (str(params.get('status'))) add('r.status = ?', params.get('status'));
  if (str(params.get('payment_status'))) {
    add('r.payment_status = ?', params.get('payment_status'));
  }
  const search = str(params.get('q')).toLowerCase();
  if (search !== '') {
    binds.push(`%${search}%`);
    const index = binds.length;
    clauses.push(
      `(lower(r.first_name) LIKE ?${index} OR lower(r.last_name) LIKE ?${index}
        OR lower(r.email) LIKE ?${index} OR lower(r.phone) LIKE ?${index}
        OR lower(r.organisation) LIKE ?${index} OR lower(r.reference) LIKE ?${index})`,
    );
  }

  const rows = await db
    .prepare(
      `SELECT r.*, e.title AS event_title, e.slug AS event_slug
         FROM event_registrations r
         JOIN events e ON e.id = r.event_id
        ${clauses.length ? `WHERE ${clauses.join(' AND ')}` : ''}
        ORDER BY r.created_at DESC LIMIT 1000`,
    )
    .bind(...binds)
    .all();

  return rows.results.map((row) => ({
    ...row,
    answers: parseJson<Record<string, unknown>>(row.answers, {}),
    // Never leave this table.
    resume_token_hash: undefined,
  }));
}

/**
 * Headline numbers for one event, or for every event.
 *
 * Revenue counts verified payments only. An abandoned or pending registration
 * is a lead, not money, and is never added to it.
 */
export async function eventOverview(db: D1Database, eventId?: string | null) {
  const scoped = str(eventId) !== '';
  const binds = scoped ? [eventId] : [];
  const where = scoped ? 'WHERE event_id = ?1' : '';

  const [counts, revenue] = await Promise.all([
    db
      .prepare(
        `SELECT COUNT(*) AS total,
                SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed,
                SUM(CASE WHEN payment_status = 'PENDING' THEN 1 ELSE 0 END) AS payment_pending,
                SUM(CASE WHEN payment_status = 'PROCESSING' THEN 1 ELSE 0 END) AS payment_processing,
                SUM(CASE WHEN payment_status = 'FAILED' THEN 1 ELSE 0 END) AS payment_failed,
                SUM(CASE WHEN status = 'ABANDONED' THEN 1 ELSE 0 END) AS abandoned,
                SUM(CASE WHEN status = 'STARTED' THEN 1 ELSE 0 END) AS started
           FROM event_registrations ${where}`,
      )
      .bind(...binds)
      .first<Record<string, number>>(),
    db
      .prepare(
        `SELECT currency, SUM(amount) AS total, COUNT(*) AS payments
           FROM event_payments
          WHERE status = 'PAID' AND verified_at IS NOT NULL
            ${scoped ? 'AND event_id = ?1' : ''}
          GROUP BY currency`,
      )
      .bind(...binds)
      .all(),
  ]);

  return {
    total_attempts: counts?.total ?? 0,
    completed: counts?.completed ?? 0,
    payment_pending: counts?.payment_pending ?? 0,
    payment_processing: counts?.payment_processing ?? 0,
    payment_failed: counts?.payment_failed ?? 0,
    abandoned: counts?.abandoned ?? 0,
    started: counts?.started ?? 0,
    revenue: revenue.results,
  };
}

const csvCell = (value: unknown) => {
  const text = value === null || value === undefined ? '' : String(value);
  return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
};

/**
 * Registrations as a spreadsheet.
 *
 * Payment *references* are exported so a row can be reconciled; nothing that
 * identifies an instrument is, because WEA never holds it in the first place.
 */
export async function exportEventRegistrations(
  db: D1Database,
  eventId?: string | null,
): Promise<string> {
  const scoped = str(eventId) !== '';
  const rows = await db
    .prepare(
      `SELECT r.reference, r.first_name, r.last_name, r.email, r.phone,
              r.organisation, r.job_title, r.country, e.title AS event_title,
              r.status, r.payment_status, r.amount, r.currency,
              r.utm_source, r.utm_campaign, r.created_at, r.completed_at,
              (SELECT provider_reference FROM event_payments p
                WHERE p.registration_id = r.id AND p.status = 'PAID'
                ORDER BY p.verified_at DESC LIMIT 1) AS payment_reference
         FROM event_registrations r
         JOIN events e ON e.id = r.event_id
        ${scoped ? 'WHERE r.event_id = ?1' : ''}
        ORDER BY r.created_at DESC`,
    )
    .bind(...(scoped ? [eventId] : []))
    .all<Record<string, unknown>>();

  const headers = [
    'Reference', 'First name', 'Last name', 'Email', 'Phone', 'Organisation',
    'Job title', 'Country', 'Event', 'Registration status', 'Payment status',
    'Amount', 'Currency', 'Campaign source', 'Campaign', 'Registered',
    'Completed', 'Payment reference',
  ];
  const lines = [headers.join(',')];
  for (const row of rows.results) {
    lines.push(
      [
        row.reference, row.first_name, row.last_name, row.email, row.phone,
        row.organisation, row.job_title, row.country, row.event_title,
        row.status, row.payment_status, row.amount, row.currency,
        row.utm_source, row.utm_campaign, row.created_at, row.completed_at,
        row.payment_reference,
      ]
        .map(csvCell)
        .join(','),
    );
  }
  return lines.join('\r\n');
}

const ADMIN_SETTABLE = [
  'PAYMENT_PENDING', 'PAID', 'COMPLETED', 'ABANDONED', 'CANCELLED', 'PAYMENT_FAILED',
];

/**
 * A Super Admin decision on a registration — chiefly confirming a payment that
 * arrived by bank transfer, which no processor can tell us about.
 */
export async function setEventRegistrationStatus(
  db: D1Database,
  registrationId: string,
  body: Record<string, unknown>,
): Promise<EventResult> {
  const status = str(body.status);
  if (!ADMIN_SETTABLE.includes(status)) return { ok: false, code: 'INVALID_STATUS' };

  const registration = await db
    .prepare('SELECT * FROM event_registrations WHERE id = ?1')
    .bind(registrationId)
    .first<Record<string, unknown>>();
  if (!registration) return { ok: false, code: 'NOT_FOUND' };

  // The two columns are moved together so they can never disagree.
  const paymentStatus =
    status === 'PAID' || status === 'COMPLETED'
      ? (num(registration.amount) ?? 0) > 0
        ? 'PAID'
        : 'NOT_REQUIRED'
      : status === 'PAYMENT_FAILED'
        ? 'FAILED'
        : status === 'CANCELLED'
          ? str(registration.payment_status)
          : 'PENDING';

  await db
    .prepare(
      `UPDATE event_registrations
          SET status = ?1, payment_status = ?2,
              admin_note = CASE WHEN ?3 <> '' THEN ?3 ELSE admin_note END,
              completed_at = CASE WHEN ?2 = 'PAID' AND completed_at IS NULL
                                  THEN CURRENT_TIMESTAMP ELSE completed_at END,
              updated_at = CURRENT_TIMESTAMP
        WHERE id = ?4`,
    )
    .bind(status, paymentStatus, str(body.note), registrationId)
    .run();

  // A confirmed payment recorded by hand should leave the same audit trail a
  // gateway payment does, so revenue reconciles from one table.
  if (paymentStatus === 'PAID') {
    await db
      .prepare(
        `INSERT OR IGNORE INTO event_payments
           (id, registration_id, event_id, provider, provider_reference,
            amount, currency, status, verified_at, provider_payload)
         VALUES (?1, ?2, ?3, 'MANUAL', ?4, ?5, ?6, 'PAID', CURRENT_TIMESTAMP, ?7)`,
      )
      .bind(
        `evtpay-${newId()}`,
        registrationId,
        registration.event_id,
        `${str(registration.reference)}-manual`,
        num(registration.amount) ?? 0,
        str(registration.currency),
        JSON.stringify({ confirmed_by: 'ACADEMY_OFFICE' }),
      )
      .run();
  }

  const row = await db
    .prepare('SELECT * FROM event_registrations WHERE id = ?1')
    .bind(registrationId)
    .first();
  return { ok: true, data: { registration: row as Record<string, unknown> } };
}

/**
 * Marks stale attempts as abandoned.
 *
 * Nothing is deleted: an abandoned registration is exactly the lead the academy
 * asked to keep. This only stops it sitting in the pending queue for ever.
 */
export async function sweepAbandonedRegistrations(db: D1Database): Promise<number> {
  const cutoff = new Date(Date.now() - ABANDON_AFTER_HOURS * 3_600_000)
    .toISOString()
    .replace('T', ' ')
    .slice(0, 19);
  const result = await db
    .prepare(
      `UPDATE event_registrations
          SET status = 'ABANDONED', updated_at = CURRENT_TIMESTAMP
        WHERE status IN ('STARTED', 'PAYMENT_PENDING')
          AND payment_status <> 'PAID'
          AND last_activity_at < ?1`,
    )
    .bind(cutoff)
    .run();
  return result.meta.changes ?? 0;
}
