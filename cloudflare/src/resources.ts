import { newId } from './auth';
import { CONTENT_STATUSES, flag, num, slugify, str } from './http';

/**
 * Declarative description of an admin-managed table.
 *
 * Every catalogue entity is edited through the same create/update/delete/
 * reorder code path, described by one of these. Adding a new managed entity is
 * a matter of adding a spec, not another set of handlers — which is what keeps
 * "manage everything without code changes" true for the operator *and* cheap
 * for the next developer.
 */
export interface FieldSpec {
  column: string;
  kind: 'text' | 'number' | 'flag' | 'json' | 'nullableText';
  required?: boolean;
}

export interface ResourceSpec {
  /** Route segment: /api/admin/<name>. */
  name: string;
  table: string;
  idPrefix: string;
  fields: FieldSpec[];
  /** Column whose value seeds the slug when the client does not supply one. */
  slugFrom?: string;
  hasStatus: boolean;
  hasSortOrder: boolean;
  /** ORDER BY clause for listing. */
  defaultOrder: string;
  /** Query parameters accepted on list, mapped to equality filters. */
  filters?: Record<string, string>;
}

const text = (column: string, required = false): FieldSpec => ({
  column,
  kind: 'text',
  required,
});
const nullable = (column: string): FieldSpec => ({
  column,
  kind: 'nullableText',
});
const number = (column: string): FieldSpec => ({ column, kind: 'number' });
const boolean = (column: string): FieldSpec => ({ column, kind: 'flag' });
const jsonField = (column: string): FieldSpec => ({ column, kind: 'json' });

export const RESOURCES: ResourceSpec[] = [
  {
    name: 'areas',
    table: 'programme_areas',
    idPrefix: 'area',
    slugFrom: 'title',
    hasStatus: true,
    hasSortOrder: true,
    defaultOrder: 'sort_order, title',
    fields: [
      text('title', true),
      text('code'),
      text('tagline'),
      text('summary'),
      text('description'),
      nullable('image_key'),
      nullable('image_url'),
    ],
  },
  {
    name: 'types',
    table: 'programme_types',
    idPrefix: 'type',
    slugFrom: 'title',
    hasStatus: true,
    hasSortOrder: true,
    defaultOrder: 'sort_order, title',
    fields: [text('title', true), text('plural_title'), text('description')],
  },
  {
    name: 'programmes',
    table: 'programmes',
    idPrefix: 'prog',
    slugFrom: 'title',
    hasStatus: true,
    hasSortOrder: true,
    defaultOrder: 'sort_order, title',
    filters: { area_id: 'area_id', type_id: 'type_id', status: 'status' },
    fields: [
      text('title', true),
      text('area_id', true),
      text('type_id', true),
      text('subtitle'),
      text('summary'),
      text('description'),
      nullable('image_key'),
      nullable('image_url'),
      text('level'),
      text('duration_label'),
      text('delivery_mode'),
      text('language'),
      text('certificate_award'),
      text('eligibility'),
      text('who_should_attend'),
      jsonField('learning_outcomes'),
      nullable('start_date'),
      nullable('application_deadline'),
      number('tuition_amount'),
      text('tuition_currency'),
      text('tuition_note'),
      number('cpd_points'),
      number('capacity'),
      boolean('registration_open'),
      boolean('featured'),
    ],
  },
  {
    name: 'modules',
    table: 'programme_modules',
    idPrefix: 'mod',
    hasStatus: false,
    hasSortOrder: true,
    defaultOrder: 'sort_order, number',
    filters: { programme_id: 'programme_id' },
    fields: [
      text('programme_id', true),
      text('title', true),
      number('number'),
      text('summary'),
      text('duration_label'),
    ],
  },
  {
    name: 'lessons',
    table: 'programme_lessons',
    idPrefix: 'les',
    hasStatus: false,
    hasSortOrder: true,
    defaultOrder: 'sort_order, number',
    filters: { module_id: 'module_id' },
    fields: [
      text('module_id', true),
      text('title', true),
      number('number'),
      text('lesson_type'),
      number('duration_minutes'),
      text('summary'),
      text('body'),
      nullable('resource_url'),
      nullable('media_key'),
      boolean('is_preview'),
    ],
  },
  {
    name: 'faculty',
    table: 'faculty',
    idPrefix: 'fac',
    slugFrom: 'name',
    hasStatus: true,
    hasSortOrder: true,
    defaultOrder: 'sort_order, name',
    fields: [
      text('name', true),
      text('role_title'),
      text('organisation'),
      text('bio'),
      jsonField('expertise'),
      nullable('image_key'),
      nullable('image_url'),
      nullable('linkedin_url'),
      nullable('user_id'),
    ],
  },
  {
    name: 'sessions',
    table: 'programme_sessions',
    idPrefix: 'ses',
    hasStatus: true,
    hasSortOrder: true,
    defaultOrder: 'starts_at, sort_order',
    filters: { programme_id: 'programme_id' },
    fields: [
      text('programme_id', true),
      text('title', true),
      text('session_type'),
      nullable('starts_at'),
      nullable('ends_at'),
      text('timezone'),
      text('mode'),
      text('location'),
      nullable('join_url'),
      nullable('faculty_id'),
      text('notes'),
    ],
  },
  {
    name: 'registration-fields',
    table: 'registration_fields',
    idPrefix: 'regfield',
    hasStatus: false,
    hasSortOrder: true,
    defaultOrder: 'sort_order, label',
    filters: { programme_id: 'programme_id' },
    fields: [
      nullable('programme_id'),
      text('field_key', true),
      text('label', true),
      text('field_type'),
      jsonField('options'),
      text('help_text'),
      boolean('required'),
    ],
  },
  {
    name: 'payment-methods',
    table: 'payment_methods',
    idPrefix: 'pay',
    slugFrom: 'title',
    hasStatus: false,
    hasSortOrder: true,
    defaultOrder: 'sort_order, title',
    fields: [
      text('title', true),
      text('kind'),
      text('instructions'),
      text('bank_name'),
      text('account_name'),
      text('account_number'),
      text('sort_code'),
      text('swift_code'),
      text('currency'),
      text('reference_prefix'),
      text('gateway_provider'),
      text('gateway_checkout_url'),
      text('gateway_public_key'),
      boolean('is_active'),
    ],
  },
];

