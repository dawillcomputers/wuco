/**
 * Social preview cards for shared links.
 *
 * The public site is a Flutter application: it paints its pages in the browser,
 * so a crawler that fetches the URL sees an empty shell. Pasting an event link
 * into LinkedIn or Facebook would give a blank card.
 *
 * This module solves that the way it is normally solved — a small server-
 * rendered page carrying the Open Graph tags, which sends people straight on to
 * the real page and leaves the crawler with the title, description and artwork
 * it came for. The share URL is the one the academy circulates; the application
 * URL is what visitors end up on.
 */

import { str } from './http';

const escapeHtml = (value: string) =>
  value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

interface Card {
  title: string;
  description: string;
  image: string;
  url: string;
  type: string;
  siteName: string;
}

function cardHtml(card: Card): string {
  const title = escapeHtml(card.title);
  const description = escapeHtml(card.description);
  const url = escapeHtml(card.url);
  const image = escapeHtml(card.image);

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<meta name="description" content="${description}">
<link rel="canonical" href="${url}">

<meta property="og:site_name" content="${escapeHtml(card.siteName)}">
<meta property="og:type" content="${escapeHtml(card.type)}">
<meta property="og:title" content="${title}">
<meta property="og:description" content="${description}">
<meta property="og:url" content="${url}">
${image ? `<meta property="og:image" content="${image}">
<meta property="og:image:alt" content="${title}">` : ''}

<meta name="twitter:card" content="${image ? 'summary_large_image' : 'summary'}">
<meta name="twitter:title" content="${title}">
<meta name="twitter:description" content="${description}">
${image ? `<meta name="twitter:image" content="${image}">` : ''}

<meta http-equiv="refresh" content="0; url=${url}">
</head>
<body>
<p>Opening <a href="${url}">${title}</a>…</p>
<script>location.replace(${JSON.stringify(card.url)});</script>
</body>
</html>`;
}

const html = (body: string, status = 200) =>
  new Response(body, {
    status,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      // Crawlers re-fetch often; a short cache keeps the card fresh after an
      // edit without hammering the database.
      'Cache-Control': 'public, max-age=300',
    },
  });

const absoluteImage = (
  apiOrigin: string,
  imageKey: unknown,
  imageUrl: unknown,
): string => {
  const url = str(imageUrl);
  if (url.startsWith('http')) return url;
  const key = str(imageKey);
  return key === '' ? '' : `${apiOrigin}/api/media/${encodeURIComponent(key)}`;
};

/**
 * Renders the card for one shared thing.
 *
 * Only published rows are looked up, so a draft event cannot be revealed by
 * sharing its link — the response is the same "not found" a stranger would get.
 */
export async function shareCard(
  db: D1Database,
  kind: string,
  slug: string,
  siteUrl: string,
  apiOrigin: string,
  query: URLSearchParams,
): Promise<Response> {
  const site = siteUrl.replace(/\/$/, '');
  // Campaign parameters ride through to the application, so a share that came
  // from LinkedIn is still attributed to LinkedIn after the redirect.
  const carried = new URLSearchParams();
  for (const key of ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'wea_ref']) {
    const value = str(query.get(key));
    if (value !== '') carried.set(key, value);
  }
  const suffix = carried.toString() === '' ? '' : `?${carried.toString()}`;

  if (kind === 'event') {
    const row = await db
      .prepare(
        `SELECT title, subtitle, summary, slug, image_key, image_url, venue,
                starts_at, fee_amount, fee_currency
           FROM events
          WHERE slug = ?1
            AND status IN ('PUBLISHED', 'REGISTRATION_CLOSED', 'COMPLETED')`,
      )
      .bind(slug)
      .first<Record<string, unknown>>();
    if (!row) return html('<h1>Not found</h1>', 404);

    const when = str(row.starts_at).slice(0, 10);
    const fee = Number(row.fee_amount ?? 0);
    const details = [
      when,
      str(row.venue),
      fee > 0 ? `${str(row.fee_currency)} ${fee.toLocaleString('en-US')}` : 'Free to attend',
    ].filter((part) => part !== '');

    return html(
      cardHtml({
        title: str(row.title),
        description:
          str(row.summary) || str(row.subtitle) || details.join(' · '),
        image: absoluteImage(apiOrigin, row.image_key, row.image_url),
        url: `${site}/events/${str(row.slug)}${suffix}`,
        type: 'website',
        siteName: 'WUCO Executive Academy',
      }),
    );
  }

  if (kind === 'programme') {
    const row = await db
      .prepare(
        `SELECT title, subtitle, summary, slug, image_key, image_url
           FROM programmes WHERE slug = ?1 AND status = 'PUBLISHED'`,
      )
      .bind(slug)
      .first<Record<string, unknown>>();
    if (!row) return html('<h1>Not found</h1>', 404);

    return html(
      cardHtml({
        title: str(row.title),
        description: str(row.summary) || str(row.subtitle),
        image: absoluteImage(apiOrigin, row.image_key, row.image_url),
        url: `${site}/programmes/${str(row.slug)}${suffix}`,
        type: 'website',
        siteName: 'WUCO Executive Academy',
      }),
    );
  }

  return html('<h1>Not found</h1>', 404);
}
