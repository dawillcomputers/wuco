import { STATIC_PAGES, apiOrigin, fetchJson } from './_lib/site.js';

/**
 * Every public page, for search engines.
 *
 * Built from the database each time rather than written by hand, because the
 * academy publishes events and programmes without a release: a sitemap that
 * had to be edited alongside them would be wrong within a week, and a wrong
 * sitemap is worse than none — it teaches a crawler that this site lists
 * pages which do not exist.
 *
 * Only published rows appear. A draft event is not merely unlisted here; it is
 * not returned by the API at all.
 */

const escapeXml = (value) =>
  String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');

/** A `<url>` entry. `lastmod` is omitted rather than invented. */
function urlEntry({ loc, lastmod, changefreq, priority }) {
  return [
    '  <url>',
    `    <loc>${escapeXml(loc)}</loc>`,
    lastmod ? `    <lastmod>${escapeXml(lastmod)}</lastmod>` : null,
    changefreq ? `    <changefreq>${changefreq}</changefreq>` : null,
    priority ? `    <priority>${priority}</priority>` : null,
    '  </url>',
  ]
    .filter(Boolean)
    .join('\n');
}

/** A timestamp as the date part of an ISO string, or null if unparseable. */
const day = (value) => {
  const parsed = Date.parse(String(value ?? '').replace(' ', 'T'));
  return Number.isFinite(parsed)
    ? new Date(parsed).toISOString().slice(0, 10)
    : null;
};

export async function onRequest({ request, env }) {
  const origin = new URL(request.url).origin;
  const api = apiOrigin(env);

  const entries = Object.keys(STATIC_PAGES).map((path) =>
    urlEntry({
      loc: `${origin}${path}`,
      changefreq: path === '/' ? 'weekly' : 'monthly',
      priority: path === '/' ? '1.0' : '0.6',
    }),
  );

  // Published events and programmes. A failed lookup drops that section rather
  // than the whole sitemap: half a sitemap is still useful, and an error page
  // where XML belongs is not.
  const events = await fetchJson(`${api}/api/events?limit=100`);
  for (const event of (events && events.events) || []) {
    if (!event.slug) continue;
    entries.push(
      urlEntry({
        loc: `${origin}/events/${event.slug}`,
        lastmod: day(event.updated_at) ?? day(event.starts_at),
        changefreq: 'weekly',
        priority: '0.8',
      }),
    );
  }

  const programmes = await fetchJson(`${api}/api/catalogue/programmes?limit=200`);
  for (const programme of (programmes && programmes.programmes) || []) {
    if (!programme.slug) continue;
    entries.push(
      urlEntry({
        loc: `${origin}/programmes/${programme.slug}`,
        lastmod: day(programme.updated_at),
        changefreq: 'monthly',
        priority: '0.8',
      }),
    );
  }

  const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${entries.join('\n')}
</urlset>
`;

  return new Response(body, {
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
      'Cache-Control': 'public, max-age=1800',
    },
  });
}
