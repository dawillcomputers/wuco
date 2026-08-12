/**
 * Social sign-in.
 *
 * The academy's rule is one person, one account. Somebody who has registered
 * for a programme with an address and later signs in with Google using that
 * same address is the same person, and must land on the same record — not on a
 * second, emptier one. That reconciliation is the substance of this module;
 * the token checking exists to make it safe.
 *
 * A provider is offered only when the deployment holds its client id, so an
 * unconfigured environment simply shows the ordinary sign-in and nothing
 * breaks.
 */

import { newId, randomHex, temporaryPassword, hashPassword, PBKDF2_ITERATIONS } from './auth';
import { str } from './http';

export interface SocialConfig {
  GOOGLE_CLIENT_ID?: string;
  APPLE_CLIENT_ID?: string;
}

interface ProviderSpec {
  name: string;
  label: string;
  issuers: string[];
  jwksUrl: string;
  audience(config: SocialConfig): string;
}

const PROVIDERS: ProviderSpec[] = [
  {
    name: 'GOOGLE',
    label: 'Continue with Google',
    issuers: ['https://accounts.google.com', 'accounts.google.com'],
    jwksUrl: 'https://www.googleapis.com/oauth2/v3/certs',
    audience: (config) => str(config.GOOGLE_CLIENT_ID),
  },
  {
    name: 'APPLE',
    label: 'Continue with Apple',
    issuers: ['https://appleid.apple.com'],
    jwksUrl: 'https://appleid.apple.com/auth/keys',
    audience: (config) => str(config.APPLE_CLIENT_ID),
  },
];

/** Providers this deployment can actually complete a sign-in with. */
export function availableProviders(config: SocialConfig) {
  return PROVIDERS.filter((provider) => provider.audience(config) !== '').map((provider) => ({
    provider: provider.name,
    label: provider.label,
    client_id: provider.audience(config),
  }));
}

// --- Token verification ----------------------------------------------------

