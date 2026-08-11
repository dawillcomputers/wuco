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
import { corsHeaders, fail, json, readJson, str } from './http';
import { deleteMedia, listMedia, serveMedia, uploadMedia } from './media';
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
} satisfies ExportedHandler<Env>;
