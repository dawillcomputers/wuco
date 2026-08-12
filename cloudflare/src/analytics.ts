/**
 * Page visitation and campaign analytics.
 *
 * What this deliberately does not do: no cookie, no cross-site identifier, no
 * stored IP address, no fingerprint. A visitor is identified only by a salted
 * digest of their address and user agent *for the current day*, which is enough
 * to count a person once per day and worthless for following anybody across
 * days or sites. That keeps the numbers honest without turning the site into
 * surveillance.
 */

import { newId, sha256 } from './auth';
import { num, str } from './http';

/** Progress events the registration funnel is built from. */
export const FUNNEL_EVENTS = [
  'registration_started',
  'registration_information_submitted',
  'registration_form_completed',
  'payment_started',
  'payment_pending',
  'payment_success',
  'payment_failed',
  'registration_completed',
] as const;

const TRACKABLE = new Set<string>([...FUNNEL_EVENTS, 'event_shared', 'material_downloaded']);

const hostOf = (value: string) => {
  try {
    return new URL(value).hostname.replace(/^www\./, '');
  } catch {
    return '';
  }
};

const deviceOf = (userAgent: string) => {
  const agent = userAgent.toLowerCase();
  if (/ipad|tablet|playbook|silk/.test(agent)) return 'TABLET';
  if (/mobi|iphone|android/.test(agent)) return 'MOBILE';
  return 'DESKTOP';
};

/**
 * A visitor identifier that expires every midnight UTC.
 *
 * The salt is deployment-specific so two WEA environments never produce the
 * same digest, and the day component means yesterday's hash cannot be matched
 * against today's.
 */
async function visitorHash(request: Request, salt: string): Promise<string> {
  const ip = request.headers.get('CF-Connecting-IP') ?? '';
  const agent = request.headers.get('User-Agent') ?? '';
  const day = new Date().toISOString().slice(0, 10);
  const digest = await sha256(`${salt}:${day}:${ip}:${agent}`);
  return digest.slice(0, 32);
}

export interface AnalyticsContext {
  db: D1Database;
  request: Request;
  salt: string;
}

/** Records one page view. Never fails the request it was fired from. */
export async function recordPageView(
  context: AnalyticsContext,
  body: Record<string, unknown>,
): Promise<void> {
  const path = str(body.path);
  if (path === '' || path.length > 300) return;

  const referrer = str(body.referrer).slice(0, 500);
  const country =
    (context.request as Request & { cf?: { country?: string } }).cf?.country ?? '';

  await context.db
    .prepare(
      `INSERT INTO page_views
         (id, path, title, event_id, programme_id, referrer, referrer_host,
          utm_source, utm_medium, utm_campaign, utm_content, share_code,
          country, device, visitor_hash)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15)`,
    )
    .bind(
      newId(),
      path,
      str(body.title).slice(0, 200),
      str(body.event_id) || null,
      str(body.programme_id) || null,
      referrer,
      hostOf(referrer),
      str(body.utm_source).slice(0, 80),
      str(body.utm_medium).slice(0, 80),
      str(body.utm_campaign).slice(0, 120),
      str(body.utm_content).slice(0, 120),
      str(body.share_code).slice(0, 40),
      country,
      deviceOf(context.request.headers.get('User-Agent') ?? ''),
      await visitorHash(context.request, context.salt),
    )
    .run();
}

/** Records one named progress event. Unknown names are ignored. */
export async function recordFunnelEvent(
  context: AnalyticsContext,
  body: Record<string, unknown>,
): Promise<void> {
  const name = str(body.name);
  if (!TRACKABLE.has(name)) return;

  await context.db
    .prepare(
      `INSERT INTO analytics_events
         (id, name, path, event_id, registration_id, utm_source, utm_campaign, visitor_hash)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)`,
    )
    .bind(
      newId(),
      name,
      str(body.path).slice(0, 300),
      str(body.event_id) || null,
      str(body.registration_id) || null,
      str(body.utm_source).slice(0, 80),
      str(body.utm_campaign).slice(0, 120),
      await visitorHash(context.request, context.salt),
    )
    .run();
}

