import {
  ALL_ROLES,
  PBKDF2_ITERATIONS,
  RESET_TTL_MINUTES,
  Role,
  SELF_ASSIGNABLE,
  SESSION_TTL_DAYS,
  Status,
  VERIFICATION_TTL_HOURS,
  hashPassword,
  isExpired,
  isPasswordAcceptable,
  isoIn,
  newId,
  newToken,
  randomHex,
  sha256,
  temporaryPassword,
  verifyPassword,
} from './auth';
import {
  getArea,
  getProgramme,
  listAreas,
  listFaculty,
  listPaymentMethods,
  listProgrammes,
  listSettings,
  listTypes,
} from './catalogue';
import {
  listEnquiries,
  listMyEnquiries,
  replyToEnquiry,
  setEnquiryStatus,
  submitEnquiry,
} from './contact';
import {
  eventFunnel,
  followShareLink,
  pruneAnalytics,
  recordFunnelEvent,
  recordPageView,
  shareLinkPerformance,
  siteAnalytics,
} from './analytics';
import {
  beginEventPayment,
  eventOverview,
  eventRegistrationContext,
  exportEventRegistrations,
  findOwnedRegistration,
  getEvent,
  joinEventSession,
  latestPayment,
  listEventRegistrations,
  listEvents,
  myEventRegistrations,
  participantDashboard,
  saveEventRegistration,
  setEventRegistrationStatus,
  settleEventPayment,
  sweepAbandonedRegistrations,
} from './events';
import { corsHeaders, fail, json, num, readJson, str } from './http';
import { deleteMedia, listMedia, serveMedia, uploadMedia } from './media';
import { readWebhook } from './payments';
import { shareCard } from './share';
import { availableProviders, signInWithProvider } from './social';
import {
  createResource,
  deleteResource,
  listResource,
  reorderResource,
  resourceByName,
  updateResource,
} from './resources';
import {
  listRegistrations,
  registrationContext,
  reviewRegistration,
  submitRegistration,
} from './registrations';

export interface Env {
  WEA_DB: D1Database;
  /** Uploaded programme and faculty imagery. */
  WEA_MEDIA: R2Bucket;
  ALLOWED_ORIGIN: string;
  /** Secret guarding the one-time Super Admin bootstrap. */
  BOOTSTRAP_TOKEN?: string;
  /** Address seeded as the first Super Admin. */
  SUPERADMIN_EMAIL?: string;
  /**
   * Development escape hatch: returns verification and reset tokens in the API
   * response so the flows can be completed before an email provider exists.
   *
   * MUST stay unset in production. With it on, anyone could request a reset
   * token for any address and read it straight back.
   */
  EXPOSE_AUTH_TOKENS?: string;

  /** Public site origin, used to build share links and payment return URLs. */
  PUBLIC_SITE_URL?: string;

  // Payment processor credentials. Secrets, set with `wrangler secret put`.
  // A processor with no key here is never offered to a payer, so an
  // unconfigured deployment falls back to the academy's own instructions
  // rather than sending anybody to a checkout that cannot work.
  PAYSTACK_SECRET_KEY?: string;
  FLUTTERWAVE_SECRET_KEY?: string;
  FLUTTERWAVE_WEBHOOK_HASH?: string;

  // OAuth client ids for social sign-in. Not secrets — they are public by
  // design — but a provider without one is not offered.
  GOOGLE_CLIENT_ID?: string;
  APPLE_CLIENT_ID?: string;

  /**
   * Salt for the rotating visitor digest used by analytics. Set it per
   * deployment; the digest is the only thing standing between "count visits"
   * and "identify people", so it must not be predictable.
   */
  ANALYTICS_SALT?: string;
}

interface UserRow {
  id: string;
  email: string;
  password_hash: string;
  password_salt: string;
  password_iterations: number;
  first_name: string;
  last_name: string;
  phone: string | null;
  country: string | null;
  avatar_url: string | null;
  role: Role;
  status: Status;
  email_verified: number;
  must_change_password: number;
  created_at: string;
  updated_at: string;
}

