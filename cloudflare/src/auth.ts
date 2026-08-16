/**
 * Credential handling, sessions and access control for the WEA API.
 *
 * Passwords never leave this module in plaintext and are never stored: only a
 * PBKDF2-SHA256 digest with a per-user salt. Session and link tokens are
 * generated here, handed to the client once, and persisted only as SHA-256
 * digests so a database copy cannot be replayed against the API.
 */

export const PBKDF2_ITERATIONS = 100_000;
/**
 * How long a session lasts without being used.
 *
 * Three months, because the academy's people come back between cohorts rather
 * than daily, and signing a learner out between two modules taught a month
 * apart achieves nothing except a forgotten password. The session is extended
 * on use, so somebody who visits at all is never signed out; only genuine
 * absence expires it.
 *
 * Signing out still ends it immediately, everywhere, as does a password reset.
 */
export const SESSION_TTL_DAYS = 90;
export const RESET_TTL_MINUTES = 60;

export type Role =
  | 'APPLICANT'
  | 'LEARNER'
  | 'LECTURER'
  | 'EVENT_MANAGER'
  | 'ADMIN'
  | 'SUPER_ADMIN'
  | 'OWNER'
  | 'PROFESSIONAL_MEMBER';

export type Status =
  | 'ACTIVE'
  | 'PENDING'
  | 'PENDING_APPROVAL'
  | 'SUSPENDED'
  | 'DISABLED';

/** Roles a visitor may give themselves by registering. */
export const SELF_ASSIGNABLE: Role[] = ['APPLICANT', 'LEARNER'];

export const ALL_ROLES: Role[] = [
  'APPLICANT',
  'LEARNER',
  'LECTURER',
  'EVENT_MANAGER',
  'ADMIN',
  'SUPER_ADMIN',
  'OWNER',
  'PROFESSIONAL_MEMBER',
];

const encoder = new TextEncoder();

function toHex(buffer: ArrayBuffer): string {
  return [...new Uint8Array(buffer)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function fromHex(value: string): Uint8Array {
  const bytes = new Uint8Array(value.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(value.slice(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}

export function randomHex(bytes = 16): string {
  const buffer = new Uint8Array(bytes);
  crypto.getRandomValues(buffer);
  return [...buffer].map((b) => b.toString(16).padStart(2, '0')).join('');
}

export function newId(): string {
  return crypto.randomUUID();
}

/** Opaque token handed to the client. Only its digest is stored. */
export function newToken(): string {
  const buffer = new Uint8Array(32);
  crypto.getRandomValues(buffer);
  return btoa(String.fromCharCode(...buffer))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

export async function sha256(value: string): Promise<string> {
  return toHex(await crypto.subtle.digest('SHA-256', encoder.encode(value)));
}

export async function hashPassword(
  password: string,
  salt: string,
  iterations = PBKDF2_ITERATIONS,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(password),
    'PBKDF2',
    false,
    ['deriveBits'],
  );
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt: fromHex(salt), iterations, hash: 'SHA-256' },
    key,
    256,
  );
  return toHex(bits);
}

/** Comparison whose duration does not depend on where the values diverge. */
export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

export async function verifyPassword(
  password: string,
  salt: string,
  expected: string,
  iterations = PBKDF2_ITERATIONS,
): Promise<boolean> {
  const actual = await hashPassword(password, salt, iterations);
  return timingSafeEqual(actual, expected);
}

/**
 * Server-side password rules. The Flutter client applies the same policy for
 * live feedback, but this is the copy that decides.
 */
export function isPasswordAcceptable(password: string): boolean {
  return (
    typeof password === 'string' &&
    password.length >= 8 &&
    /[A-Z]/.test(password) &&
    /[a-z]/.test(password) &&
    /[0-9]/.test(password) &&
    /[^A-Za-z0-9]/.test(password)
  );
}

/** Readable one-time password for administrator-created accounts. */
export function temporaryPassword(): string {
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const lower = 'abcdefghijkmnopqrstuvwxyz';
  const digits = '23456789';
  const symbols = '!@#$%&*';
  const pools = [upper, lower, digits, symbols];
  const pick = (pool: string) => {
    const buffer = new Uint32Array(1);
    crypto.getRandomValues(buffer);
    return pool[buffer[0] % pool.length];
  };
  const chars = pools.map(pick);
  const all = upper + lower + digits + symbols;
  while (chars.length < 12) chars.push(pick(all));
  for (let i = chars.length - 1; i > 0; i--) {
    const buffer = new Uint32Array(1);
    crypto.getRandomValues(buffer);
    const j = buffer[0] % (i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join('');
}

export function isoIn(ms: number): string {
  return new Date(Date.now() + ms).toISOString();
}

export function isExpired(iso: string): boolean {
  return new Date(iso).getTime() <= Date.now();
}

/**
 * Which areas a role may reach.
 *
 * An owner reaches everything by definition. Everything else is listed rather
 * than inferred, so a new role gains access only where it was written down.
 */
export function canAccessRoute(role: Role, route: string): boolean {
  if (role === 'OWNER') return true;
  if (route.startsWith('/super-admin')) return role === 'SUPER_ADMIN';
  if (route.startsWith('/events/manage')) {
    return role === 'EVENT_MANAGER' || role === 'ADMIN' || role === 'SUPER_ADMIN';
  }
  if (route.startsWith('/admin')) {
    return role === 'ADMIN' || role === 'SUPER_ADMIN' || role === 'EVENT_MANAGER';
  }
  if (route.startsWith('/lecturer')) return role === 'LECTURER' || role === 'SUPER_ADMIN';
  // The learner area is open to every signed-in account. Anyone may enrol on
  // a programme or register for an event and hold full learner rights in it,
  // without giving up the role they already have — a lecturer studying
  // somebody else's course is still a lecturer.
  if (route.startsWith('/learner')) return true;
  return true;
}