const windowStart = (days: number) =>
  new Date(Date.now() - Math.max(1, Math.min(days, 365)) * 86_400_000)
    .toISOString()
    .replace('T', ' ')
    .slice(0, 19);

/** Everything the Super Admin analytics view shows for the whole site. */
export async function siteAnalytics(db: D1Database, days = 30) {
  const since = windowStart(days);

  const [totals, series, pages, referrers, campaigns, devices, countries] =
    await Promise.all([
      db
        .prepare(
          `SELECT COUNT(*) AS views, COUNT(DISTINCT visitor_hash) AS visitors
             FROM page_views WHERE created_at >= ?1`,
        )
        .bind(since)
        .first<{ views: number; visitors: number }>(),
      db
        .prepare(
          `SELECT substr(created_at, 1, 10) AS day,
                  COUNT(*) AS views,
                  COUNT(DISTINCT visitor_hash) AS visitors
             FROM page_views WHERE created_at >= ?1
            GROUP BY day ORDER BY day`,
        )
        .bind(since)
        .all(),
      db
        .prepare(
          `SELECT path, COUNT(*) AS views, COUNT(DISTINCT visitor_hash) AS visitors
             FROM page_views WHERE created_at >= ?1
            GROUP BY path ORDER BY views DESC LIMIT 25`,
        )
        .bind(since)
        .all(),
      db
        .prepare(
          `SELECT referrer_host AS source, COUNT(*) AS views
             FROM page_views
            WHERE created_at >= ?1 AND referrer_host <> ''
            GROUP BY referrer_host ORDER BY views DESC LIMIT 15`,
        )
        .bind(since)
        .all(),
      db
        .prepare(
          `SELECT utm_source AS source, utm_medium AS medium, utm_campaign AS campaign,
                  COUNT(*) AS views, COUNT(DISTINCT visitor_hash) AS visitors
             FROM page_views
            WHERE created_at >= ?1 AND (utm_source <> '' OR utm_campaign <> '')
            GROUP BY utm_source, utm_medium, utm_campaign
            ORDER BY views DESC LIMIT 20`,
        )
        .bind(since)
        .all(),
      db
        .prepare(
          `SELECT device, COUNT(*) AS views FROM page_views
            WHERE created_at >= ?1 GROUP BY device ORDER BY views DESC`,
        )
        .bind(since)
        .all(),
      db
        .prepare(
          `SELECT country, COUNT(*) AS views FROM page_views
            WHERE created_at >= ?1 AND country <> ''
            GROUP BY country ORDER BY views DESC LIMIT 12`,
        )
        .bind(since)
        .all(),
    ]);

  return {
    days,
    views: totals?.views ?? 0,
    visitors: totals?.visitors ?? 0,
    series: series.results,
    pages: pages.results,
    referrers: referrers.results,
    campaigns: campaigns.results,
    devices: devices.results,
    countries: countries.results,
  };
}

/**
 * The registration funnel for one event, or for every event at once.
 *
 * Landing-page visitors come from `page_views`; the rest come from the
 * registration rows themselves rather than from client-reported events, so the
 * conversion figures survive an ad blocker.
 */
