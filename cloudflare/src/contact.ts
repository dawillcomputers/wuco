import { newId } from './auth';
import { str } from './http';

/**
 * Enquiries from the public site, and the academy's replies.
 *
 * Anyone may send one. A signed-in sender has the enquiry linked to their
 * account so replies can be shown to them in the application; an anonymous
 * sender is answered by email against the reference.
 */

const MAX_MESSAGE = 5000;
const MAX_FIELD = 200;

export interface ContactAuthor {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  role: string;
}

export interface ContactResult {
  ok: boolean;
  code?: string;
  message?: string;
  data?: unknown;
}

async function nextReference(db: D1Database) {
  const result = await db
    .prepare('INSERT INTO contact_sequence DEFAULT VALUES')
    .run();
  const sequence = Number(result.meta.last_row_id ?? Date.now());
  return `WEA-ENQ-${String(sequence).padStart(5, '0')}`;
}

/** Accepts an enquiry. Validation is server-side; the form is a convenience. */
export async function submitEnquiry(
  db: D1Database,
  body: Record<string, unknown>,
  actor: ContactAuthor | null,
): Promise<ContactResult> {
  // A signed-in sender's own identity is trusted over anything posted, so an
  // enquiry cannot be attributed to somebody else.
  const name = actor
    ? `${actor.first_name} ${actor.last_name}`.trim() || str(body.name)
    : str(body.name);
  const email = actor ? actor.email : str(body.email).toLowerCase();
  const message = str(body.message);

  if (name.length === 0 || name.length > MAX_FIELD) {
    return { ok: false, code: 'INVALID_REQUEST', message: 'Please give your name.' };
  }
  if (!email.includes('@') || email.length > MAX_FIELD) {
    return {
      ok: false,
      code: 'INVALID_EMAIL',
      message: 'Please give a valid email address.',
    };
  }
  if (message.length < 10) {
    return {
      ok: false,
      code: 'INVALID_REQUEST',
      message: 'Please include a little more detail in your message.',
    };
  }
  if (message.length > MAX_MESSAGE) {
    return {
      ok: false,
      code: 'INVALID_REQUEST',
      message: 'Please keep your message under 5000 characters.',
    };
  }

  const reference = await nextReference(db);
  const id = `enq-${newId()}`;

  await db
    .prepare(
      `INSERT INTO contact_messages
         (id, reference, name, email, phone, organisation, subject, message, user_id, source)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)`,
    )
    .bind(
      id,
      reference,
      name,
      email,
      str(body.phone).slice(0, MAX_FIELD),
      str(body.organisation).slice(0, MAX_FIELD),
      str(body.subject).slice(0, MAX_FIELD),
      message,
      actor?.id ?? null,
      str(body.source) || 'CONTACT_PAGE',
    )
    .run();

  return { ok: true, data: { id, reference } };
}

interface MessageRow {
  id: string;
  [key: string]: unknown;
}

/** Attaches the reply thread to each message in one extra query. */
async function withReplies(db: D1Database, messages: MessageRow[]) {
  if (messages.length === 0) return [];
  const placeholders = messages.map((_, index) => `?${index + 1}`).join(', ');
  const replies = await db
    .prepare(
      `SELECT r.*, u.first_name, u.last_name
         FROM contact_replies r
         LEFT JOIN users u ON u.id = r.author_id
        WHERE r.message_id IN (${placeholders})
        ORDER BY r.created_at`,
    )
    .bind(...messages.map((row) => row.id))
    .all();

  return messages.map((message) => ({
    ...message,
    replies: replies.results
      .filter((reply) => reply.message_id === message.id)
      .map((reply) => ({
        ...reply,
        from_academy: reply.from_academy === 1,
        author_name: `${reply.first_name ?? ''} ${reply.last_name ?? ''}`.trim(),
      })),
  }));
}

/** The signed-in sender's own enquiries. Never anyone else's. */
export async function listMyEnquiries(db: D1Database, userId: string) {
  const rows = await db
    .prepare(
      `SELECT id, reference, subject, message, status, created_at
         FROM contact_messages WHERE user_id = ?1
        ORDER BY created_at DESC LIMIT 50`,
    )
    .bind(userId)
    .all<MessageRow>();
  return withReplies(db, rows.results);
}

/** Every enquiry, for the academy office. */
export async function listEnquiries(db: D1Database, status: string | null) {
  const rows = await db
    .prepare(
      `SELECT * FROM contact_messages
        ${status ? 'WHERE status = ?1' : ''}
        ORDER BY created_at DESC LIMIT 300`,
    )
    .bind(...(status ? [status] : []))
    .all<MessageRow>();
  return withReplies(db, rows.results);
}

const STATUSES = ['NEW', 'READ', 'REPLIED', 'CLOSED'];

export async function setEnquiryStatus(
  db: D1Database,
  actorId: string,
  id: string,
  status: string,
): Promise<ContactResult> {
  if (!STATUSES.includes(status)) return { ok: false, code: 'INVALID_STATUS' };
  const existing = await db
    .prepare('SELECT id FROM contact_messages WHERE id = ?1')
    .bind(id)
    .first();
  if (!existing) return { ok: false, code: 'NOT_FOUND' };

  await db
    .prepare(
      `UPDATE contact_messages
          SET status = ?1, handled_by = ?2, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?3`,
    )
    .bind(status, actorId, id)
    .run();
  return { ok: true };
}

/**
 * Adds a reply.
 *
 * Staff may reply to any enquiry. A sender may follow up only on their own —
 * the ownership check is here, not in the interface.
 */
export async function replyToEnquiry(
  db: D1Database,
  actor: ContactAuthor,
  id: string,
  body: Record<string, unknown>,
): Promise<ContactResult> {
  const text = str(body.body);
  if (text.length === 0 || text.length > MAX_MESSAGE) {
    return { ok: false, code: 'INVALID_REQUEST', message: 'Please write a reply.' };
  }

  const message = await db
    .prepare('SELECT id, user_id FROM contact_messages WHERE id = ?1')
    .bind(id)
    .first<{ id: string; user_id: string | null }>();
  if (!message) return { ok: false, code: 'NOT_FOUND' };

  const isStaff = actor.role === 'SUPER_ADMIN' || actor.role === 'ADMIN';
  if (!isStaff && message.user_id !== actor.id) {
    return { ok: false, code: 'NOT_AUTHORISED' };
  }

  await db
    .prepare(
      `INSERT INTO contact_replies (id, message_id, body, author_id, from_academy)
       VALUES (?1, ?2, ?3, ?4, ?5)`,
    )
    .bind(`rep-${newId()}`, id, text, actor.id, isStaff ? 1 : 0)
    .run();

  await db
    .prepare(
      `UPDATE contact_messages
          SET status = ?1,
              handled_by = COALESCE(handled_by, ?2),
              updated_at = CURRENT_TIMESTAMP
        WHERE id = ?3`,
    )
    // A sender's follow-up reopens the enquiry rather than marking it answered.
    .bind(isStaff ? 'REPLIED' : 'NEW', isStaff ? actor.id : null, id)
    .run();

  return { ok: true };
}
