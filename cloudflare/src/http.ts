/** Shared request/response helpers used by every route module. */

const CORS_METHODS = 'GET, POST, PUT, PATCH, DELETE, OPTIONS';

/**
 * Every header a client is allowed to send.
 *
 * This list is not documentation — a browser refuses the preflight for any
 * header missing from it, and the request never reaches the Worker. So an
 * omission here does not weaken anything; it silently breaks the feature that
 * sends the header, on web only, with no server-side trace.
 *
 * Keep it in step with what the clients actually send:
 *   X-Filename           image upload  (api_catalogue_repository.uploadImage)
 *   X-Registration-Token guest resume  (api_events_repository)
 *   X-Bootstrap-Token    one-time Super Admin bootstrap
 */
const CORS_HEADERS = [
  'Content-Type',
  'Authorization',
  'X-Bootstrap-Token',
  'X-Filename',
  'X-Registration-Token',
].join(', ');

export function corsHeaders(origin?: string) {
  return {
    'Access-Control-Allow-Origin': origin ?? 'null',
    'Access-Control-Allow-Methods': CORS_METHODS,
    'Access-Control-Allow-Headers': CORS_HEADERS,
    Vary: 'Origin',
  };
}

export const json = (body: unknown, status = 200, origin?: string) =>
  Response.json(body, { status, headers: corsHeaders(origin) });

/** Error shape the Flutter client maps onto its typed failures. */
export const fail = (
  code: string,
  status: number,
  origin?: string,
  message?: string,
) => json({ error: { code, message: message ?? null } }, status, origin);

export async function readJson(request: Request): Promise<Record<string, unknown>> {
  try {
    return ((await request.json()) as Record<string, unknown>) ?? {};
  } catch {
    return {};
  }
}

export const str = (value: unknown) =>
  typeof value === 'string' ? value.trim() : '';

export const num = (value: unknown): number | null => {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
};

/** SQLite has no boolean type; every flag is stored as 0 or 1. */
export const flag = (value: unknown): number =>
  value === true || value === 1 || value === '1' || value === 'true' ? 1 : 0;

/** URL-safe slug derived from a title, used for public catalogue paths. */
export const slugify = (text: string) =>
  text
    .toLowerCase()
    .replaceAll('&', ' and ')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);

/** Parses a JSON column, falling back rather than throwing on bad data. */
export function parseJson<T>(value: unknown, fallback: T): T {
  if (typeof value !== 'string' || value.trim() === '') return fallback;
  try {
    return JSON.parse(value) as T;
  } catch {
    return fallback;
  }
}

export const CONTENT_STATUSES = ['DRAFT', 'PUBLISHED', 'ARCHIVED'] as const;
export type ContentStatus = (typeof CONTENT_STATUSES)[number];
