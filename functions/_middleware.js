import { SITE_NAME, isNoIndex, metadataFor } from './_lib/site.js';

/**
 * Puts real metadata into the page a crawler receives.
 *
 * The application is unchanged by this. It is the same `index.html`, served to
 * the same visitors, with the head rewritten before it leaves the edge — so a
 * link pasted into WhatsApp shows the event's own cover image, and a search
 * engine indexing `/programmes/x` sees that programme rather than a loading
 * screen.
 *
 * Only navigation requests are touched. Assets, the Dart bundle and every API
 * call pass straight through, because rewriting those would cost time and
 * achieve nothing.
 */

const escapeHtml = (value) =>
  String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

/**
 * Rewrites the document head.
 *
 * `HTMLRewriter` is used rather than a string replace because it streams: the
 * shell is sent on as it arrives, so the crawler — and the visitor — waits for
 * nothing that a regex over the whole body would have cost them.
 *
 * One handler for both elements: the title is replaced in place, and the rest
 * of the tags are appended once the head is otherwise complete.
 */
class HeadRewriter {
  constructor(title, tags) {
    this.title = title;
    this.tags = tags;
  }

  element(element) {
    if (element.tagName === 'title') {
      element.setInnerContent(this.title);
    } else if (element.tagName === 'head') {
      element.append(this.tags, { html: true });
    }
  }
}

/**
 * Strips the shell's own description and preview tags.
 *
 * `web/index.html` carries a set describing the academy generally. Left in
 * place they would sit alongside the page-specific ones, and a crawler
 * choosing between two `og:title` tags is a coin toss nobody should be
 * offering it.
 */
class MetaStripper {
  element(element) {
    const name = element.getAttribute('name');
    const property = element.getAttribute('property');
    if (
      name === 'description' ||
      name === 'robots' ||
      (name && name.startsWith('twitter:')) ||
      (property && property.startsWith('og:'))
    ) {
      element.remove();
    }
  }
}

function headTags(meta, canonical, noindex) {
  const title = escapeHtml(meta.title);
  const description = escapeHtml(meta.description);
  const image = escapeHtml(meta.image);
  const url = escapeHtml(canonical);

  return `
<meta name="description" content="${description}">
<link rel="canonical" href="${url}">
${noindex ? '<meta name="robots" content="noindex, nofollow">' : '<meta name="robots" content="index, follow, max-image-preview:large">'}
<meta property="og:site_name" content="${escapeHtml(SITE_NAME)}">
<meta property="og:type" content="${escapeHtml(meta.type)}">
<meta property="og:title" content="${title}">
<meta property="og:description" content="${description}">
<meta property="og:url" content="${url}">
${image ? `<meta property="og:image" content="${image}">
<meta property="og:image:alt" content="${title}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">` : ''}
<meta name="twitter:card" content="${image ? 'summary_large_image' : 'summary'}">
<meta name="twitter:title" content="${title}">
<meta name="twitter:description" content="${description}">
${image ? `<meta name="twitter:image" content="${image}">` : ''}
`;
}

export async function onRequest(context) {
  const { request, next, env } = context;
  const url = new URL(request.url);

  // Anything that is not a page: assets, the bundle, the manifest. Passed
  // through untouched.
  const accepts = request.headers.get('Accept') ?? '';
  if (
    request.method !== 'GET' ||
    !accepts.includes('text/html') ||
    /\.[a-z0-9]+$/i.test(url.pathname)
  ) {
    return next();
  }

  const response = await next();
  const type = response.headers.get('Content-Type') ?? '';
  if (!type.includes('text/html')) return response;

  const path = url.pathname.replace(/\/+$/, '') || '/';
  const noindex = isNoIndex(path);
  const meta = await metadataFor(path, env);
  const canonical = `${url.origin}${path === '/' ? '/' : path}`;

  const rewriter = new HeadRewriter(
    escapeHtml(meta.title),
    headTags(meta, canonical, noindex),
  );
  const rewritten = new HTMLRewriter()
    .on('meta', new MetaStripper())
    .on('title', rewriter)
    .on('head', rewriter)
    .transform(response);

  const headers = new Headers(rewritten.headers);
  // Short, because an administrator who edits an event expects the card to
  // follow within minutes rather than after a purge.
  headers.set('Cache-Control', 'public, max-age=0, s-maxage=300');
  if (noindex) headers.set('X-Robots-Tag', 'noindex, nofollow');

  return new Response(rewritten.body, {
    status: rewritten.status,
    statusText: rewritten.statusText,
    headers,
  });
}
