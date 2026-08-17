/**
 * What each public page is, for crawlers.
 *
 * The academy's site is a Flutter application: it paints its pages in the
 * browser. A crawler that fetches a URL gets an empty shell — no title, no
 * description, no artwork — so pasting an event link into WhatsApp produced a
 * blank card, and search engines had nothing to index beyond the loading page.
 *
 * These functions run at the edge, before the shell is served, and put the
 * page's real title, description and image into the HTML that a crawler
 * receives. Visitors are unaffected: they get the same application they always
 * did, with better tags in its head.
 *
 * Google can execute JavaScript and would eventually see some of this anyway.
 * Facebook, LinkedIn, X and WhatsApp never do, which is why this is not
 * optional.
 */

/** Where the API lives. Overridable so a preview build can point elsewhere. */
export const apiOrigin = (env) =>
  (env && env.WEA_API_BASE_URL ? String(env.WEA_API_BASE_URL) : '')
    .replace(/\/$/, '') ||
  'https://wuco-api.dawillcomputers.workers.dev';

export const SITE_NAME = 'WUCO Executive Academy';

const DEFAULT_DESCRIPTION =
  'Executive certificates, masterclasses, short courses and executive short ' +
  'cases for professionals across Africa who carry real decisions.';

/**
 * The fixed pages, and what each one is about.
 *
 * Written here rather than scraped from the application, because a crawler
 * needs an answer before any Dart has run. A page missing from this list still
 * works — it simply gets the academy's own title and description.
 */
export const STATIC_PAGES = {
  '/': {
    title: 'WUCO Executive Academy — Executive programmes for Africa’s leaders',
    description: DEFAULT_DESCRIPTION,
  },
  '/about': {
    title: 'About the Academy',
    description:
      'Who WUCO Executive Academy is, what it teaches, and the standards its ' +
      'certificates are held to.',
  },
  '/programmes': {
    title: 'Executive programmes',
    description:
      'Executive certificates, masterclasses, short courses and executive ' +
      'short cases, developed for working professionals.',
  },
  '/events': {
    title: 'Events and masterclasses',
    description:
      'Summits, masterclasses and briefings from WUCO Executive Academy, ' +
      'in person and online.',
  },
  '/faculty': {
    title: 'Faculty',
    description:
      'The practitioners and academics who teach at WUCO Executive Academy.',
  },
  '/admissions': {
    title: 'Admissions',
    description: 'How to apply to a WUCO Executive Academy programme.',
  },
  '/research': {
    title: 'Research',
    description: 'Research and publications from WUCO Executive Academy.',
  },
  '/professional-network': {
    title: 'Professional network',
    description:
      'The WUCO professional membership network, and what it offers members.',
  },
  '/contact': {
    title: 'Contact the Academy',
    description: 'Reach WUCO Executive Academy about programmes, events or membership.',
  },
  '/apply': {
    title: 'Apply',
    description: 'Begin an application to WUCO Executive Academy.',
  },
  '/privacy': {
    title: 'Privacy notice',
    description:
      'How WUCO Executive Academy collects, uses and protects personal information.',
  },
  '/terms': {
    title: 'Terms and conditions',
    description: 'The terms on which WUCO Executive Academy provides its services.',
  },
};

/**
 * Pages that must never be indexed.
 *
 * Everything behind a sign-in, plus the registration and payment routes: a
 * search result leading to somebody's half-finished registration would be a
 * privacy failure, not a discovery win.
 */
export const NOINDEX_PREFIXES = [
  '/learner',
  '/admin',
  '/super-admin',
  '/profile',
  '/login',
  '/register',
  '/change-password',
  '/reset-password',
  '/forgot-password',
  '/verify-email',
  '/splash',
  '/design-system',
  '/application',
  '/lecturer',
  '/dashboard',
];

export const isNoIndex = (path) =>
  NOINDEX_PREFIXES.some(
    (prefix) => path === prefix || path.startsWith(`${prefix}/`),
  ) ||
  // A specific registration, or the form for one. The event page itself is
  // indexable; the act of registering is not.
  /^\/events\/[^/]+\/register$/.test(path) ||
  path.startsWith('/events/registration/') ||
  /^\/register\//.test(path);

/** Trims a description to something a search result will actually show. */
export const clamp = (text, limit = 300) => {
  const value = String(text ?? '')
    .replace(/\s+/g, ' ')
    .trim();
  return value.length <= limit ? value : `${value.slice(0, limit - 1)}…`;
};

/** An image reference from the API, as an absolute URL. */
export const absoluteImage = (origin, row) => {
  const url = String(row.image_url ?? '').trim();
  if (url.startsWith('http')) return url;
  const key = String(row.image_key ?? '').trim();
  return key === '' ? '' : `${origin}/api/media/${encodeURIComponent(key)}`;
};

/** One API call, returning null rather than throwing: metadata is not worth a 500. */
export async function fetchJson(url) {
  try {
    const response = await fetch(url, {
      headers: { Accept: 'application/json' },
      cf: { cacheTtl: 300, cacheEverything: true },
    });
    if (!response.ok) return null;
    return await response.json();
  } catch {
    return null;
  }
}

/**
 * The title, description and image for a path.
 *
 * Event and programme pages are looked up so a shared link carries the real
 * cover artwork. Anything else falls back to the static table, and anything
 * not in that falls back to the academy itself — a plain card is acceptable;
 * a broken page is not.
 */
export async function metadataFor(path, env) {
  const origin = apiOrigin(env);

  const event = path.match(/^\/events\/([^/]+)$/);
  if (event) {
    const data = await fetchJson(
      `${origin}/api/events/${encodeURIComponent(event[1])}`,
    );
    const row = data && (data.event || data);
    if (row && row.title) {
      return {
        title: `${row.title} — ${SITE_NAME}`,
        description: clamp(row.summary || row.subtitle || DEFAULT_DESCRIPTION),
        image: absoluteImage(origin, row),
        type: 'article',
      };
    }
  }

  const programme = path.match(/^\/programmes\/([^/]+)$/);
  if (programme && programme[1] !== 'area') {
    const data = await fetchJson(
      `${origin}/api/catalogue/programmes/${encodeURIComponent(programme[1])}`,
    );
    const row = data && (data.programme || data);
    if (row && row.title) {
      return {
        title: `${row.title} — ${SITE_NAME}`,
        description: clamp(row.summary || row.subtitle || DEFAULT_DESCRIPTION),
        image: absoluteImage(origin, row),
        type: 'article',
      };
    }
  }

  const page = STATIC_PAGES[path];
  return {
    title: page ? `${page.title}${path === '/' ? '' : ` — ${SITE_NAME}`}` : SITE_NAME,
    description: clamp(page ? page.description : DEFAULT_DESCRIPTION),
    image: '',
    type: 'website',
  };
}
