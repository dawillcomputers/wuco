import { parseJson } from './http';

/**
 * Public catalogue reads.
 *
 * Every query here filters on status = 'PUBLISHED'. Draft and archived content
 * is invisible to the public API entirely — it is not fetched and filtered in
 * the client, so an unpublished programme cannot leak through a crafted request.
 */

const PUBLISHED = 'PUBLISHED';

export interface AreaRow {
  id: string;
  slug: string;
  code: string;
  title: string;
  tagline: string;
  summary: string;
  description: string;
  image_key: string | null;
  image_url: string | null;
  sort_order: number;
}

const shapeArea = (row: AreaRow, programmeCount = 0) => ({
  id: row.id,
  slug: row.slug,
  code: row.code,
  title: row.title,
  tagline: row.tagline,
  summary: row.summary,
  description: row.description,
  image_key: row.image_key,
  image_url: row.image_url,
  programme_count: programmeCount,
});

const shapeProgramme = (row: Record<string, unknown>) => ({
  id: row.id,
  slug: row.slug,
  title: row.title,
  subtitle: row.subtitle,
  summary: row.summary,
  description: row.description,
  image_key: row.image_key,
  image_url: row.image_url,
  level: row.level,
  duration_label: row.duration_label,
  delivery_mode: row.delivery_mode,
  language: row.language,
  certificate_award: row.certificate_award,
  eligibility: row.eligibility,
  who_should_attend: row.who_should_attend,
  learning_outcomes: parseJson<string[]>(row.learning_outcomes, []),
  start_date: row.start_date,
  application_deadline: row.application_deadline,
  tuition_amount: row.tuition_amount,
  tuition_currency: row.tuition_currency,
  tuition_note: row.tuition_note,
  cpd_points: row.cpd_points,
  capacity: row.capacity,
  registration_open: row.registration_open === 1,
  featured: row.featured === 1,
  area_id: row.area_id,
  area_slug: row.area_slug,
  area_title: row.area_title,
  type_id: row.type_id,
  type_slug: row.type_slug,
  type_title: row.type_title,
});

const PROGRAMME_SELECT = `
  SELECT p.*,
         a.slug AS area_slug, a.title AS area_title,
         t.slug AS type_slug, t.title AS type_title
    FROM programmes p
    JOIN programme_areas a ON a.id = p.area_id
    JOIN programme_types t ON t.id = p.type_id
   WHERE p.status = 'PUBLISHED' AND a.status = 'PUBLISHED'`;

/** Areas with a published-programme count, for the catalogue landing page. */
export async function listAreas(db: D1Database) {
  const areas = await db
    .prepare(
      `SELECT * FROM programme_areas WHERE status = ?1 ORDER BY sort_order, title`,
    )
    .bind(PUBLISHED)
    .all<AreaRow>();

  const counts = await db
    .prepare(
      `SELECT area_id, COUNT(*) AS total
         FROM programmes WHERE status = ?1 GROUP BY area_id`,
    )
    .bind(PUBLISHED)
    .all<{ area_id: string; total: number }>();
  const byArea = new Map(counts.results.map((row) => [row.area_id, row.total]));

  return areas.results.map((area) => shapeArea(area, byArea.get(area.id) ?? 0));
}

export async function listTypes(db: D1Database) {
  const rows = await db
    .prepare(
      `SELECT id, slug, title, plural_title, description
         FROM programme_types WHERE status = ?1 ORDER BY sort_order, title`,
    )
    .bind(PUBLISHED)
    .all();
  return rows.results;
}

/** Filtered programme list. All filters are optional and combine with AND. */
export async function listProgrammes(db: D1Database, params: URLSearchParams) {
  const clauses: string[] = [];
  const binds: unknown[] = [];

  const area = params.get('area');
  if (area) {
    binds.push(area);
    clauses.push(`(a.slug = ?${binds.length} OR a.id = ?${binds.length})`);
  }
  const type = params.get('type');
  if (type) {
    binds.push(type);
    clauses.push(`(t.slug = ?${binds.length} OR t.id = ?${binds.length})`);
  }
  const search = params.get('q')?.trim();
  if (search) {
    binds.push(`%${search.toLowerCase()}%`);
    clauses.push(
      `(LOWER(p.title) LIKE ?${binds.length} OR LOWER(p.summary) LIKE ?${binds.length})`,
    );
  }
  if (params.get('featured') === 'true') {
    clauses.push('p.featured = 1');
  }

  const limit = Math.min(Number(params.get('limit') ?? '200') || 200, 500);
  const sql = `${PROGRAMME_SELECT}${
    clauses.length ? ` AND ${clauses.join(' AND ')}` : ''
  } ORDER BY p.featured DESC, a.sort_order, p.sort_order, p.title LIMIT ${limit}`;

  const rows = await db.prepare(sql).bind(...binds).all();
  return rows.results.map(shapeProgramme);
}

