/**
 * What each role is allowed to do.
 *
 * The point of this module is that authorisation is asked as a question about
 * a *permission*, never about a role. `can(actor, 'event.publish')` survives a
 * new role being added; `role === 'SUPER_ADMIN'` scattered through the code
 * does not, and is how a new role silently gains — or loses — access it should
 * not have.
 *
 * Adding a role is a row in ROLE_PERMISSIONS. Adding a capability is one
 * permission name used at the one place that guards it.
 */

export type Role =
  | 'APPLICANT'
  | 'LEARNER'
  | 'LECTURER'
  | 'EVENT_MANAGER'
  | 'ADMIN'
  | 'SUPER_ADMIN'
  | 'OWNER'
  | 'PROFESSIONAL_MEMBER';

export const ALL_ROLES: Role[] = [
  'APPLICANT',
  'LEARNER',
  'LECTURER',
  'EVENT_MANAGER',
  'ADMIN',
  'SUPER_ADMIN',
  'OWNER',
  'PROFESSIONAL_MEMBER',
];

/** Roles a visitor may give themselves by registering. */
export const SELF_ASSIGNABLE: Role[] = ['APPLICANT', 'LEARNER'];

/**
 * Roles that carry administrative authority, and may therefore only be
 * granted by an owner.
 */
export const PRIVILEGED_ROLES: Role[] = [
  'EVENT_MANAGER',
  'ADMIN',
  'SUPER_ADMIN',
  'OWNER',
  'LECTURER',
];

export type Permission =
  // Platform
  | 'platform.settings'
  | 'platform.integrations'
  | 'platform.analytics'
  // People and roles
  | 'user.read'
  | 'user.write'
  | 'role.grant'
  // Catalogue
  | 'catalogue.read'
  | 'catalogue.write'
  // Programmes and applications
  | 'programme.registration.read'
  | 'programme.registration.review'
  // Events
  | 'event.read'
  | 'event.create'
  | 'event.edit'
  | 'event.publish'
  | 'event.materials'
  | 'event.sessions'
  | 'event.announcements'
  | 'event.registrant.read'
  | 'event.registrant.manage'
  | 'event.analytics'
  // Money
  | 'payment.configure'
  | 'payment.reconcile'
  // Enquiries
  | 'enquiry.read'
  | 'enquiry.reply'
  // Video
  //
  // `video.upload` is the right to add a video at all; `video.manage.all` is
  // the right to touch somebody else's. A lecturer holds the first and not
  // the second, which is what "own videos only" means in practice — the rule
  // is enforced by the handler asking these two questions, not by the client
  // hiding a button.
  | 'video.upload'
  | 'video.manage.all'
  // Live events
  //
  // Creating an event and putting it on air are deliberately separate
  // permissions. Scheduling something is reversible; transitioning a
  // broadcast to live is what an audience sees, and is the action worth
  // holding more narrowly.
  | 'live.create'
  | 'live.control';

/** Everything an event manager may do on an event assigned to them. */
const EVENT_MANAGER_PERMISSIONS: Permission[] = [
  'event.read',
  'event.edit',
  'event.materials',
  'event.sessions',
  'event.announcements',
  'event.registrant.read',
  'event.registrant.manage',
  'event.analytics',
];

const ADMIN_PERMISSIONS: Permission[] = [
  'platform.analytics',
  'user.read',
  'catalogue.read',
  'catalogue.write',
  'programme.registration.read',
  'programme.registration.review',
  ...EVENT_MANAGER_PERMISSIONS,
  'event.create',
  'event.publish',
  'enquiry.read',
  'enquiry.reply',
  'video.upload',
  'video.manage.all',
  'live.create',
  'live.control',
];

const SUPER_ADMIN_PERMISSIONS: Permission[] = [
  ...ADMIN_PERMISSIONS,
  'platform.settings',
  'user.write',
  'payment.configure',
  'payment.reconcile',
];

/**
 * The owner has everything, and is the only role that may grant privileged
 * roles — including another owner. That is the one authority a Super Admin
 * does not have, and the reason the role exists.
 */
const OWNER_PERMISSIONS: Permission[] = [
  ...SUPER_ADMIN_PERMISSIONS,
  'platform.integrations',
  'role.grant',
];

const ROLE_PERMISSIONS: Record<Role, Permission[]> = {
  OWNER: OWNER_PERMISSIONS,
  SUPER_ADMIN: SUPER_ADMIN_PERMISSIONS,
  ADMIN: ADMIN_PERMISSIONS,
  // An event manager's reach is narrowed further by assignment: the role
  // grants the verbs, `event_managers` decides which events they apply to.
  EVENT_MANAGER: [...EVENT_MANAGER_PERMISSIONS, 'catalogue.read'],
  // A lecturer may add teaching video and manage what they added. Not
  // anybody else's, and nothing to do with live broadcasts.
  LECTURER: ['catalogue.read', 'event.read', 'video.upload'],
  LEARNER: ['catalogue.read', 'event.read'],
  APPLICANT: ['catalogue.read', 'event.read'],
  PROFESSIONAL_MEMBER: ['catalogue.read', 'event.read'],
};

export interface Actor {
  id: string;
  role: Role;
}

/** Whether this role carries a permission at all, before scoping. */
export function can(actor: Actor | null, permission: Permission): boolean {
  if (!actor) return false;
  return (ROLE_PERMISSIONS[actor.role] ?? []).includes(permission);
}

/** Every permission a role holds. Sent to the client to shape its interface. */
export function permissionsFor(role: Role): Permission[] {
  return [...(ROLE_PERMISSIONS[role] ?? [])];
}

/**
 * Whether the actor may act on *this* event.
 *
 * An owner, super admin or administrator may act on any event. An event
 * manager may act only on events assigned to them — the role alone grants
 * nothing, which is what stops a new event manager inheriting the whole
 * calendar.
 */
export async function canManageEvent(
  db: D1Database,
  actor: Actor | null,
  eventId: string,
  permission: Permission,
): Promise<boolean> {
  if (!can(actor, permission)) return false;
  if (actor!.role !== 'EVENT_MANAGER') return true;

  const assignment = await db
    .prepare(
      'SELECT granted_permissions FROM event_managers WHERE user_id = ?1 AND event_id = ?2',
    )
    .bind(actor!.id, eventId)
    .first<{ granted_permissions: string }>();
  if (!assignment) return false;

  // Publishing is withheld unless it has been granted on this event
  // specifically, so an assignment is not implicitly a licence to put an
  // event in front of the public.
  if (permission === 'event.publish' || permission === 'event.create') {
    try {
      const granted = JSON.parse(assignment.granted_permissions) as string[];
      return Array.isArray(granted) && granted.includes(permission);
    } catch {
      return false;
    }
  }
  return true;
}

/** The events an event manager is responsible for. Empty means none. */
export async function assignedEventIds(
  db: D1Database,
  actor: Actor,
): Promise<string[]> {
  const rows = await db
    .prepare('SELECT event_id FROM event_managers WHERE user_id = ?1')
    .bind(actor.id)
    .all<{ event_id: string }>();
  return rows.results.map((row) => row.event_id);
}

/**
 * Whether `actor` may set somebody's role to `role`.
 *
 * Only an owner may hand out administrative authority. Everything else is
 * refused rather than quietly downgraded, so a mistake is visible.
 */
export function canGrantRole(actor: Actor | null, role: Role): boolean {
  if (!actor) return false;
  if (PRIVILEGED_ROLES.includes(role) || actor.role === 'OWNER') {
    return can(actor, 'role.grant');
  }
  return can(actor, 'user.write');
}
