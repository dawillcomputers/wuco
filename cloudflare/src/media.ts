import { newId } from './auth';
import { corsHeaders, json, fail, str } from './http';

/**
 * Image upload and delivery.
 *
 * Binaries live in R2; `media_assets` is the catalogue of them. Files are served
 * back through this Worker rather than from a public bucket domain, so the
 * bucket stays private and no extra DNS or public-access configuration is
 * needed to go live.
 */

const MAX_BYTES = 10 * 1024 * 1024;

const ALLOWED = new Map<string, string>([
  ['image/jpeg', 'jpg'],
  ['image/png', 'png'],
  ['image/webp', 'webp'],
  ['image/gif', 'gif'],
  ['image/svg+xml', 'svg'],
  ['application/pdf', 'pdf'],
]);

export interface MediaEnv {
  WEA_DB: D1Database;
  WEA_MEDIA: R2Bucket;
}

/**
 * Accepts a multipart form upload (field `file`) or a raw body with
 * Content-Type set. Multipart is what browsers send; the raw path keeps
 * scripted uploads simple.
 */
export async function uploadMedia(
  request: Request,
  env: MediaEnv,
  actorId: string,
  origin?: string,
): Promise<Response> {
  const contentType = request.headers.get('Content-Type') ?? '';
  let bytes: ArrayBuffer;
  let filename = '';
  let mime = '';
  let altText = '';

  if (contentType.includes('multipart/form-data')) {
    const form = await request.formData();
    const file = form.get('file');
    if (!(file instanceof File)) {
      return fail('INVALID_REQUEST', 400, origin, 'No file was supplied.');
    }
    bytes = await file.arrayBuffer();
    filename = file.name;
    mime = file.type;
    altText = str(form.get('alt_text'));
  } else {
    bytes = await request.arrayBuffer();
    mime = contentType.split(';')[0].trim();
    filename = str(request.headers.get('X-Filename')) || 'upload';
  }

  if (bytes.byteLength === 0) {
    return fail('INVALID_REQUEST', 400, origin, 'The file was empty.');
  }
  if (bytes.byteLength > MAX_BYTES) {
    return fail('FILE_TOO_LARGE', 413, origin, 'Maximum upload size is 10 MB.');
  }
  const extension = ALLOWED.get(mime);
  if (!extension) {
    return fail(
      'UNSUPPORTED_TYPE',
      415,
      origin,
      'Upload a JPEG, PNG, WebP, GIF, SVG or PDF file.',
    );
  }

  // Content-addressed enough to avoid collisions, opaque enough not to leak
  // the original filename into public URLs.
  const key = `${new Date().toISOString().slice(0, 7)}/${newId()}.${extension}`;

  await env.WEA_MEDIA.put(key, bytes, {
    httpMetadata: {
      contentType: mime,
      // Keys are unique per upload, so a long immutable cache is safe: a
      // replaced image gets a new key rather than a new version of this one.
      cacheControl: 'public, max-age=31536000, immutable',
    },
  });

  const id = `media-${newId()}`;
  await env.WEA_DB.prepare(
    `INSERT INTO media_assets (id, key, filename, content_type, size_bytes, alt_text, uploaded_by)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)`,
  )
    .bind(id, key, filename, mime, bytes.byteLength, altText, actorId)
    .run();

  return json(
    {
      asset: {
        id,
        key,
        filename,
        content_type: mime,
        size_bytes: bytes.byteLength,
        alt_text: altText,
        url: `/api/media/${key}`,
      },
    },
    201,
    origin,
  );
}

export async function listMedia(env: MediaEnv, origin?: string) {
  const rows = await env.WEA_DB.prepare(
    `SELECT id, key, filename, content_type, size_bytes, alt_text, created_at
       FROM media_assets ORDER BY created_at DESC LIMIT 200`,
  ).all();
  return json(
    {
      assets: rows.results.map((row) => ({ ...row, url: `/api/media/${row.key}` })),
    },
    200,
    origin,
  );
}

export async function deleteMedia(env: MediaEnv, key: string, origin?: string) {
  await env.WEA_MEDIA.delete(key);
  await env.WEA_DB.prepare('DELETE FROM media_assets WHERE key = ?1')
    .bind(key)
    .run();
  return json({ ok: true }, 200, origin);
}

/**
 * Serves an asset. Public and unauthenticated by design — these are programme
 * images on a public catalogue — but scoped strictly to keys the bucket holds.
 */
export async function serveMedia(
  env: MediaEnv,
  key: string,
  request: Request,
): Promise<Response> {
  const object = await env.WEA_MEDIA.get(key);
  if (!object) return new Response('Not found', { status: 404 });

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('etag', object.httpEtag);
  headers.set('Cache-Control', 'public, max-age=31536000, immutable');
  headers.set('Access-Control-Allow-Origin', '*');

  // Honour conditional requests so repeat views cost nothing.
  if (request.headers.get('If-None-Match') === object.httpEtag) {
    return new Response(null, { status: 304, headers });
  }
  return new Response(object.body, { headers });
}

export const mediaCors = corsHeaders;