export async function eventFunnel(db: D1Database, eventId?: string | null) {
  const scoped = str(eventId) !== '';
  const bind = scoped ? [eventId] : [];
  const viewFilter = scoped ? 'WHERE event_id = ?1' : "WHERE event_id IS NOT NULL";
  const regFilter = scoped ? 'WHERE event_id = ?1' : '';

  const [visits, registrations, payments] = await Promise.all([
    db
      .prepare(
        `SELECT COUNT(*) AS views, COUNT(DISTINCT visitor_hash) AS visitors
           FROM page_views ${viewFilter}`,
      )
      .bind(...bind)
      .first<{ views: number; visitors: number }>(),
    db
      .prepare(
        `SELECT COUNT(*) AS started,
                SUM(CASE WHEN status <> 'STARTED' THEN 1 ELSE 0 END) AS form_completed,
                SUM(CASE WHEN payment_status = 'PAID' THEN 1 ELSE 0 END) AS paid,
                SUM(CASE WHEN status = 'ABANDONED' THEN 1 ELSE 0 END) AS abandoned,
                SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed
           FROM event_registrations ${regFilter}`,
      )
      .bind(...bind)
      .first<Record<string, number>>(),
    db
      .prepare(
        `SELECT COUNT(*) AS attempts,
                SUM(CASE WHEN p.status = 'PAID' THEN 1 ELSE 0 END) AS successful,
                SUM(CASE WHEN p.status = 'FAILED' THEN 1 ELSE 0 END) AS failed
           FROM event_payments p ${scoped ? 'WHERE p.event_id = ?1' : ''}`,
      )
      .bind(...bind)
      .first<Record<string, number>>(),
  ]);

  const visitors = visits?.visitors ?? 0;
  const completed = registrations?.completed ?? 0;

  return {
    landing_page_views: visits?.views ?? 0,
    landing_page_visitors: visitors,
    started_registration: registrations?.started ?? 0,
    completed_form: registrations?.form_completed ?? 0,
    payment_attempts: payments?.attempts ?? 0,
    successful_payments: payments?.successful ?? 0,
    failed_payments: payments?.failed ?? 0,
    abandoned: registrations?.abandoned ?? 0,
    completed_registrations: completed,
    // Visitors who went all the way. Zero visitors means no rate, not zero.
    conversion_rate: visitors > 0 ? Number(((completed / visitors) * 100).toFixed(1)) : null,
  };
}

/**
 * Follows a campaign short link.
 *
 * Returns the public URL to redirect to, with the campaign parameters attached
 * so the resulting page view is attributed to the channel it came from.
 */
export async function followShareLink(
  db: D1Database,
  code: string,
  siteUrl: string,
): Promise<string | null> {
  const row = await db
    .prepare(
      `SELECT id, target_path, channel, medium, campaign
         FROM share_links WHERE code = ?1 AND status = 'PUBLISHED'`,
    )
    .bind(code)
    .first<{
      id: string;
      target_path: string;
      channel: string;
      medium: string;
      campaign: string;
    }>();
  if (!row) return null;

  await db
    .prepare(
      `UPDATE share_links
          SET clicks = clicks + 1, last_click_at = CURRENT_TIMESTAMP
        WHERE id = ?1`,
    )
    .bind(row.id)
    .run();

  const base = siteUrl.replace(/\/$/, '');
  const target = new URL(
    row.target_path.startsWith('/') ? `${base}${row.target_path}` : `${base}/${row.target_path}`,
  );
  if (row.channel) target.searchParams.set('utm_source', row.channel);
  target.searchParams.set('utm_medium', row.medium || 'social');
  if (row.campaign) target.searchParams.set('utm_campaign', row.campaign);
  target.searchParams.set('wea_ref', code);
  return target.toString();
}

/** Per-link performance for the promotion view. */
export async function shareLinkPerformance(db: D1Database) {
  const rows = await db
    .prepare(
      `SELECT s.*,
              (SELECT COUNT(*) FROM page_views v WHERE v.share_code = s.code) AS landings
         FROM share_links s
        ORDER BY s.clicks DESC, s.created_at DESC
        LIMIT 200`,
    )
    .all();
  return rows.results;
}

/** Retention: analytics rows older than the window are not kept. */
export async function pruneAnalytics(db: D1Database, days = 400): Promise<void> {
  const cutoff = windowStart(num(days) ?? 400);
  await db.batch([
    db.prepare('DELETE FROM page_views WHERE created_at < ?1').bind(cutoff),
    db.prepare('DELETE FROM analytics_events WHERE created_at < ?1').bind(cutoff),
  ]);
}
