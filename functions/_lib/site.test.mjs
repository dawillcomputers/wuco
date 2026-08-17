/**
 * Checks the edge metadata rules without a Worker runtime.
 *
 * These are the properties that must hold whatever the site contains: that no
 * signed-in area is ever advertised to a crawler, that a shared link carries
 * the right artwork, and that a page missing from the table still gets a
 * usable card rather than nothing. Run with:
 *
 *   node functions/_lib/site.test.mjs
 */

import {
  STATIC_PAGES,
  absoluteImage,
  apiOrigin,
  clamp,
  isNoIndex,
  metadataFor,
} from './site.js';

let failures = 0;

function check(name, condition, detail = '') {
  const mark = condition ? 'PASS' : 'FAIL';
  if (!condition) failures += 1;
  console.log(`  [${mark}] ${name}${detail && !condition ? ` — ${detail}` : ''}`);
}

const section = (title) => console.log(`\n${title}`);

section('Private areas are never advertised');

for (const path of [
  '/learner',
  '/learner/programmes/x',
  '/admin',
  '/super-admin/cms',
  '/profile',
  '/login',
  '/change-password',
  '/reset-password',
]) {
  check(`${path} is refused to crawlers`, isNoIndex(path));
}

check(
  'a specific registration is not indexable',
  isNoIndex('/events/registration/WEA-EVT-2026-00005'),
  'a search result leading to somebody’s registration is a privacy failure',
);
check(
  'the act of registering is not indexable',
  isNoIndex('/events/some-summit/register') && isNoIndex('/register/a-programme'),
);

section('Public pages are');

for (const path of ['/', '/about', '/programmes', '/events', '/privacy', '/terms']) {
  check(`${path} is indexable`, !isNoIndex(path));
}
check(
  'an event page itself is indexable',
  !isNoIndex('/events/wuco-executive-leadership-masterclass-series'),
  'the event is public even though registering for it is not',
);
check('a programme page is indexable', !isNoIndex('/programmes/some-programme'));

section('Every listed page says something');

for (const [path, page] of Object.entries(STATIC_PAGES)) {
  check(
    `${path} has a title and a description`,
    page.title.length > 0 && page.description.length > 20,
  );
}

section('Descriptions are usable');

check('short text is left alone', clamp('Executive programmes') === 'Executive programmes');
check(
  'long text is trimmed',
  clamp('x'.repeat(400)).length <= 300,
  `${clamp('x'.repeat(400)).length}`,
);
check(
  'whitespace is collapsed',
  clamp('a\n\n  b\t c') === 'a b c',
  'a description full of newlines renders badly in a search result',
);
check('nothing becomes empty, not "undefined"', clamp(undefined) === '');

section('Artwork resolves to something a crawler can fetch');

const origin = 'https://api.example';
check(
  'an absolute URL is left alone',
  absoluteImage(origin, { image_url: 'https://images.example/a.png' }) ===
    'https://images.example/a.png',
);
check(
  'a stored key becomes an absolute URL',
  absoluteImage(origin, { image_key: '2026-08/a b.png' }) ===
    `${origin}/api/media/2026-08%2Fa%20b.png`,
  'a relative path in og:image is ignored by every crawler',
);
check('no artwork is empty, not a broken URL', absoluteImage(origin, {}) === '');

section('Configuration');

check(
  'the API origin has no trailing slash',
  apiOrigin({ WEA_API_BASE_URL: 'https://api.example/' }) === 'https://api.example',
  'a double slash would 404 every lookup',
);
check(
  'an unset origin still resolves',
  apiOrigin({}).startsWith('https://'),
  'metadata must not depend on a variable somebody forgot to set',
);

section('An unknown page still gets a card');

const unknown = await metadataFor('/something-nobody-listed', {});
check('it has a title', unknown.title.length > 0);
check('it has a description', unknown.description.length > 20);
check('and it is a website, not an article', unknown.type === 'website');

console.log(
  failures === 0
    ? '\nAll checks passed.'
    : `\n${failures} check${failures === 1 ? '' : 's'} failed.`,
);
if (failures > 0) process.exit(1);
