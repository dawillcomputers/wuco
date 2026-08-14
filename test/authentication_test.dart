import 'package:flutter_test/flutter_test.dart';
import 'package:wea_lms/app/router.dart';
import 'package:wea_lms/features/authentication/data/in_memory_auth_repository.dart';
import 'package:wea_lms/features/authentication/domain/account_status.dart';
import 'package:wea_lms/features/authentication/domain/auth_failure.dart';
import 'package:wea_lms/features/authentication/domain/auth_state.dart';
import 'package:wea_lms/features/authentication/domain/password_policy.dart';
import 'package:wea_lms/features/authentication/domain/user_profile.dart';
import 'package:wea_lms/features/authentication/domain/user_role.dart';

const _validPassword = 'Executive!2026';

Future<UserProfile> _register(
  InMemoryAuthRepository repository, {
  String email = 'learner@example.com',
}) => repository.signUp(
  email: email,
  password: _validPassword,
  firstName: 'Ada',
  lastName: 'Obi',
);

void main() {
  late InMemoryAuthRepository repository;

  setUp(() => repository = InMemoryAuthRepository());
  tearDown(() => repository.dispose());

  group('password policy', () {
    test('rejects passwords missing a required character class', () {
      expect(PasswordPolicy.isValid('short'), isFalse);
      expect(PasswordPolicy.isValid('alllowercase1!'), isFalse);
      expect(PasswordPolicy.isValid('NoDigitsHere!'), isFalse);
      expect(PasswordPolicy.isValid('NoSymbol1234'), isFalse);
    });

    test('accepts a password meeting every rule', () {
      expect(PasswordPolicy.isValid(_validPassword), isTrue);
      expect(PasswordPolicy.strength(_validPassword), greaterThan(.7));
    });
  });

  group('registration', () {
    test('creates a pending, unverified applicant', () async {
      final profile = await _register(repository);
      expect(profile.email, 'learner@example.com');
      expect(profile.role, UserRole.applicant);
      expect(profile.status, AccountStatus.pending);
      expect(profile.emailVerified, isFalse);
    });

    test('rejects a duplicate email', () async {
      await _register(repository);
      expect(
        () => _register(repository),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.kind,
            'kind',
            AuthFailureKind.emailAlreadyRegistered,
          ),
        ),
      );
    });

    test('rejects a weak password', () {
      expect(
        () => repository.signUp(
          email: 'weak@example.com',
          password: 'password',
          firstName: 'A',
          lastName: 'B',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.kind,
            'kind',
            AuthFailureKind.weakPassword,
          ),
        ),
      );
    });

    test('refuses to grant a privileged role on self-registration', () async {
      final profile = await repository.signUp(
        email: 'sneaky@example.com',
        password: _validPassword,
        firstName: 'A',
        lastName: 'B',
        role: UserRole.superAdmin,
      );
      expect(profile.role, UserRole.applicant);
    });
  });

  group('sign in', () {
    test('rejects an unknown account and a wrong password identically', () async {
      await _register(repository);
      Object? unknownError;
      Object? wrongError;
      try {
        await repository.signIn(email: 'nobody@example.com', password: _validPassword);
      } catch (error) {
        unknownError = error;
      }
      try {
        await repository.signIn(
          email: 'learner@example.com',
          password: 'Wrong!2026aa',
        );
      } catch (error) {
        wrongError = error;
      }
      expect((unknownError as AuthFailure).kind, AuthFailureKind.invalidCredentials);
      expect((wrongError as AuthFailure).kind, AuthFailureKind.invalidCredentials);
    });

    test('blocks a pending account until the email is verified', () async {
      await _register(repository);
      await repository.signOut();
      expect(
        () => repository.signIn(
          email: 'learner@example.com',
          password: _validPassword,
        ),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('succeeds once verified, and restores the session', () async {
      final profile = await _register(repository);
      await repository.verifyEmail('any');
      await repository.signOut();

      final signedIn = await repository.signIn(
        email: 'learner@example.com',
        password: _validPassword,
      );
      expect(signedIn.id, profile.id);
      expect(signedIn.status, AccountStatus.active);
      expect(await repository.restoreSession(), isNotNull);

      await repository.signOut();
      expect(await repository.restoreSession(), isNull);
    });
  });

  group('password recovery and change', () {
    test('rejects an unknown reset token', () {
      expect(
        () => repository.resetPassword(token: 'bogus', newPassword: _validPassword),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.kind,
            'kind',
            AuthFailureKind.invalidLink,
          ),
        ),
      );
    });

    test('sending a reset does not reveal whether the account exists', () async {
      await expectLater(repository.sendPasswordReset('nobody@example.com'), completes);
    });

    test('changing a password requires the current one', () async {
      await _register(repository);
      expect(
        () => repository.changePassword(
          currentPassword: 'Wrong!2026aa',
          newPassword: 'Another!2026',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.kind,
            'kind',
            AuthFailureKind.invalidCredentials,
          ),
        ),
      );
    });

    test('a successful change clears the temporary-password flag', () async {
      await repository.signIn(
        email: 'proptgoservices@gmail.com',
        password: 'WeaSetup!2026',
      );
      await repository.changePassword(
        currentPassword: 'WeaSetup!2026',
        newPassword: 'Another!2026',
      );
      final profile = await repository.restoreSession();
      expect(profile!.mustChangePassword, isFalse);
    });
  });

  group('super admin', () {
    Future<UserProfile> signInAsSuperAdmin() => repository.signIn(
      email: 'proptgoservices@gmail.com',
      password: 'WeaSetup!2026',
    );

    test('is seeded with a temporary password', () async {
      final profile = await signInAsSuperAdmin();
      expect(profile.role, UserRole.superAdmin);
      expect(profile.mustChangePassword, isTrue);
    });

    test('non-administrators cannot list or create users', () async {
      await _register(repository);
      expect(
        repository.listUsers(),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.kind,
            'kind',
            AuthFailureKind.notAuthorised,
          ),
        ),
      );
      expect(
        repository.adminCreateUser(
          email: 'x@example.com',
          role: UserRole.admin,
        ),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('creates a user with a one-time password', () async {
      await signInAsSuperAdmin();
      final created = await repository.adminCreateUser(
        email: 'lecturer@example.com',
        role: UserRole.lecturer,
      );
      expect(created.temporaryPassword.length, greaterThanOrEqualTo(12));
      expect(created.profile.mustChangePassword, isTrue);
      expect(created.profile.role, UserRole.lecturer);
      expect(PasswordPolicy.isValid(created.temporaryPassword), isTrue);
    });

    test('deletes a user but never the signed-in account', () async {
      final admin = await signInAsSuperAdmin();
      final created = await repository.adminCreateUser(
        email: 'temp@example.com',
        role: UserRole.learner,
      );
      await repository.adminDeleteUser(created.profile.id);
      expect((await repository.listUsers()).length, 1);

      expect(
        repository.adminDeleteUser(admin.id),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('programme enrolment', () {
    test('one account may hold several programme places', () async {
      await repository.signIn(
        email: 'proptgoservices@gmail.com',
        password: 'WeaSetup!2026',
      );
      final learner = await repository.adminCreateUser(
        email: 'multi@example.com',
        role: UserRole.learner,
      );
      await repository.enrol(
        userId: learner.profile.id,
        programmeId: 'programme-a',
        waivePayment: true,
      );
      await repository.enrol(
        userId: learner.profile.id,
        programmeId: 'programme-b',
      );
      final enrolments = await repository.listEnrolments(
        userId: learner.profile.id,
      );
      expect(enrolments.length, 2);
      expect(enrolments.where((e) => e.isWaived).length, 1);
    });

    test('the same programme cannot be joined twice', () async {
      await repository.signIn(
        email: 'proptgoservices@gmail.com',
        password: 'WeaSetup!2026',
      );
      final learner = await repository.adminCreateUser(
        email: 'dupe@example.com',
        role: UserRole.learner,
      );
      await repository.enrol(
        userId: learner.profile.id,
        programmeId: 'programme-a',
      );
      expect(
        repository.enrol(
          userId: learner.profile.id,
          programmeId: 'programme-a',
        ),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('a learner cannot waive their own payment', () async {
      await _register(repository);
      expect(
        repository.enrol(
          userId: (await repository.restoreSession())!.id,
          programmeId: 'programme-a',
          waivePayment: true,
        ),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.kind,
            'kind',
            AuthFailureKind.notAuthorised,
          ),
        ),
      );
    });
  });

  group('route guards', () {
    UserProfile profileWith(UserRole role) => UserProfile(
      id: 'id',
      email: 'user@example.com',
      role: role,
      status: AccountStatus.active,
      emailVerified: true,
    );

    test('holds on the splash until the session resolves', () {
      expect(guardLocation(const AuthState.initial(), '/learner'), '/splash');
      expect(guardLocation(const AuthState.initial(), '/splash'), isNull);
    });

    test('sends an unauthenticated visitor to login for protected routes', () {
      const state = AuthState.unauthenticated();
      expect(guardLocation(state, '/learner'), '/login');
      expect(guardLocation(state, '/profile'), '/login');
      expect(guardLocation(state, '/super-admin'), '/login');
      // Public pages stay reachable.
      expect(guardLocation(state, '/programmes'), isNull);
      expect(guardLocation(state, '/login'), isNull);
    });

    test('keeps a signed-in user away from guest-only pages', () {
      final state = AuthState.authenticated(profileWith(UserRole.learner));
      expect(guardLocation(state, '/login'), '/learner');
      expect(guardLocation(state, '/register'), '/learner');
    });

    test('a learner cannot reach lecturer, admin or super admin areas', () {
      final state = AuthState.authenticated(profileWith(UserRole.learner));
      expect(guardLocation(state, '/lecturer'), '/learner');
      expect(guardLocation(state, '/admin'), '/learner');
      expect(guardLocation(state, '/super-admin'), '/learner');
      expect(guardLocation(state, '/learner'), isNull);
    });

    test('an admin does not inherit super admin access', () {
      final state = AuthState.authenticated(profileWith(UserRole.admin));
      expect(guardLocation(state, '/super-admin'), '/admin');
      expect(guardLocation(state, '/admin'), isNull);
    });

    test('a super admin may reach every area', () {
      final state = AuthState.authenticated(profileWith(UserRole.superAdmin));
      for (final route in ['/learner', '/lecturer', '/admin', '/super-admin']) {
        expect(guardLocation(state, route), isNull, reason: route);
      }
    });

    test('a temporary password forces the change-password screen', () {
      final state = AuthState.authenticated(
        profileWith(UserRole.learner).copyWith(mustChangePassword: true),
      );
      expect(guardLocation(state, '/learner'), '/change-password');
      expect(guardLocation(state, '/change-password'), isNull);
    });

    test('email verification no longer walls off the application', () {
      // Accounts are created active and verified: holding a new registrant
      // behind a link in an inbox cost more registrations than the check was
      // worth. The verification screen still opens for anyone following an
      // older link, but it is not somewhere they are sent.
      final state = AuthState.authenticated(
        UserProfile(
          id: 'id',
          email: 'user@example.com',
          role: UserRole.applicant,
          status: AccountStatus.active,
          emailVerified: false,
        ),
      );
      expect(guardLocation(state, '/application'), isNull);
      expect(guardLocation(state, '/verify-email'), isNull);
    });

    test('each role lands on its own destination', () {
      expect(UserRole.learner.landingRoute, '/learner');
      expect(UserRole.lecturer.landingRoute, '/lecturer');
      expect(UserRole.admin.landingRoute, '/admin');
      expect(UserRole.superAdmin.landingRoute, '/super-admin');
      expect(UserRole.applicant.landingRoute, '/application');
      expect(
        UserRole.professionalMember.landingRoute,
        '/professional-network/member',
      );
    });
  });
}
