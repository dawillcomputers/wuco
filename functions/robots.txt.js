import { NOINDEX_PREFIXES } from './_lib/site.js';

/**
 * What a crawler may look at.
 *
 * Served from a function rather than a static file so the disallow list and
 * the application's own "never index this" list are the same list. Two copies
 * would drift, and the copy that drifts is the one that ends up putting
 * somebody's registration into a search result.
 */
export function onRequest({ request }) {
  const origin = new URL(request.url).origin;

  const body = [
    'User-agent: *',
    ...NOINDEX_PREFIXES.map((prefix) => `Disallow: ${prefix}`),
    // The act of registering, as against the event being registered for.
    'Disallow: /events/registration/',
    'Disallow: /*/register$',
    '',
    `Sitemap: ${origin}/sitemap.xml`,
    '',
  ].join('\n');

  return new Response(body, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
}