export const resourceByName = (name: string) =>
  RESOURCES.find((resource) => resource.name === name);

/** Converts one inbound value to the type its column stores. */
function coerce(field: FieldSpec, raw: unknown): unknown {
  switch (field.kind) {
    case 'number':
      return num(raw);
    case 'flag':
      return flag(raw);
    case 'json':
      // Accept either an array/object or an already-encoded string, so the
      // client can send whichever is natural.
      return typeof raw === 'string' ? raw : JSON.stringify(raw ?? []);
    case 'nullableText': {
      const value = str(raw);
      return value === '' ? null : value;
    }
    default:
      return str(raw);
  }
}

/** Ensures a slug is unique within its table by appending -2, -3, … */
async function uniqueSlug(
  db: D1Database,
  table: string,
  base: string,
  excludeId?: string,
): Promise<string> {
  const root = base || 'item';
  for (let attempt = 0; attempt < 50; attempt += 1) {
    const candidate = attempt === 0 ? root : `${root}-${attempt + 1}`;
    const clash = await db
      .prepare(`SELECT id FROM ${table} WHERE slug = ?1 AND id <> ?2`)
      .bind(candidate, excludeId ?? '')
      .first<{ id: string }>();
    if (!clash) return candidate;
  }
  return `${root}-${Date.now()}`;
}

export interface MutationResult {
  ok: boolean;
  code?: string;
  message?: string;
  row?: Record<string, unknown>;
}

export async function listResource(
  db: D1Database,
  spec: ResourceSpec,
  params: URLSearchParams,
): Promise<Record<string, unknown>[]> {
  const where: string[] = [];
  const binds: unknown[] = [];
  for (const [param, column] of Object.entries(spec.filters ?? {})) {
    const value = params.get(param);
    if (value === null) continue;
    binds.push(value);
    where.push(`${column} = ?${binds.length}`);
  }
  const sql = `SELECT * FROM ${spec.table}${
    where.length ? ` WHERE ${where.join(' AND ')}` : ''
  } ORDER BY ${spec.defaultOrder}`;
  const result = await db.prepare(sql).bind(...binds).all();
  return result.results as Record<string, unknown>[];
}