function base64UrlDecode(value: string): Uint8Array {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/');
  const binary = atob(padded.padEnd(padded.length + ((4 - (padded.length % 4)) % 4), '='));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

const decodeJsonSegment = (segment: string): Record<string, unknown> => {
  try {
    return JSON.parse(new TextDecoder().decode(base64UrlDecode(segment))) as Record<
      string,
      unknown
    >;
  } catch {
    return {};
  }
};

/** The subset of a published JWK this module reads; the rest is passed on. */
type PublishedKey = JsonWebKey & { kid?: string };

/**
 * Verifies an OpenID Connect ID token against the provider's published keys.
 *
 * Everything that matters is checked here: the signature, that the token was
 * issued by the provider, that it was issued *for this application* rather than
 * for some other site the user also signs into, and that it has not expired.
 * Skipping the audience check is the classic way this goes wrong, so it is not
 * optional.
 */
async function verifyIdToken(
  spec: ProviderSpec,
  token: string,
  audience: string,
): Promise<Record<string, unknown> | null> {
  const parts = token.split('.');
  if (parts.length !== 3) return null;

  const header = decodeJsonSegment(parts[0]);
  const claims = decodeJsonSegment(parts[1]);
  if (str(header.alg) !== 'RS256') return null;

  const response = await fetch(spec.jwksUrl);
  if (!response.ok) return null;
  const jwks = (await response.json().catch(() => ({}))) as { keys?: PublishedKey[] };
  const key = (jwks.keys ?? []).find((candidate) => candidate.kid === str(header.kid));
  if (!key) return null;

  let cryptoKey: CryptoKey;
  try {
    cryptoKey = await crypto.subtle.importKey(
      'jwk',
      key,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['verify'],
    );
  } catch {
    return null;
  }

  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    base64UrlDecode(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!valid) return null;

  if (!spec.issuers.includes(str(claims.iss))) return null;
  if (str(claims.aud) !== audience) return null;
  const expiry = Number(claims.exp ?? 0) * 1000;
  if (!Number.isFinite(expiry) || expiry <= Date.now()) return null;

  return claims;
}

export interface SocialResult {
  ok: boolean;
  code?: string;
  userId?: string;
  /** True when this call created the account rather than finding it. */
  created?: boolean;
}

interface UserLookup {
  id: string;
  email: string;
  status: string;
}

/**
 * Signs somebody in with a provider token, creating an account only if the
 * person is genuinely new.
 *
 * Three cases, in order: the identity is already linked; the address belongs to
 * an existing WEA account, which is then linked rather than duplicated; or
 * neither, and a verified account is created. A social account is created with
 * `email_verified = 1` because the provider has already done that work, but
 * with a random password nobody knows, so the credential path stays closed
 * until the person deliberately sets one.
 */
export async function signInWithProvider(
  db: D1Database,
  config: SocialConfig,
  providerName: string,
  idToken: string,
): Promise<SocialResult> {
  const spec = PROVIDERS.find((candidate) => candidate.name === providerName.toUpperCase());
  if (!spec) return { ok: false, code: 'UNSUPPORTED_PROVIDER' };
  const audience = spec.audience(config);
  if (audience === '') return { ok: false, code: 'PROVIDER_NOT_CONFIGURED' };

  const claims = await verifyIdToken(spec, idToken, audience);
  if (!claims) return { ok: false, code: 'INVALID_CREDENTIALS' };

  const subject = str(claims.sub);
  const email = str(claims.email).toLowerCase();
  if (subject === '') return { ok: false, code: 'INVALID_CREDENTIALS' };
  // An unverified address at the provider must not be used to claim an
  // existing WEA account that happens to share it.
  const emailVerified = claims.email_verified === true || claims.email_verified === 'true';

  const linked = await db
    .prepare('SELECT user_id FROM social_identities WHERE provider = ?1 AND subject = ?2')
    .bind(spec.name, subject)
    .first<{ user_id: string }>();
  if (linked) return { ok: true, userId: linked.user_id, created: false };

  if (email === '') return { ok: false, code: 'INVALID_EMAIL' };

  const existing = emailVerified
    ? await db
        .prepare('SELECT id, email, status FROM users WHERE email = ?1')
        .bind(email)
        .first<UserLookup>()
    : null;

  if (existing) {
    if (existing.status !== 'ACTIVE' && existing.status !== 'PENDING') {
      return { ok: false, code: `ACCOUNT_${existing.status}` };
    }
    await db
      .prepare(
        `INSERT OR IGNORE INTO social_identities (id, user_id, provider, subject, email)
         VALUES (?1, ?2, ?3, ?4, ?5)`,
      )
      .bind(newId(), existing.id, spec.name, subject, email)
      .run();
    // Signing in through a provider that has verified the address settles a
    // pending account, exactly as clicking the verification link would.
    await db
      .prepare(
        `UPDATE users
            SET email_verified = 1,
                status = CASE WHEN status = 'PENDING' THEN 'ACTIVE' ELSE status END,
                updated_at = CURRENT_TIMESTAMP
          WHERE id = ?1`,
      )
      .bind(existing.id)
      .run();
    return { ok: true, userId: existing.id, created: false };
  }

  const id = newId();
  const salt = randomHex(16);
  const given = str(claims.given_name) || str(claims.name).split(' ')[0] || 'WEA';
  const family = str(claims.family_name) || str(claims.name).split(' ').slice(1).join(' ') || 'Member';

  await db
    .prepare(
      `INSERT INTO users
         (id, email, password_hash, password_salt, password_iterations,
          first_name, last_name, role, status, email_verified, must_change_password)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, 'APPLICANT', 'ACTIVE', 1, 0)`,
    )
    .bind(
      id,
      email,
      await hashPassword(temporaryPassword(), salt),
      salt,
      PBKDF2_ITERATIONS,
      given,
      family,
    )
    .run();

  await db
    .prepare(
      `INSERT INTO social_identities (id, user_id, provider, subject, email)
       VALUES (?1, ?2, ?3, ?4, ?5)`,
    )
    .bind(newId(), id, spec.name, subject, email)
    .run();

  return { ok: true, userId: id, created: true };
}
