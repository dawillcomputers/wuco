import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../../core/services/app_environment.dart';
import '../domain/account_status.dart';
import '../domain/auth_failure.dart';
import '../domain/password_policy.dart';
import '../domain/programme_enrolment.dart';
import '../domain/user_profile.dart';
import '../domain/user_role.dart';
import 'auth_repository.dart';

/// Offline development backend.
///
/// Used when Supabase credentials are absent so the whole authentication
/// experience is runnable and testable. It mirrors the rules the live backend
/// enforces — password hashing, role restrictions, account status — so moving
/// to Supabase changes configuration only. State lives in memory and is lost on
/// restart; it is never a production path.
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository() {
    _seedSuperAdmin();
  }

  final _controller = StreamController<UserProfile?>.broadcast();
  final _users = <String, _Account>{};
  final _enrolments = <ProgrammeEnrolment>[];
  final _resetTokens = <String, String>{};
  final _verificationTokens = <String, String>{};
  final _random = Random.secure();

  String? _currentUserId;

  @override
  Stream<UserProfile?> get changes => _controller.stream;

  void _seedSuperAdmin() {
    final email = AppEnvironmentConfig.seedSuperAdminEmail.toLowerCase();
    final id = _newId();
    _users[email] = _Account(
      profile: UserProfile(
        id: id,
        email: email,
        firstName: 'WEA',
        lastName: 'Super Admin',
        role: UserRole.superAdmin,
        status: AccountStatus.active,
        emailVerified: true,
        // Seeded with a temporary password that must be replaced on first use.
        mustChangePassword: true,
        createdAt: DateTime.now(),
      ),
      salt: _newSalt(),
    ).._setPassword(AppEnvironmentConfig.seedSuperAdminPassword);
  }

  String _newId() =>
      List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();

  String _newSalt() =>
      List.generate(8, (_) => _random.nextInt(256).toRadixString(16)).join();

  /// Readable but unguessable: 12 chars from an unambiguous alphabet.
  String _newTemporaryPassword() {
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghijkmnopqrstuvwxyz';
    const digits = '23456789';
    const symbols = '!@#\$%&*';
    final pools = [upper, lower, digits, symbols];
    final chars = <String>[
      for (final pool in pools) pool[_random.nextInt(pool.length)],
    ];
    const all = '$upper$lower$digits$symbols';
    while (chars.length < 12) {
      chars.add(all[_random.nextInt(all.length)]);
    }
    chars.shuffle(_random);
    return chars.join();
  }

  _Account? _requireCurrent() {
    if (_currentUserId == null) return null;
    for (final account in _users.values) {
      if (account.profile.id == _currentUserId) return account;
    }
    return null;
  }

  void _requireSuperAdmin() {
    final current = _requireCurrent();
    if (current == null) {
      throw const AuthFailure(AuthFailureKind.sessionExpired);
    }
    if (!current.profile.role.canManageUsers) {
      throw const AuthFailure(AuthFailureKind.notAuthorised);
    }
  }

  void _emit() => _controller.add(_requireCurrent()?.profile);

  @override
  Future<UserProfile?> restoreSession() async => _requireCurrent()?.profile;

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final account = _users[email.trim().toLowerCase()];
    // Same failure for unknown address and wrong password: distinguishing them
    // would let anyone enumerate registered accounts.
    if (account == null || !account.matches(password)) {
      throw const AuthFailure(AuthFailureKind.invalidCredentials);
    }
    final status = account.profile.status;
    if (!status.canSignIn) {
      throw AuthFailure(switch (status) {
        AccountStatus.suspended => AuthFailureKind.accountSuspended,
        AccountStatus.disabled => AuthFailureKind.accountDisabled,
        AccountStatus.pendingApproval => AuthFailureKind.accountPendingApproval,
        _ => AuthFailureKind.emailNotVerified,
      }, status.blockedMessage);
    }
    _currentUserId = account.profile.id;
    _emit();
    return account.profile;
  }

  @override
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    String? country,
    UserRole role = UserRole.applicant,
  }) async {
    final key = email.trim().toLowerCase();
    if (_users.containsKey(key)) {
      throw const AuthFailure(AuthFailureKind.emailAlreadyRegistered);
    }
    if (!PasswordPolicy.isValid(password)) {
      throw const AuthFailure(AuthFailureKind.weakPassword);
    }
    // Self-registration can never yield a privileged role, whatever the client
    // asked for.
    final safeRole = UserRole.selfAssignable.contains(role)
        ? role
        : UserRole.applicant;

    final account = _Account(
      profile: UserProfile(
        id: _newId(),
        email: key,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        phone: phone,
        country: country,
        role: safeRole,
        status: AccountStatus.pending,
        createdAt: DateTime.now(),
      ),
      salt: _newSalt(),
    ).._setPassword(password);
    _users[key] = account;

    _verificationTokens[_newId()] = key;
    _currentUserId = account.profile.id;
    _emit();
    return account.profile;
  }

  @override
  Future<void> signOut() async {
    _currentUserId = null;
    _emit();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final key = email.trim().toLowerCase();
    // Always succeeds, so the response cannot confirm whether an account exists.
    if (_users.containsKey(key)) {
      _resetTokens[_newId()] = key;
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final email = _resetTokens[token];
    if (email == null) {
      throw const AuthFailure(AuthFailureKind.invalidLink);
    }
    if (!PasswordPolicy.isValid(newPassword)) {
      throw const AuthFailure(AuthFailureKind.weakPassword);
    }
    final account = _users[email];
    if (account == null) {
      throw const AuthFailure(AuthFailureKind.invalidLink);
    }
    account._setPassword(newPassword);
    account.profile = account.profile.copyWith(mustChangePassword: false);
    _resetTokens.remove(token);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final account = _requireCurrent();
    if (account == null) {
      throw const AuthFailure(AuthFailureKind.sessionExpired);
    }
    if (!account.matches(currentPassword)) {
      throw const AuthFailure(AuthFailureKind.invalidCredentials);
    }
    if (!PasswordPolicy.isValid(newPassword)) {
      throw const AuthFailure(AuthFailureKind.weakPassword);
    }
    account._setPassword(newPassword);
    account.profile = account.profile.copyWith(mustChangePassword: false);
    _emit();
  }

  @override
  Future<void> resendVerification(String email) async {
    final key = email.trim().toLowerCase();
    if (_users.containsKey(key)) {
      _verificationTokens[_newId()] = key;
    }
  }

  @override
  Future<UserProfile> verifyEmail(String token) async {
    final email = _verificationTokens[token] ?? _currentEmail();
    final account = email == null ? null : _users[email];
    if (account == null) {
      throw const AuthFailure(AuthFailureKind.invalidLink);
    }
    account.profile = account.profile.copyWith(
      emailVerified: true,
      status: account.profile.status == AccountStatus.pending
          ? AccountStatus.active
          : account.profile.status,
    );
    _verificationTokens.remove(token);
    _emit();
    return account.profile;
  }

  String? _currentEmail() => _requireCurrent()?.profile.email;

  @override
  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? country,
    String? avatarUrl,
  }) async {
    final account = _requireCurrent();
    if (account == null) {
      throw const AuthFailure(AuthFailureKind.sessionExpired);
    }
    // Role and status are deliberately absent: users cannot promote themselves.
    account.profile = account.profile.copyWith(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      country: country,
      avatarUrl: avatarUrl,
    );
    _emit();
    return account.profile;
  }

  @override
  Future<List<UserProfile>> listUsers() async {
    _requireSuperAdmin();
    return _users.values.map((account) => account.profile).toList()
      ..sort((a, b) => a.email.compareTo(b.email));
  }

  @override
  Future<({UserProfile profile, String temporaryPassword})> adminCreateUser({
    required String email,
    required UserRole role,
    String firstName = '',
    String lastName = '',
  }) async {
    _requireSuperAdmin();
    final key = email.trim().toLowerCase();
    if (_users.containsKey(key)) {
      throw const AuthFailure(AuthFailureKind.emailAlreadyRegistered);
    }
    final temporary = _newTemporaryPassword();
    final account = _Account(
      profile: UserProfile(
        id: _newId(),
        email: key,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        role: role,
        // Administrator-created accounts are usable immediately; the temporary
        // password is the gate.
        status: AccountStatus.active,
        emailVerified: true,
        mustChangePassword: true,
        createdAt: DateTime.now(),
      ),
      salt: _newSalt(),
    ).._setPassword(temporary);
    _users[key] = account;
    return (profile: account.profile, temporaryPassword: temporary);
  }

  @override
  Future<void> adminDeleteUser(String userId) async {
    _requireSuperAdmin();
    if (userId == _currentUserId) {
      throw const AuthFailure(
        AuthFailureKind.notAuthorised,
        'You cannot delete the account you are signed in with.',
      );
    }
    _users.removeWhere((_, account) => account.profile.id == userId);
    _enrolments.removeWhere((enrolment) => enrolment.userId == userId);
  }

  @override
  Future<UserProfile> adminSetRole({
    required String userId,
    required UserRole role,
  }) async {
    _requireSuperAdmin();
    for (final account in _users.values) {
      if (account.profile.id == userId) {
        account.profile = account.profile.copyWith(role: role);
        return account.profile;
      }
    }
    throw const AuthFailure(AuthFailureKind.unknown, 'That account no longer exists.');
  }

  @override
  Future<List<ProgrammeEnrolment>> listEnrolments({String? userId}) async {
    final current = _requireCurrent();
    if (current == null) {
      throw const AuthFailure(AuthFailureKind.sessionExpired);
    }
    // Anyone may read their own; only a Super Admin may read another's.
    if (userId != null && userId != current.profile.id) {
      _requireSuperAdmin();
    }
    final target = userId ?? current.profile.id;
    return _enrolments.where((e) => e.userId == target).toList();
  }

  @override
  Future<ProgrammeEnrolment> enrol({
    required String userId,
    required String programmeId,
    bool waivePayment = false,
  }) async {
    final current = _requireCurrent();
    if (current == null) {
      throw const AuthFailure(AuthFailureKind.sessionExpired);
    }
    if (waivePayment || userId != current.profile.id) {
      _requireSuperAdmin();
    }
    final existing = _enrolments.where(
      (e) => e.userId == userId && e.programmeId == programmeId,
    );
    if (existing.isNotEmpty) {
      throw const AuthFailure(
        AuthFailureKind.unknown,
        'That learner is already enrolled on this programme.',
      );
    }
    final enrolment = ProgrammeEnrolment(
      id: _newId(),
      userId: userId,
      programmeId: programmeId,
      payment: waivePayment ? EnrolmentPayment.waived : EnrolmentPayment.pending,
      grantedBy: waivePayment ? current.profile.id : null,
      createdAt: DateTime.now(),
    );
    _enrolments.add(enrolment);
    return enrolment;
  }

  void dispose() => _controller.close();
}

/// Stored account. Passwords are kept only as a salted digest.
class _Account {
  _Account({required this.profile, required this.salt});

  UserProfile profile;
  final String salt;
  String _digest = '';

  void _setPassword(String password) => _digest = _hash(password);

  bool matches(String password) => _digest == _hash(password);

  String _hash(String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();
}
