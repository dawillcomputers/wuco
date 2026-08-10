/// Roles recognised by WEA.
///
/// Privileged roles are never self-assigned during registration; see
/// [UserRole.selfAssignable]. Granting them is a Super Admin action enforced in
/// the repository and, for live Supabase, in row-level security.
enum UserRole {
  applicant('APPLICANT', 'Applicant', '/application'),
  learner('LEARNER', 'Learner', '/learner'),
  lecturer('LECTURER', 'Lecturer', '/lecturer'),
  admin('ADMIN', 'Administrator', '/admin'),
  superAdmin('SUPER_ADMIN', 'Super Administrator', '/super-admin'),
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

  /// Roles only a Super Admin may grant.
  static const grantableBySuperAdminOnly = {
    UserRole.lecturer,
    UserRole.admin,
    UserRole.superAdmin,
  };

  bool get isPrivileged => grantableBySuperAdminOnly.contains(this);

  /// Whether this role may administer users. Admin does *not* imply Super
  /// Admin; Super Admin is always explicit.
  bool get canManageUsers => this == UserRole.superAdmin;

  /// Routes this role is permitted to open.
  bool canAccess(String route) {
    if (route.startsWith('/super-admin')) {
      return this == UserRole.superAdmin;
    }
    if (route.startsWith('/admin')) {
      return this == UserRole.admin || this == UserRole.superAdmin;
    }
    if (route.startsWith('/lecturer')) {
      return this == UserRole.lecturer || this == UserRole.superAdmin;
    }
    if (route.startsWith('/learner')) {
      return this == UserRole.learner || this == UserRole.superAdmin;
    }
    return true;
  }
}