export async function createResource(
  db: D1Database,
  spec: ResourceSpec,
  body: Record<string, unknown>,
): Promise<MutationResult> {
  const columns: string[] = ['id'];
  const values: unknown[] = [`${spec.idPrefix}-${newId()}`];

  for (const field of spec.fields) {
    const provided = body[field.column] !== undefined;
    if (field.required && (!provided || str(body[field.column]) === '')) {
      return { ok: false, code: 'INVALID_REQUEST', message: `${field.column} is required.` };
    }
    if (!provided) continue;
    columns.push(field.column);
    values.push(coerce(field, body[field.column]));
  }

  if (spec.slugFrom) {
    const requested = str(body.slug) || slugify(str(body[spec.slugFrom]));
    columns.push('slug');
    values.push(await uniqueSlug(db, spec.table, requested));
  }

  if (spec.hasStatus) {
    const status = str(body.status) || 'DRAFT';
    if (!CONTENT_STATUSES.includes(status as never)) {
      return { ok: false, code: 'INVALID_STATUS' };
    }
    columns.push('status');
    values.push(status);
  }

  if (spec.hasSortOrder) {
    const requested = num(body.sort_order);
    columns.push('sort_order');
    if (requested !== null) {
      values.push(requested);
    } else {
      // Append to the end rather than colliding on 0.
      const last = await db
        .prepare(`SELECT COALESCE(MAX(sort_order), 0) AS max FROM ${spec.table}`)
        .first<{ max: number }>();
      values.push((last?.max ?? 0) + 1);
    }
  }

  const placeholders = columns.map((_, index) => `?${index + 1}`).join(', ');
  await db
    .prepare(
      `INSERT INTO ${spec.table} (${columns.join(', ')}) VALUES (${placeholders})`,
    )
    .bind(...values)
    .run();

  const row = await db
    .prepare(`SELECT * FROM ${spec.table} WHERE id = ?1`)
    .bind(values[0])
    .first();
  return { ok: true, row: row as Record<string, unknown> };
}

export async function updateResource(
  db: D1Database,
  spec: ResourceSpec,
  id: string,
  body: Record<string, unknown>,
): Promise<MutationResult> {
  const existing = await db
    .prepare(`SELECT * FROM ${spec.table} WHERE id = ?1`)
    .bind(id)
    .first();
  if (!existing) return { ok: false, code: 'NOT_FOUND' };

  const sets: string[] = [];
  const binds: unknown[] = [];

  for (const field of spec.fields) {
    if (body[field.column] === undefined) continue;
    binds.push(coerce(field, body[field.column]));
    sets.push(`${field.column} = ?${binds.length}`);
  }

  if (spec.slugFrom && body.slug !== undefined) {
    binds.push(await uniqueSlug(db, spec.table, slugify(str(body.slug)), id));
    sets.push(`slug = ?${binds.length}`);
  }

  if (spec.hasStatus && body.status !== undefined) {
    const status = str(body.status);
    if (!CONTENT_STATUSES.includes(status as never)) {
      return { ok: false, code: 'INVALID_STATUS' };
    }
    binds.push(status);
    sets.push(`status = ?${binds.length}`);
  }

  if (spec.hasSortOrder && body.sort_order !== undefined) {
    binds.push(num(body.sort_order) ?? 0);
    sets.push(`sort_order = ?${binds.length}`);
  }

  if (sets.length === 0) {
    return { ok: true, row: existing as Record<string, unknown> };
  }

  binds.push(id);
  await db
    .prepare(
      `UPDATE ${spec.table} SET ${sets.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = ?${binds.length}`,
    )
    .bind(...binds)
    .run();

  const row = await db
    .prepare(`SELECT * FROM ${spec.table} WHERE id = ?1`)
    .bind(id)
    .first();
  return { ok: true, row: row as Record<string, unknown> };
}

export async function deleteResource(
  db: D1Database,
  spec: ResourceSpec,
  id: string,
): Promise<MutationResult> {
  const existing = await db
    .prepare(`SELECT id FROM ${spec.table} WHERE id = ?1`)
    .bind(id)
    .first();
  if (!existing) return { ok: false, code: 'NOT_FOUND' };
  await db.prepare(`DELETE FROM ${spec.table} WHERE id = ?1`).bind(id).run();
  return { ok: true };
}

/** Applies a new manual order in one batch. */
export async function reorderResource(
  db: D1Database,
  spec: ResourceSpec,
  ids: string[],
): Promise<MutationResult> {
  if (!spec.hasSortOrder) return { ok: false, code: 'NOT_SUPPORTED' };
  const statements = ids.map((id, index) =>
    db
      .prepare(
        `UPDATE ${spec.table} SET sort_order = ?1, updated_at = CURRENT_TIMESTAMP WHERE id = ?2`,
      )
      .bind(index + 1, id),
  );
  if (statements.length > 0) await db.batch(statements);
  return { ok: true };
}