/** One area with its published programmes, for an area landing page. */
export async function getArea(db: D1Database, slug: string) {
  const area = await db
    .prepare(
      `SELECT * FROM programme_areas WHERE (slug = ?1 OR id = ?1) AND status = ?2`,
    )
    .bind(slug, PUBLISHED)
    .first<AreaRow>();
  if (!area) return null;

  const rows = await db
    .prepare(
      `${PROGRAMME_SELECT} AND p.area_id = ?1 ORDER BY t.sort_order, p.sort_order, p.title`,
    )
    .bind(area.id)
    .all();

  const programmes = rows.results.map(shapeProgramme);
  return { area: shapeArea(area, programmes.length), programmes };
}

/**
 * A programme with everything its public page needs, in one round trip:
 * modules and lessons, faculty, scheduled sessions and the registration
 * questions that apply to it.
 */
export async function getProgramme(db: D1Database, slug: string) {
  const programme = await db
    .prepare(`${PROGRAMME_SELECT} AND (p.slug = ?1 OR p.id = ?1)`)
    .bind(slug)
    .first();
  if (!programme) return null;

  const id = programme.id as string;

  const [modules, faculty, sessions, fields] = await Promise.all([
    db
      .prepare(
        `SELECT * FROM programme_modules WHERE programme_id = ?1 ORDER BY sort_order, number`,
      )
      .bind(id)
      .all(),
    db
      .prepare(
        `SELECT f.id, f.slug, f.name, f.role_title, f.organisation, f.bio,
                f.expertise, f.image_key, f.image_url, f.linkedin_url, pf.role
           FROM programme_faculty pf
           JOIN faculty f ON f.id = pf.faculty_id
          WHERE pf.programme_id = ?1 AND f.status = 'PUBLISHED'
          ORDER BY pf.sort_order`,
      )
      .bind(id)
      .all(),
    db
      .prepare(
        `SELECT s.*, f.name AS faculty_name
           FROM programme_sessions s
           LEFT JOIN faculty f ON f.id = s.faculty_id
          WHERE s.programme_id = ?1 AND s.status = 'PUBLISHED'
          ORDER BY s.starts_at, s.sort_order`,
      )
      .bind(id)
      .all(),
    db
      .prepare(
        `SELECT * FROM registration_fields
          WHERE programme_id IS NULL OR programme_id = ?1
          ORDER BY sort_order, label`,
      )
      .bind(id)
      .all(),
  ]);

  const moduleIds = modules.results.map((row) => row.id as string);
  let lessons: Record<string, unknown>[] = [];
  if (moduleIds.length > 0) {
    const placeholders = moduleIds.map((_, index) => `?${index + 1}`).join(', ');
    const result = await db
      .prepare(
        `SELECT * FROM programme_lessons WHERE module_id IN (${placeholders}) ORDER BY sort_order, number`,
      )
      .bind(...moduleIds)
      .all();
    lessons = result.results as Record<string, unknown>[];
  }

  return {
    programme: shapeProgramme(programme),
    modules: modules.results.map((module) => ({
      ...module,
      lessons: lessons.filter((lesson) => lesson.module_id === module.id),
    })),
    faculty: faculty.results.map((member) => ({
      ...member,
      expertise: parseJson<string[]>(member.expertise, []),
    })),
    sessions: sessions.results,
    registration_fields: fields.results.map((field) => ({
      ...field,
      options: parseJson<string[]>(field.options, []),
      required: field.required === 1,
    })),
  };
}

export async function listFaculty(db: D1Database) {
  const rows = await db
    .prepare(
      `SELECT id, slug, name, role_title, organisation, bio, expertise,
              image_key, image_url, linkedin_url
         FROM faculty WHERE status = ?1 ORDER BY sort_order, name`,
    )
    .bind(PUBLISHED)
    .all();
  return rows.results.map((member) => ({
    ...member,
    expertise: parseJson<string[]>(member.expertise, []),
  }));
}

/** Active payment methods, with gateway secrets excluded. */
export async function listPaymentMethods(db: D1Database) {
  const rows = await db
    .prepare(
      `SELECT id, slug, kind, title, instructions, bank_name, account_name,
              account_number, sort_code, swift_code, currency, reference_prefix,
              gateway_provider, gateway_checkout_url, gateway_public_key
         FROM payment_methods WHERE is_active = 1 ORDER BY sort_order, title`,
    )
    .all();
  return rows.results;
}

export async function listSettings(db: D1Database) {
  const rows = await db.prepare('SELECT key, value FROM site_settings').all<{
    key: string;
    value: string;
  }>();
  return Object.fromEntries(rows.results.map((row) => [row.key, row.value]));
}