/** Strips credentials and internal columns before anything is returned. */
function toProfile(row: UserRow) {
  return {
    id: row.id,
    email: row.email,
    first_name: row.first_name,
    last_name: row.last_name,
    phone: row.phone,
    country: row.country,
    avatar_url: row.avatar_url,
    role: row.role,
    status: row.status,
    email_verified: row.email_verified === 1,
    must_change_password: row.must_change_password === 1,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

async function findUserByEmail(env: Env, email: string) {
  return env.WEA_DB.prepare('SELECT * FROM users WHERE email = ?1')
    .bind(email.trim().toLowerCase())
    .first<UserRow>();
}

async function findUserById(env: Env, id: string) {
  return env.WEA_DB.prepare('SELECT * FROM users WHERE id = ?1')
    .bind(id)
    .first<UserRow>();
}

/** Resolves the bearer token to a live session, or null. */
async function authenticate(request: Request, env: Env): Promise<UserRow | null> {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const tokenHash = await sha256(header.slice(7));
  const session = await env.WEA_DB.prepare(
    'SELECT user_id, expires_at FROM sessions WHERE token_hash = ?1',
  )
    .bind(tokenHash)
    .first<{ user_id: string; expires_at: string }>();
  if (!session) return null;
  if (isExpired(session.expires_at)) {
    await env.WEA_DB.prepare('DELETE FROM sessions WHERE token_hash = ?1')
      .bind(tokenHash)
      .run();
    return null;
  }
  return findUserById(env, session.user_id);
}

async function createSession(env: Env, userId: string) {
  const token = newToken();
  await env.WEA_DB.prepare(
    'INSERT INTO sessions (id, user_id, token_hash, expires_at) VALUES (?1, ?2, ?3, ?4)',
  )
    .bind(
      newId(),
      userId,
      await sha256(token),
      isoIn(SESSION_TTL_DAYS * 86_400_000),
    )
    .run();
  return { token, expires_at: isoIn(SESSION_TTL_DAYS * 86_400_000) };
}

async function issueToken(
  env: Env,
  userId: string,
  purpose: 'EMAIL_VERIFICATION' | 'PASSWORD_RESET',
  ttlMs: number,
) {
  const token = newToken();
  await env.WEA_DB.prepare(
    'INSERT INTO auth_tokens (id, user_id, token_hash, purpose, expires_at) VALUES (?1, ?2, ?3, ?4, ?5)',
  )
    .bind(newId(), userId, await sha256(token), purpose, isoIn(ttlMs))
    .run();
  return token;
}

/// Explicit union so `'error' in result` narrows to a definite `userId`.
/// Neither member may declare the other's key, or `in` stops discriminating.
type ConsumedToken =
  | { error: 'INVALID_LINK' | 'EXPIRED_LINK' }
  | { userId: string };

async function consumeToken(
  env: Env,
  token: string,
  purpose: 'EMAIL_VERIFICATION' | 'PASSWORD_RESET',
): Promise<ConsumedToken> {
  const tokenHash = await sha256(token);
  const row = await env.WEA_DB.prepare(
    'SELECT id, user_id, expires_at, used_at FROM auth_tokens WHERE token_hash = ?1 AND purpose = ?2',
  )
    .bind(tokenHash, purpose)
    .first<{ id: string; user_id: string; expires_at: string; used_at: string | null }>();
  if (!row || row.used_at) return { error: 'INVALID_LINK' as const };
  if (isExpired(row.expires_at)) return { error: 'EXPIRED_LINK' as const };
  await env.WEA_DB.prepare('UPDATE auth_tokens SET used_at = CURRENT_TIMESTAMP WHERE id = ?1')
    .bind(row.id)
    .run();
  return { userId: row.user_id };
}

async function audit(
  env: Env,
  actorId: string | null,
  action: string,
  subjectId?: string,
  detail?: string,
) {
  await env.WEA_DB.prepare(
    'INSERT INTO admin_audit (id, actor_id, action, subject_id, detail) VALUES (?1, ?2, ?3, ?4, ?5)',
  )
    .bind(newId(), actorId, action, subjectId ?? null, detail ?? null)
    .run();
}

async function setPassword(env: Env, userId: string, password: string) {
  const salt = randomHex(16);
  const hash = await hashPassword(password, salt);
  await env.WEA_DB.prepare(
    `UPDATE users
       SET password_hash = ?1, password_salt = ?2, password_iterations = ?3,
           must_change_password = 0, updated_at = CURRENT_TIMESTAMP
     WHERE id = ?4`,
  )
    .bind(hash, salt, PBKDF2_ITERATIONS, userId)
    .run();
}

/** Only echo link tokens when the development flag is explicitly enabled. */
const devToken = (env: Env, token?: string) =>
  env.EXPOSE_AUTH_TOKENS === 'true' ? (token ?? null) : null;

/** Processor credentials, gathered in one place so nothing else reads them. */
const paymentSecrets = (env: Env) => ({
  PAYSTACK_SECRET_KEY: env.PAYSTACK_SECRET_KEY,
  FLUTTERWAVE_SECRET_KEY: env.FLUTTERWAVE_SECRET_KEY,
  FLUTTERWAVE_WEBHOOK_HASH: env.FLUTTERWAVE_WEBHOOK_HASH,
});

/**
 * Where the public site lives.
 *
 * Editable in the CMS so the academy can move the site without a deploy,
 * falling back to configuration and then to the allowed origin.
 */
async function publicSiteUrl(env: Env): Promise<string> {
  const row = await env.WEA_DB.prepare(
    "SELECT value FROM site_settings WHERE key = 'public_site_url'",
  ).first<{ value: string }>();
  return str(row?.value) || str(env.PUBLIC_SITE_URL) || env.ALLOWED_ORIGIN;
}

/**
 * A guest proves a registration is theirs with the token issued when they
 * created it. Sent as a header so it never lands in a server log or a browser
 * history the way a query parameter would.
 */
const resumeTokenOf = (request: Request) =>
  request.headers.get('X-Registration-Token') ?? undefined;

export default {
  async fetch(request, env): Promise<Response> {
    const origin = request.headers.get('Origin');
    const allowed = origin === env.ALLOWED_ORIGIN ? origin : undefined;
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    if (method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders(allowed) });
    }

    try {
      // --- Public ----------------------------------------------------------

      if (method === 'GET' && path === '/api/health') {
        const result = await env.WEA_DB.prepare(
          'SELECT value FROM app_metadata WHERE key = ?1',
        )
          .bind('service_status')
          .first<{ value: string }>();
        return json({ service: 'wuco-api', status: result?.value ?? 'ready' }, 200, allowed);
      }

      // --- Public catalogue -------------------------------------------------
      // Everything here reads PUBLISHED rows only. Draft and archived content
      // is never selected, so it cannot be reached by guessing a URL.

      if (method === 'GET' && path === '/api/catalogue') {
        const [areas, types, settings] = await Promise.all([
          listAreas(env.WEA_DB),
          listTypes(env.WEA_DB),
          listSettings(env.WEA_DB),
        ]);
        return json({ areas, types, settings }, 200, allowed);
      }

      if (method === 'GET' && path === '/api/catalogue/areas') {
        return json({ areas: await listAreas(env.WEA_DB) }, 200, allowed);
      }

      const areaMatch = path.match(/^\/api\/catalogue\/areas\/([^/]+)$/);
      if (method === 'GET' && areaMatch) {
        const result = await getArea(env.WEA_DB, decodeURIComponent(areaMatch[1]));
        if (!result) return fail('NOT_FOUND', 404, allowed);
        return json(result, 200, allowed);
      }

      if (method === 'GET' && path === '/api/catalogue/types') {
        return json({ types: await listTypes(env.WEA_DB) }, 200, allowed);
      }

      if (method === 'GET' && path === '/api/catalogue/programmes') {
        return json(
          { programmes: await listProgrammes(env.WEA_DB, url.searchParams) },
          200,
          allowed,
        );
      }

      const programmeMatch = path.match(/^\/api\/catalogue\/programmes\/([^/]+)$/);
      if (method === 'GET' && programmeMatch) {
        const result = await getProgramme(
          env.WEA_DB,
          decodeURIComponent(programmeMatch[1]),
        );
        if (!result) return fail('NOT_FOUND', 404, allowed);
        return json(result, 200, allowed);
      }

      if (method === 'GET' && path === '/api/catalogue/faculty') {
        return json({ faculty: await listFaculty(env.WEA_DB) }, 200, allowed);
      }

      if (method === 'GET' && path === '/api/payment-methods') {
        return json(
          { payment_methods: await listPaymentMethods(env.WEA_DB) },
          200,
          allowed,
        );
      }

      // Images are public assets; they are served with their own permissive
      // CORS header rather than the API's origin allow-list.
      if (method === 'GET' && path.startsWith('/api/media/')) {
        return serveMedia(env, decodeURIComponent(path.slice('/api/media/'.length)), request);
      }

      // --- Public events ----------------------------------------------------

      if (method === 'GET' && path === '/api/events') {
        return json(
          { events: await listEvents(env.WEA_DB, url.searchParams) },
          200,
          allowed,
        );
      }

      const eventMatch = path.match(/^\/api\/events\/([^/]+)$/);
      if (method === 'GET' && eventMatch) {
        const result = await getEvent(env.WEA_DB, decodeURIComponent(eventMatch[1]));
        if (!result) return fail('NOT_FOUND', 404, allowed);
        return json(result, 200, allowed);
      }

      // --- Sharing and analytics --------------------------------------------
      //
      // These sit outside /api because they are opened by crawlers and by
      // people following a link, not by the application.

      const shareMatch = path.match(/^\/share\/([a-z]+)\/([^/]+)$/);
      if (method === 'GET' && shareMatch) {
        return shareCard(
          env.WEA_DB,
          shareMatch[1],
          decodeURIComponent(shareMatch[2]),
          await publicSiteUrl(env),
          url.origin,
          url.searchParams,
        );
      }

      // Campaign short link: count the click, then hand the visitor on with
      // the campaign parameters attached.
      const followMatch = path.match(/^\/s\/([A-Za-z0-9_-]{3,40})$/);
      if (method === 'GET' && followMatch) {
        const target = await followShareLink(
          env.WEA_DB,
          followMatch[1],
          await publicSiteUrl(env),
        );
        if (!target) return fail('NOT_FOUND', 404, allowed);
        return Response.redirect(target, 302);
      }

      if (method === 'POST' && path === '/api/analytics/page-view') {
        await recordPageView(
          { db: env.WEA_DB, request, salt: str(env.ANALYTICS_SALT) || 'wea-analytics' },
          await readJson(request),
        );
        return json({ ok: true }, 202, allowed);
      }

      if (method === 'POST' && path === '/api/analytics/event') {
        await recordFunnelEvent(
          { db: env.WEA_DB, request, salt: str(env.ANALYTICS_SALT) || 'wea-analytics' },
          await readJson(request),
        );
        return json({ ok: true }, 202, allowed);
      }

      // --- Payment webhooks -------------------------------------------------

      /**
       * The processor telling us something happened.
       *
       * The signature is checked, and then the *only* thing taken from the
       * body is which transaction it concerns: settlement re-verifies against
       * the processor's own API. A forged webhook therefore cannot mark
       * anything paid, and a genuine one that arrives before the payer gets
       * back to the site still settles the registration.
       */
      const webhookMatch = path.match(/^\/api\/payments\/webhook\/([a-z]+)$/);
      if (method === 'POST' && webhookMatch) {
        const rawBody = await request.text();
        const notice = await readWebhook(
          webhookMatch[1],
          request,
          rawBody,
          paymentSecrets(env),
        );
        if (!notice.ok) return fail('NOT_AUTHORISED', 401, allowed);
        if (notice.reference !== '') {
          await settleEventPayment(env.WEA_DB, notice.reference, paymentSecrets(env));
        }
        return json({ ok: true }, 200, allowed);
      }

      // --- Social sign-in ---------------------------------------------------

      if (method === 'GET' && path === '/api/auth/providers') {
        return json({ providers: availableProviders(env) }, 200, allowed);
      }

      if (method === 'POST' && path === '/api/auth/social') {
        const body = await readJson(request);
        const result = await signInWithProvider(
          env.WEA_DB,
          env,
          str(body.provider),
          str(body.id_token),
        );
        if (!result.ok || !result.userId) {
          return fail(
            result.code ?? 'INVALID_CREDENTIALS',
            result.code === 'PROVIDER_NOT_CONFIGURED' ? 501 : 401,
            allowed,
          );
        }
        const row = await findUserById(env, result.userId);
        if (!row) return fail('INVALID_CREDENTIALS', 401, allowed);
        if (row.status !== 'ACTIVE') return fail(`ACCOUNT_${row.status}`, 403, allowed);
        const session = await createSession(env, row.id);
        return json(
          { profile: toProfile(row), session, created: result.created === true },
          result.created ? 201 : 200,
          allowed,
        );
      }

      /**
       * One-time creation of the first Super Admin. Guarded by a secret and
       * refuses once any Super Admin exists, so it cannot be replayed to mint
       * privileged accounts. Returns the temporary password exactly once.
       */
      if (method === 'POST' && path === '/api/auth/bootstrap') {
        const provided = request.headers.get('X-Bootstrap-Token') ?? '';
        if (!env.BOOTSTRAP_TOKEN || provided !== env.BOOTSTRAP_TOKEN) {
          return fail('NOT_AUTHORISED', 403, allowed);
        }
        const existing = await env.WEA_DB.prepare(
          "SELECT id FROM users WHERE role = 'SUPER_ADMIN' LIMIT 1",
        ).first<{ id: string }>();
        if (existing) {
          return fail('ALREADY_BOOTSTRAPPED', 409, allowed);
        }
        const email = (env.SUPERADMIN_EMAIL ?? '').trim().toLowerCase();
        if (!email) return fail('SERVER', 500, allowed, 'SUPERADMIN_EMAIL is not set.');

        const password = temporaryPassword();
        const salt = randomHex(16);
        const id = newId();
        await env.WEA_DB.prepare(
          `INSERT INTO users
             (id, email, password_hash, password_salt, password_iterations,
              first_name, last_name, role, status, email_verified, must_change_password)
           VALUES (?1, ?2, ?3, ?4, ?5, 'WEA', 'Super Admin', 'SUPER_ADMIN', 'ACTIVE', 1, 1)`,
        )
          .bind(id, email, await hashPassword(password, salt), salt, PBKDF2_ITERATIONS)
          .run();
        await audit(env, null, 'BOOTSTRAP_SUPER_ADMIN', id, email);
        const row = await findUserById(env, id);
        return json(
          { profile: toProfile(row!), temporary_password: password },
          201,
          allowed,
        );
      }

      if (method === 'POST' && path === '/api/auth/register') {
        const body = await readJson(request);
        const email = str(body.email).toLowerCase();
        const password = str(body.password);
        if (!email.includes('@')) return fail('INVALID_EMAIL', 400, allowed);
        if (!isPasswordAcceptable(password)) return fail('WEAK_PASSWORD', 400, allowed);
        if (await findUserByEmail(env, email)) {
          return fail('EMAIL_EXISTS', 409, allowed);
        }
        // A requested role is honoured only if it is self-assignable; anything
        // else silently becomes APPLICANT. Privilege is never client-chosen.
        const requested = str(body.role) as Role;
        const role: Role = SELF_ASSIGNABLE.includes(requested) ? requested : 'APPLICANT';

        const id = newId();
        const salt = randomHex(16);
        await env.WEA_DB.prepare(
          `INSERT INTO users
             (id, email, password_hash, password_salt, password_iterations,
              first_name, last_name, phone, country, role, status)
           VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, 'PENDING')`,
        )
          .bind(
            id,
            email,
            await hashPassword(password, salt),
            salt,
            PBKDF2_ITERATIONS,
            str(body.first_name),
            str(body.last_name),
            str(body.phone) || null,
            str(body.country) || null,
            role,
          )
          .run();

        const verification = await issueToken(
          env,
          id,
          'EMAIL_VERIFICATION',
          VERIFICATION_TTL_HOURS * 3_600_000,
        );
        const row = await findUserById(env, id);
        const session = await createSession(env, id);
        return json(
          {
            profile: toProfile(row!),
            session,
            // Only present when EXPOSE_AUTH_TOKENS is on, so the flow can be
            // completed before an email provider is connected.
            verification_token: devToken(env, verification),
          },
          201,
          allowed,
        );
      }

      if (method === 'POST' && path === '/api/auth/login') {
        const body = await readJson(request);
        const user = await findUserByEmail(env, str(body.email));
        const password = str(body.password);
        // Unknown address and wrong password give the same answer so accounts
        // cannot be enumerated.
        if (
          !user ||
          !(await verifyPassword(
            password,
            user.password_salt,
            user.password_hash,
            user.password_iterations,
          ))
        ) {
          return fail('INVALID_CREDENTIALS', 401, allowed);
        }
        if (user.status !== 'ACTIVE') {
          return fail(`ACCOUNT_${user.status}`, 403, allowed);
        }
        const session = await createSession(env, user.id);
        return json({ profile: toProfile(user), session }, 200, allowed);
      }

      if (method === 'POST' && path === '/api/auth/forgot-password') {
        const body = await readJson(request);
        const user = await findUserByEmail(env, str(body.email));
        let token: string | undefined;
        if (user) {
          token = await issueToken(
            env,
            user.id,
            'PASSWORD_RESET',
            RESET_TTL_MINUTES * 60_000,
          );
        }
        // Always 200: the response must not reveal whether the address exists.
        return json({ ok: true, reset_token: devToken(env, token) }, 200, allowed);
      }

      if (method === 'POST' && path === '/api/auth/reset-password') {
        const body = await readJson(request);
        const password = str(body.password);
        if (!isPasswordAcceptable(password)) return fail('WEAK_PASSWORD', 400, allowed);
        const result = await consumeToken(env, str(body.token), 'PASSWORD_RESET');
        if ('error' in result) return fail(result.error, 400, allowed);
        await setPassword(env, result.userId, password);
        // Every existing session is dropped: a reset should log out anyone
        // holding the old credentials.
        await env.WEA_DB.prepare('DELETE FROM sessions WHERE user_id = ?1')
          .bind(result.userId)
          .run();
        return json({ ok: true }, 200, allowed);
      }

      if (method === 'POST' && path === '/api/auth/verify-email') {
        const body = await readJson(request);
        const result = await consumeToken(env, str(body.token), 'EMAIL_VERIFICATION');
        if ('error' in result) return fail(result.error, 400, allowed);
        await env.WEA_DB.prepare(
          `UPDATE users
             SET email_verified = 1,
                 status = CASE WHEN status = 'PENDING' THEN 'ACTIVE' ELSE status END,
                 updated_at = CURRENT_TIMESTAMP
           WHERE id = ?1`,
        )
          .bind(result.userId)
          .run();
        const row = await findUserById(env, result.userId);
        return json({ profile: toProfile(row!) }, 200, allowed);
      }

      if (method === 'POST' && path === '/api/auth/resend-verification') {
        const body = await readJson(request);
        const user = await findUserByEmail(env, str(body.email));
        let token: string | undefined;
        if (user && user.email_verified === 0) {
          token = await issueToken(
            env,
            user.id,
            'EMAIL_VERIFICATION',
            VERIFICATION_TTL_HOURS * 3_600_000,
          );
        }
        return json(
          { ok: true, verification_token: devToken(env, token) },
          200,
          allowed,
        );
      }

      // --- Authenticated ---------------------------------------------------

      const actor = await authenticate(request, env);

      /**
       * Enquiries are open to the public, so this sits before the sign-in
       * gate. A signed-in sender is linked to the message so replies can reach
       * them in the application; an anonymous one is answered by email.
       */
      if (method === 'POST' && path === '/api/contact') {
        const result = await submitEnquiry(
          env.WEA_DB,
          await readJson(request),
          actor,
        );
        if (!result.ok) {
          return fail(result.code!, 400, allowed, result.message);
        }
        return json(result.data, 201, allowed);
      }

      // --- Event registration ------------------------------------------------
      //
      // Open to visitors as well as to accounts: an event may accept guests,
      // and requiring a password before somebody can tell us their name is
      // exactly what loses the registration. Ownership of a guest registration
      // is proved with the token issued when it was created.

      const eventContextMatch = path.match(/^\/api\/events\/([^/]+)\/registration-context$/);
      if (method === 'GET' && eventContextMatch) {
        const context = await eventRegistrationContext(
          env.WEA_DB,
          decodeURIComponent(eventContextMatch[1]),
          actor,
        );
        if (!context) return fail('NOT_FOUND', 404, allowed);
        return json(context, 200, allowed);
      }

      const eventRegisterMatch = path.match(/^\/api\/events\/([^/]+)\/registrations$/);
      if (method === 'POST' && eventRegisterMatch) {
        const result = await saveEventRegistration(
          env.WEA_DB,
          decodeURIComponent(eventRegisterMatch[1]),
          await readJson(request),
          actor,
        );
        if (!result.ok) {
          const status =
            result.code === 'NOT_FOUND'
              ? 404
              : result.code === 'ACCOUNT_REQUIRED'
                ? 401
                : 400;
          return fail(result.code!, status, allowed, result.message);
        }
        return json(result.data, 201, allowed);
      }

      const registrationMatch = path.match(/^\/api\/events\/registrations\/([^/]+)$/);
      if (method === 'GET' && registrationMatch) {
        const registration = await findOwnedRegistration(
          env.WEA_DB,
          decodeURIComponent(registrationMatch[1]),
          actor,
          resumeTokenOf(request),
        );
        // Deliberately indistinguishable from "no such registration": whether
        // a reference exists is not something a stranger gets to learn.
        if (!registration) return fail('NOT_FOUND', 404, allowed);
        return json(await participantDashboard(env.WEA_DB, registration), 200, allowed);
      }

      const beginPaymentMatch = path.match(
        /^\/api\/events\/registrations\/([^/]+)\/payment$/,
      );
      if (method === 'POST' && beginPaymentMatch) {
        const registration = await findOwnedRegistration(
          env.WEA_DB,
          decodeURIComponent(beginPaymentMatch[1]),
          actor,
          resumeTokenOf(request),
        );
        if (!registration) return fail('NOT_FOUND', 404, allowed);
        const site = await publicSiteUrl(env);
        const result = await beginEventPayment(
          env.WEA_DB,
          registration,
          paymentSecrets(env),
          `${site.replace(/\/$/, '')}/events/registration/${registration.reference}`,
        );
        if (!result.ok) {
          return fail(result.code!, result.code === 'ALREADY_PAID' ? 409 : 400, allowed, result.message);
        }
        return json(result.data, 201, allowed);
      }

      /**
       * Confirms what actually happened with a payment.
       *
       * Called when the payer returns from the processor, and safe to call
       * again at any time: it asks the processor rather than believing the
       * browser, so a tampered return URL changes nothing.
       */
      const verifyPaymentMatch = path.match(
        /^\/api\/events\/registrations\/([^/]+)\/verify$/,
      );
      if (method === 'POST' && verifyPaymentMatch) {
        const registration = await findOwnedRegistration(
          env.WEA_DB,
          decodeURIComponent(verifyPaymentMatch[1]),
          actor,
          resumeTokenOf(request),
        );
        if (!registration) return fail('NOT_FOUND', 404, allowed);

        const body = await readJson(request);
        // The client may name the attempt it is asking about; if it does not,
        // the most recent one is the one that matters.
        const reference =
          str(body.payment_reference) ||
          str(
            (await latestPayment(env.WEA_DB, str(registration.id)))?.provider_reference,
          );
        if (reference === '') return fail('NOT_FOUND', 404, allowed);

        // A payment reference belongs to the registration it was issued for.
        if (!reference.startsWith(str(registration.reference))) {
          return fail('NOT_AUTHORISED', 403, allowed);
        }

        const result = await settleEventPayment(
          env.WEA_DB,
          reference,
          paymentSecrets(env),
        );
        if (!result.ok) return fail(result.code!, 404, allowed);
        return json(result.data, 200, allowed);
      }

      const joinMatch = path.match(
        /^\/api\/events\/registrations\/([^/]+)\/sessions\/([^/]+)\/join$/,
      );
      if (method === 'POST' && joinMatch) {
        const registration = await findOwnedRegistration(
          env.WEA_DB,
          decodeURIComponent(joinMatch[1]),
          actor,
          resumeTokenOf(request),
        );
        if (!registration) return fail('NOT_FOUND', 404, allowed);
        const result = await joinEventSession(
          env.WEA_DB,
          registration,
          decodeURIComponent(joinMatch[2]),
        );
        if (!result.ok) {
          return fail(
            result.code!,
            result.code === 'PAYMENT_REQUIRED'
              ? 402
              : result.code === 'NOT_FOUND'
                ? 404
                : 409,
            allowed,
          );
        }
        return json(result.data, 200, allowed);
      }

      if (method === 'POST' && path === '/api/auth/logout') {
        const header = request.headers.get('Authorization');
        if (header?.startsWith('Bearer ')) {
          await env.WEA_DB.prepare('DELETE FROM sessions WHERE token_hash = ?1')
            .bind(await sha256(header.slice(7)))
            .run();
        }
        return json({ ok: true }, 200, allowed);
      }

      if (!actor) {
        if (
          path.startsWith('/api/auth/') ||
          path.startsWith('/api/admin/') ||
          path.startsWith('/api/registrations') ||
          path.startsWith('/api/contact/') ||
          path === '/api/profile' ||
          path === '/api/enrolments'
        ) {
          return fail('SESSION_EXPIRED', 401, allowed);
        }
        return fail('NOT_FOUND', 404, allowed);
      }

      if (method === 'GET' && path === '/api/auth/session') {
        return json({ profile: toProfile(actor) }, 200, allowed);
      }

      if (method === 'POST' && path === '/api/auth/change-password') {
        const body = await readJson(request);
        const current = str(body.current_password);
        const next = str(body.new_password);
        if (
          !(await verifyPassword(
            current,
            actor.password_salt,
            actor.password_hash,
            actor.password_iterations,
          ))
        ) {
          return fail('INVALID_CREDENTIALS', 401, allowed);
        }
        if (!isPasswordAcceptable(next)) return fail('WEAK_PASSWORD', 400, allowed);
        await setPassword(env, actor.id, next);
        const row = await findUserById(env, actor.id);
        return json({ profile: toProfile(row!) }, 200, allowed);
      }

      if (path === '/api/profile') {
        if (method === 'GET') return json({ profile: toProfile(actor) }, 200, allowed);
        if (method === 'PATCH') {
          const body = await readJson(request);
          // role and status are absent by design: nobody edits their own
          // privileges through this endpoint.
          await env.WEA_DB.prepare(
            `UPDATE users
               SET first_name = COALESCE(?1, first_name),
                   last_name = COALESCE(?2, last_name),
                   phone = COALESCE(?3, phone),
                   country = COALESCE(?4, country),
                   avatar_url = COALESCE(?5, avatar_url),
                   updated_at = CURRENT_TIMESTAMP
             WHERE id = ?6`,
          )
            .bind(
              body.first_name === undefined ? null : str(body.first_name),
              body.last_name === undefined ? null : str(body.last_name),
              body.phone === undefined ? null : str(body.phone),
              body.country === undefined ? null : str(body.country),
              body.avatar_url === undefined ? null : str(body.avatar_url),
              actor.id,
            )
            .run();
          const row = await findUserById(env, actor.id);
          return json({ profile: toProfile(row!) }, 200, allowed);
        }
      }

      // --- My enquiries ------------------------------------------------------

      if (method === 'GET' && path === '/api/contact/messages') {
        return json(
          { messages: await listMyEnquiries(env.WEA_DB, actor.id) },
          200,
          allowed,
        );
      }

      // Follow up on your own enquiry. Ownership is checked inside.
      const followUpMatch = path.match(/^\/api\/contact\/messages\/([^/]+)\/replies$/);
      if (method === 'POST' && followUpMatch) {
        const result = await replyToEnquiry(
          env.WEA_DB,
          actor,
          followUpMatch[1],
          await readJson(request),
        );
        if (!result.ok) {
          return fail(
            result.code!,
            result.code === 'NOT_FOUND'
              ? 404
              : result.code === 'NOT_AUTHORISED'
                ? 403
                : 400,
            allowed,
            result.message,
          );
        }
        return json({ ok: true }, 201, allowed);
      }

      // --- Registration ----------------------------------------------------

      /**
       * What still needs asking for this applicant and programme. Everything
       * WEA already holds comes back under `known`, so the form can confirm it
       * instead of asking for it again.
       */
      if (method === 'GET' && path === '/api/registrations/context') {
        const programmeId = url.searchParams.get('programme_id') ?? '';
        if (!programmeId) return fail('INVALID_REQUEST', 400, allowed);
        const programme = await env.WEA_DB.prepare(
          'SELECT id FROM programmes WHERE (id = ?1 OR slug = ?1) AND status = ?2',
        )
          .bind(programmeId, 'PUBLISHED')
          .first<{ id: string }>();
        if (!programme) return fail('NOT_FOUND', 404, allowed);
        return json(
          await registrationContext(env.WEA_DB, actor, programme.id),
          200,
          allowed,
        );
      }

      if (path === '/api/registrations') {
        if (method === 'GET') {
          return json(
            {
              registrations: await listRegistrations(env.WEA_DB, {
                userId: actor.id,
                status: url.searchParams.get('status'),
              }),
            },
            200,
            allowed,
          );
        }
        if (method === 'POST') {
          const result = await submitRegistration(
            env.WEA_DB,
            actor,
            await readJson(request),
          );
          if (!result.ok) {
            const status =
              result.code === 'NOT_FOUND'
                ? 404
                : result.code === 'ALREADY_REGISTERED'
                  ? 409
                  : 400;
            return fail(result.code!, status, allowed, result.message);
          }
          return json({ registration: result.registration }, 201, allowed);
        }
      }

      // Every event this account has registered for. Scoped to the caller;
      // there is no parameter that would widen it to somebody else's.
      if (method === 'GET' && path === '/api/my/event-registrations') {
        return json(
          { registrations: await myEventRegistrations(env.WEA_DB, actor.id) },
          200,
          allowed,
        );
      }

      // --- Enrolments ------------------------------------------------------

      if (path === '/api/enrolments') {
        if (method === 'GET') {
          const requested = url.searchParams.get('user_id');
          if (requested && requested !== actor.id && actor.role !== 'SUPER_ADMIN') {
            return fail('NOT_AUTHORISED', 403, allowed);
          }
          const rows = await env.WEA_DB.prepare(
            'SELECT * FROM programme_enrolments WHERE user_id = ?1 ORDER BY created_at',
          )
            .bind(requested ?? actor.id)
            .all();
          return json({ enrolments: rows.results }, 200, allowed);
        }
        if (method === 'POST') {
          const body = await readJson(request);
          const targetUser = str(body.user_id) || actor.id;
          const waive = body.waive_payment === true;
          // Waiving payment, or enrolling somebody else, is a Super Admin act.
          if ((waive || targetUser !== actor.id) && actor.role !== 'SUPER_ADMIN') {
            return fail('NOT_AUTHORISED', 403, allowed);
          }
          const programmeId = str(body.programme_id);
          if (!programmeId) return fail('INVALID_REQUEST', 400, allowed);
          const existing = await env.WEA_DB.prepare(
            'SELECT id FROM programme_enrolments WHERE user_id = ?1 AND programme_id = ?2',
          )
            .bind(targetUser, programmeId)
            .first();
          if (existing) return fail('ALREADY_ENROLLED', 409, allowed);

          const id = newId();
          await env.WEA_DB.prepare(
            `INSERT INTO programme_enrolments
               (id, user_id, programme_id, payment_status, granted_by)
             VALUES (?1, ?2, ?3, ?4, ?5)`,
          )
            .bind(id, targetUser, programmeId, waive ? 'WAIVED' : 'PENDING', waive ? actor.id : null)
            .run();
          if (waive) {
            await audit(env, actor.id, 'WAIVE_PAYMENT', targetUser, programmeId);
          }
          const row = await env.WEA_DB.prepare(
            'SELECT * FROM programme_enrolments WHERE id = ?1',
          )
            .bind(id)
            .first();
          return json({ enrolment: row }, 201, allowed);
        }
      }

      // --- Super Admin -----------------------------------------------------

      if (path.startsWith('/api/admin/')) {
        if (actor.role !== 'SUPER_ADMIN') {
          return fail('NOT_AUTHORISED', 403, allowed);
        }

        // --- Media -----------------------------------------------------------

        if (method === 'POST' && path === '/api/admin/media') {
          return uploadMedia(request, env, actor.id, allowed);
        }
        if (method === 'GET' && path === '/api/admin/media') {
          return listMedia(env, allowed);
        }
        if (method === 'DELETE' && path.startsWith('/api/admin/media/')) {
          return deleteMedia(
            env,
            decodeURIComponent(path.slice('/api/admin/media/'.length)),
            allowed,
          );
        }

        // --- Editable site copy ----------------------------------------------

        if (path === '/api/admin/settings') {
          if (method === 'GET') {
            const rows = await env.WEA_DB.prepare(
              'SELECT key, value FROM site_settings ORDER BY key',
            ).all();
            return json({ settings: rows.results }, 200, allowed);
          }
          if (method === 'PUT') {
            const body = await readJson(request);
            const entries = Object.entries(body);
            if (entries.length > 0) {
              await env.WEA_DB.batch(
                entries.map(([key, value]) =>
                  env.WEA_DB.prepare(
                    `INSERT INTO site_settings (key, value, updated_at)
                     VALUES (?1, ?2, CURRENT_TIMESTAMP)
                     ON CONFLICT(key) DO UPDATE
                       SET value = excluded.value, updated_at = CURRENT_TIMESTAMP`,
                  ).bind(key, str(value)),
                ),
              );
            }
            await audit(env, actor.id, 'UPDATE_SETTINGS', undefined, `${entries.length} keys`);
            return json({ ok: true }, 200, allowed);
          }
        }

        // --- Registrations ---------------------------------------------------

        if (method === 'GET' && path === '/api/admin/registrations') {
          return json(
            {
              registrations: await listRegistrations(env.WEA_DB, {
                status: url.searchParams.get('status'),
              }),
            },
            200,
            allowed,
          );
        }

        const reviewMatch = path.match(/^\/api\/admin\/registrations\/([^/]+)$/);
        if (method === 'PATCH' && reviewMatch) {
          const result = await reviewRegistration(
            env.WEA_DB,
            actor.id,
            reviewMatch[1],
            await readJson(request),
          );
          if (!result.ok) {
            return fail(result.code!, result.code === 'NOT_FOUND' ? 404 : 400, allowed);
          }
          await audit(env, actor.id, 'REVIEW_REGISTRATION', reviewMatch[1]);
          return json({ registration: result.registration }, 200, allowed);
        }

        // --- Enquiries -------------------------------------------------------

        if (method === 'GET' && path === '/api/admin/contact-messages') {
          return json(
            {
              messages: await listEnquiries(
                env.WEA_DB,
                url.searchParams.get('status'),
              ),
            },
            200,
            allowed,
          );
        }

        const enquiryReplyMatch = path.match(
          /^\/api\/admin\/contact-messages\/([^/]+)\/replies$/,
        );
        if (method === 'POST' && enquiryReplyMatch) {
          const result = await replyToEnquiry(
            env.WEA_DB,
            actor,
            enquiryReplyMatch[1],
            await readJson(request),
          );
          if (!result.ok) {
            return fail(
              result.code!,
              result.code === 'NOT_FOUND' ? 404 : 400,
              allowed,
              result.message,
            );
          }
          await audit(env, actor.id, 'REPLY_ENQUIRY', enquiryReplyMatch[1]);
          return json({ ok: true }, 201, allowed);
        }

        const enquiryMatch = path.match(/^\/api\/admin\/contact-messages\/([^/]+)$/);
        if (method === 'PATCH' && enquiryMatch) {
          const result = await setEnquiryStatus(
            env.WEA_DB,
            actor.id,
            enquiryMatch[1],
            str((await readJson(request)).status),
          );
          if (!result.ok) {
            return fail(result.code!, result.code === 'NOT_FOUND' ? 404 : 400, allowed);
          }
          return json({ ok: true }, 200, allowed);
        }

        // --- Event registrations ---------------------------------------------
        //
        // These sit above the generic resource layer because their paths would
        // otherwise be read as "the resource `event-registrations`, row
        // `export`". Registrations are not editable rows; they move through a
        // state machine, so they get their own handlers.

        if (method === 'GET' && path === '/api/admin/event-registrations/export') {
          const csv = await exportEventRegistrations(
            env.WEA_DB,
            url.searchParams.get('event_id'),
          );
          await audit(env, actor.id, 'EXPORT_EVENT_REGISTRATIONS');
          return new Response(csv, {
            headers: {
              ...corsHeaders(allowed),
              'Content-Type': 'text/csv; charset=utf-8',
              'Content-Disposition':
                'attachment; filename="wea-event-registrations.csv"',
            },
          });
        }

        if (method === 'GET' && path === '/api/admin/event-registrations') {
          return json(
            {
              registrations: await listEventRegistrations(
                env.WEA_DB,
                url.searchParams,
              ),
            },
            200,
            allowed,
          );
        }

        const adminRegistrationMatch = path.match(
          /^\/api\/admin\/event-registrations\/([^/]+)$/,
        );
        if (method === 'PATCH' && adminRegistrationMatch) {
          const result = await setEventRegistrationStatus(
            env.WEA_DB,
            adminRegistrationMatch[1],
            await readJson(request),
          );
          if (!result.ok) {
            return fail(result.code!, result.code === 'NOT_FOUND' ? 404 : 400, allowed);
          }
          await audit(
            env,
            actor.id,
            'SET_EVENT_REGISTRATION_STATUS',
            adminRegistrationMatch[1],
          );
          return json(result.data, 200, allowed);
        }

        if (method === 'GET' && path === '/api/admin/event-overview') {
          const eventId = url.searchParams.get('event_id');
          const [overview, funnel] = await Promise.all([
            eventOverview(env.WEA_DB, eventId),
            eventFunnel(env.WEA_DB, eventId),
          ]);
          return json({ overview, funnel }, 200, allowed);
        }

        // Turns stale attempts into named leads. Idempotent, so it is safe to
        // run from a button as well as from a schedule.
        if (method === 'POST' && path === '/api/admin/event-registrations/sweep') {
          const changed = await sweepAbandonedRegistrations(env.WEA_DB);
          await audit(env, actor.id, 'SWEEP_ABANDONED', undefined, `${changed} rows`);
          return json({ ok: true, updated: changed }, 200, allowed);
        }

        // --- Site analytics ---------------------------------------------------

        if (method === 'GET' && path === '/api/admin/analytics') {
          return json(
            await siteAnalytics(env.WEA_DB, num(url.searchParams.get('days')) ?? 30),
            200,
            allowed,
          );
        }

        if (method === 'GET' && path === '/api/admin/share-links/performance') {
          return json(
            {
              links: await shareLinkPerformance(env.WEA_DB),
              site_url: await publicSiteUrl(env),
              api_origin: url.origin,
            },
            200,
            allowed,
          );
        }

        // A campaign link needs a code, and nobody should have to invent one.
        if (method === 'POST' && path === '/api/admin/share-links') {
          const body = await readJson(request);
          if (str(body.code) === '') body.code = randomHex(4);
          body.created_by = actor.id;
          const spec = resourceByName('share-links')!;
          const result = await createResource(env.WEA_DB, spec, body);
          if (!result.ok) return fail(result.code!, 400, allowed, result.message);
          await audit(env, actor.id, 'CREATE', 'share-links', String(result.row?.id));
          return json({ item: result.row }, 201, allowed);
        }

        // --- Catalogue CRUD --------------------------------------------------
        // Every managed entity shares this code path; see resources.ts.

        const resourceMatch = path.match(
          /^\/api\/admin\/([a-z-]+)(?:\/([^/]+))?(?:\/(reorder))?$/,
        );
        if (resourceMatch) {
          const spec = resourceByName(resourceMatch[1]);
          if (spec) {
            const targetId = resourceMatch[2];
            const action = resourceMatch[3];

            if (method === 'POST' && targetId === 'reorder') {
              const body = await readJson(request);
              const ids = Array.isArray(body.ids) ? (body.ids as string[]) : [];
              const result = await reorderResource(env.WEA_DB, spec, ids);
              if (!result.ok) return fail(result.code!, 400, allowed);
              await audit(env, actor.id, 'REORDER', spec.name, `${ids.length} items`);
              return json({ ok: true }, 200, allowed);
            }

            if (method === 'GET' && !targetId) {
              return json(
                { items: await listResource(env.WEA_DB, spec, url.searchParams) },
                200,
                allowed,
              );
            }

            if (method === 'GET' && targetId && !action) {
              const row = await env.WEA_DB.prepare(
                `SELECT * FROM ${spec.table} WHERE id = ?1`,
              )
                .bind(targetId)
                .first();
              if (!row) return fail('NOT_FOUND', 404, allowed);
              return json({ item: row }, 200, allowed);
            }

            if (method === 'POST' && !targetId) {
              const result = await createResource(
                env.WEA_DB,
                spec,
                await readJson(request),
              );
              if (!result.ok) {
                return fail(result.code!, 400, allowed, result.message);
              }
              await audit(env, actor.id, 'CREATE', spec.name, String(result.row?.id));
              return json({ item: result.row }, 201, allowed);
            }

            if (method === 'PATCH' && targetId) {
              const result = await updateResource(
                env.WEA_DB,
                spec,
                targetId,
                await readJson(request),
              );
              if (!result.ok) {
                return fail(
                  result.code!,
                  result.code === 'NOT_FOUND' ? 404 : 400,
                  allowed,
                  result.message,
                );
              }
              await audit(env, actor.id, 'UPDATE', spec.name, targetId);
              return json({ item: result.row }, 200, allowed);
            }

            if (method === 'DELETE' && targetId) {
              const result = await deleteResource(env.WEA_DB, spec, targetId);
              if (!result.ok) return fail(result.code!, 404, allowed);
              await audit(env, actor.id, 'DELETE', spec.name, targetId);
              return json({ ok: true }, 200, allowed);
            }
          }
        }

        // Faculty assignment is a join table, so it sits outside the generic
        // resource layer.
        if (method === 'PUT' && path === '/api/admin/programme-faculty') {
          const body = await readJson(request);
          const programmeId = str(body.programme_id);
          const facultyIds = Array.isArray(body.faculty_ids)
            ? (body.faculty_ids as string[])
            : [];
          if (!programmeId) return fail('INVALID_REQUEST', 400, allowed);
          await env.WEA_DB.prepare(
            'DELETE FROM programme_faculty WHERE programme_id = ?1',
          )
            .bind(programmeId)
            .run();
          if (facultyIds.length > 0) {
            await env.WEA_DB.batch(
              facultyIds.map((facultyId, index) =>
                env.WEA_DB.prepare(
                  `INSERT OR IGNORE INTO programme_faculty
                     (programme_id, faculty_id, role, sort_order)
                   VALUES (?1, ?2, ?3, ?4)`,
                ).bind(
                  programmeId,
                  facultyId,
                  index === 0 ? 'Programme Director' : 'Faculty',
                  index + 1,
                ),
              ),
            );
          }
          await audit(env, actor.id, 'SET_PROGRAMME_FACULTY', programmeId);
          return json({ ok: true }, 200, allowed);
        }

        if (method === 'GET' && path === '/api/admin/users') {
          const rows = await env.WEA_DB.prepare(
            'SELECT * FROM users ORDER BY email',
          ).all<UserRow>();
          return json({ users: rows.results.map(toProfile) }, 200, allowed);
        }

        if (method === 'POST' && path === '/api/admin/users') {
          const body = await readJson(request);
          const email = str(body.email).toLowerCase();
          const role = str(body.role) as Role;
          if (!email.includes('@')) return fail('INVALID_EMAIL', 400, allowed);
          if (!ALL_ROLES.includes(role)) return fail('INVALID_ROLE', 400, allowed);
          if (await findUserByEmail(env, email)) return fail('EMAIL_EXISTS', 409, allowed);

          const password = temporaryPassword();
          const salt = randomHex(16);
          const id = newId();
          // Lecturers still land in PENDING_APPROVAL: creating the account is
          // not the same as approving it.
          const status: Status = role === 'LECTURER' ? 'PENDING_APPROVAL' : 'ACTIVE';
          await env.WEA_DB.prepare(
            `INSERT INTO users
               (id, email, password_hash, password_salt, password_iterations,
                first_name, last_name, role, status, email_verified, must_change_password)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, 1, 1)`,
          )
            .bind(
              id,
              email,
              await hashPassword(password, salt),
              salt,
              PBKDF2_ITERATIONS,
              str(body.first_name),
              str(body.last_name),
              role,
              status,
            )
            .run();
          await audit(env, actor.id, 'CREATE_USER', id, role);
          const row = await findUserById(env, id);
          return json(
            { profile: toProfile(row!), temporary_password: password },
            201,
            allowed,
          );
        }

        const userMatch = path.match(/^\/api\/admin\/users\/([^/]+)$/);
        if (userMatch) {
          const targetId = userMatch[1];
          if (method === 'DELETE') {
            if (targetId === actor.id) {
              return fail('NOT_AUTHORISED', 400, allowed,
                'You cannot delete the account you are signed in with.');
            }
            await env.WEA_DB.prepare('DELETE FROM users WHERE id = ?1').bind(targetId).run();
            await audit(env, actor.id, 'DELETE_USER', targetId);
            return json({ ok: true }, 200, allowed);
          }
          if (method === 'PATCH') {
            const body = await readJson(request);
            const role = str(body.role) as Role;
            const status = str(body.status) as Status;
            if (role && !ALL_ROLES.includes(role)) return fail('INVALID_ROLE', 400, allowed);
            await env.WEA_DB.prepare(
              `UPDATE users
                 SET role = COALESCE(?1, role),
                     status = COALESCE(?2, status),
                     updated_at = CURRENT_TIMESTAMP
               WHERE id = ?3`,
            )
              .bind(role || null, status || null, targetId)
              .run();
            await audit(env, actor.id, 'UPDATE_USER', targetId, `${role || ''} ${status || ''}`.trim());
            const row = await findUserById(env, targetId);
            if (!row) return fail('NOT_FOUND', 404, allowed);
            return json({ profile: toProfile(row) }, 200, allowed);
          }
        }
      }

      return fail('NOT_FOUND', 404, allowed);
    } catch (error) {
      // Never surface internal detail; the client shows a generic message.
      console.error('Unhandled API error', error);
      return fail('SERVER', 500, allowed);
    }
  },

  /**
   * Housekeeping.
   *
   * Half-finished registrations are moved into the abandoned list so they stop
   * sitting in the pending queue — they are still kept, because an abandoned
   * registration is exactly the lead the academy wants. Analytics rows past the
   * retention window are removed, since nothing is served by keeping page
   * views for ever.
   */
  async scheduled(_event, env, _ctx): Promise<void> {
    await sweepAbandonedRegistrations(env.WEA_DB);
    await pruneAnalytics(env.WEA_DB);
  },
} satisfies ExportedHandler<Env>;
