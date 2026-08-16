import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wea_lms/app/router.dart';
import 'package:wea_lms/app/theme/app_theme.dart';
import 'package:wea_lms/features/authentication/application/auth_controller.dart';
import 'package:wea_lms/features/authentication/data/auth_repository.dart';
import 'package:wea_lms/features/authentication/domain/account_status.dart';
import 'package:wea_lms/features/authentication/domain/programme_enrolment.dart';
import 'package:wea_lms/features/authentication/domain/user_profile.dart';
import 'package:wea_lms/features/authentication/domain/user_role.dart';
import 'package:wea_lms/features/learner/application/learner_providers.dart';

import 'stub_learner_repositories.dart';

export 'stub_learner_repositories.dart' show LearnerDataMode;

/// A signed-in account, used so learner screens run against a real session
/// rather than a stubbed profile provider.
UserProfile testAccount({UserRole role = UserRole.learner}) => UserProfile(
  id: 'user-1',
  email: 'ada.obi@example.com',
  firstName: 'Ada',
  lastName: 'Obi',
  phone: '+234 800 000 0000',
  country: 'Nigeria',
  role: role,
  status: AccountStatus.active,
  emailVerified: true,
  createdAt: DateTime(2026, 1, 4),
);

/// Authentication backend for widget tests: restores straight into a session
/// of the requested role. Only the surface the learner area touches is
/// implemented; anything else would be a test reaching where it should not.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({UserRole role = UserRole.learner})
    : _profile = testAccount(role: role);

  UserProfile _profile;
  final _controller = StreamController<UserProfile?>.broadcast();

  @override
  Stream<UserProfile?> get changes => _controller.stream;

  @override
  Future<UserProfile?> restoreSession() async => _profile;

  /// No provider in a widget test: the learner area never signs anybody in.
  @override
  Future<List<SocialProvider>> socialProviders() async => const [];

  @override
  Future<UserProfile> signInWithProvider({
    required String provider,
    required String idToken,
  }) async => throw UnimplementedError();

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async => _profile;

  @override
  Future<void> signOut() async {}

  @override
  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? country,
    String? avatarUrl,
  }) async => _profile = _profile.copyWith(
    firstName: firstName,
    lastName: lastName,
    phone: phone,
    country: country,
    avatarUrl: avatarUrl,
  );

  Never _unsupported() =>
      throw UnsupportedError('Not reachable from the learner area.');

  @override
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    String? country,
    UserRole role = UserRole.applicant,
  }) => _unsupported();

  @override
  Future<void> sendPasswordReset(String email) => _unsupported();

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) => _unsupported();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _unsupported();

  @override
  Future<List<UserProfile>> listUsers() => _unsupported();

  @override
  Future<({UserProfile profile, String temporaryPassword})> adminCreateUser({
    required String email,
    required UserRole role,
    String firstName = '',
    String lastName = '',
  }) => _unsupported();

  @override
  Future<void> adminDeleteUser(String userId) => _unsupported();

  @override
  Future<UserProfile> adminSetStatus({
    required String userId,
    required AccountStatus status,
  }) => _unsupported();

  @override
  Future<UserProfile> adminSetRole({
    required String userId,
    required UserRole role,
  }) => _unsupported();

  @override
  Future<List<ProgrammeEnrolment>> listEnrolments({String? userId}) =>
      _unsupported();

  @override
  Future<ProgrammeEnrolment> enrol({
    required String userId,
    required String programmeId,
    bool waivePayment = false,
  }) => _unsupported();
}

/// Boots the real application — real router, real guards — signed in as
/// [role], then navigates to [location].
///
/// [data] swaps the whole learner backend for empty or failing stubs, which is
/// how the empty- and error-state tests are driven.
Future<GoRouter> pumpLearnerApp(
  WidgetTester tester, {
  String location = '/learner',
  UserRole role = UserRole.learner,
  LearnerDataMode data = LearnerDataMode.seeded,
  Size size = const Size(1440, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fail = data == LearnerDataMode.failing;
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(role: role)),
      if (data != LearnerDataMode.seeded) ...[
        learnerRepositoryProvider.overrideWithValue(
          StubLearnerRepository(fail: fail),
        ),
        programmeRepositoryProvider.overrideWithValue(
          StubProgrammeRepository(fail: fail),
        ),
        courseRepositoryProvider.overrideWithValue(
          StubCourseRepository(fail: fail),
        ),
        lessonRepositoryProvider.overrideWithValue(
          StubLessonRepository(fail: fail),
        ),
        assessmentRepositoryProvider.overrideWithValue(
          StubAssessmentRepository(fail: fail),
        ),
        certificateRepositoryProvider.overrideWithValue(
          StubCertificateRepository(fail: fail),
        ),
        credentialRepositoryProvider.overrideWithValue(
          StubCredentialRepository(fail: fail),
        ),
        cpdRepositoryProvider.overrideWithValue(StubCpdRepository(fail: fail)),
        notificationRepositoryProvider.overrideWithValue(
          StubNotificationRepository(fail: fail),
        ),
        preferencesRepositoryProvider.overrideWithValue(
          StubPreferencesRepository(fail: fail),
        ),
        learnerSearchRepositoryProvider.overrideWithValue(
          StubSearchRepository(fail: fail),
        ),
      ],
    ],
  );
  addTearDown(container.dispose);

  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: WEAAppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();

  router.go(location);
  await settleLearnerPage(tester);
  return router;
}

/// Drains the page, including reads a page starts on its *first* build.
///
/// `pumpAndSettle` only waits while frames are scheduled, so a repository call
/// made during the final build — a detail page fetching its parent programme,
/// say — is still in flight when it returns.
Future<void> settleLearnerPage(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}
