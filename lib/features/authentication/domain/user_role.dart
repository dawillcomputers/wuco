/// Roles recognised by WEA.
///
/// Privileged roles are never self-assigned during registration; see
/// [UserRole.selfAssignable]. Granting one is an owner action, enforced by the
/// API — nothing here is a security control, only what the interface offers.
enum UserRole {
  applicant('APPLICANT', 'Applicant', '/application'),
  learner('LEARNER', 'Learner', '/learner'),
  lecturer('LECTURER', 'Lecturer', '/lecturer'),
  eventManager('EVENT_MANAGER', 'Event Manager', '/super-admin/content'),
  admin('ADMIN', 'Administrator', '/admin'),
  superAdmin('SUPER_ADMIN', 'Super Administrator', '/super-admin'),
  owner('OWNER', 'Owner', '/super-admin'),
  professionalMember(
    'PROFESSIONAL_MEMBER',
    'Professional Member',
    '/professional-network/member',
  );

  const UserRole(this.wireName, this.label, this.landingRoute);

  /// Stable identifier used by the backend. Never persist [name] instead: the
  /// Dart identifier is camelCase and would drift from the database.
  final String wireName;

  final String label;

  /// Where a signed-in user of this role belongs after authenticating.
  final String landingRoute;

  static UserRole fromWireName(String? value) => UserRole.values.firstWhere(
    (role) => role.wireName == value,
    orElse: () => UserRole.applicant,
  );

  /// The only roles a visitor may obtain by registering themselves.
  static const selfAssignable = {UserRole.applicant, UserRole.learner};

  /// Roles that carry administrative authority. Only an owner may grant one.
  static const privileged = {
    UserRole.lecturer,
    UserRole.eventManager,
    UserRole.admin,
    UserRole.superAdmin,
    UserRole.owner,
  };

  bool get isPrivileged => privileged.contains(this);

  /// Whether this role may administer users. Administrator does *not* imply
  /// Super Administrator, and neither implies Owner.
  bool get canManageUsers =>
      this == UserRole.superAdmin || this == UserRole.owner;

  /// Whether this role may grant privileged roles. The owner alone can.
  bool get canGrantRoles => this == UserRole.owner;

  /// Whether this role administers events.
  bool get managesEvents =>
      this == UserRole.eventManager ||
      this == UserRole.admin ||
      this == UserRole.superAdmin ||
      this == UserRole.owner;

  /// Routes this role is permitted to open.
  bool canAccess(String route) {
    // The owner reaches everything; that is what the role is for.
    if (this == UserRole.owner) return true;
    if (route.startsWith('/super-admin/content')) {
      return this == UserRole.superAdmin || this == UserRole.eventManager;
    }
    if (route.startsWith('/super-admin')) {
      return this == UserRole.superAdmin;
    }
    if (route.startsWith('/admin')) {
      return this == UserRole.admin || this == UserRole.superAdmin;
    }
    if (route.startsWith('/lecturer')) {
      return this == UserRole.lecturer || this == UserRole.superAdmin;
    }
    // Open to every signed-in account. Roles are additive: anyone may enrol
    // on a programme or register for an event and hold full learner rights
    // in it while keeping the access their own role gives them.
    if (route.startsWith('/learner')) return true;
    return true;
  }
}
