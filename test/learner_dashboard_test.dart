import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:wea_lms/app/router.dart';
import 'package:wea_lms/features/authentication/domain/auth_state.dart';
import 'package:wea_lms/features/authentication/domain/user_role.dart';
import 'package:wea_lms/features/learner/presentation/pages/learner_dashboard_page.dart';
import 'package:wea_lms/features/learner/presentation/shell/learner_shell.dart';
import 'package:wea_lms/features/learner/presentation/shell/learner_sidebar.dart';
import 'package:wea_lms/features/learner/presentation/widgets/dashboard_sections.dart';
import 'package:wea_lms/features/learner/presentation/widgets/learner_cards.dart';
import 'package:wea_lms/features/learner/presentation/widgets/learner_states.dart';

import 'support/learner_harness.dart';

void main() {
  group('learner route protection', () {
    test('an unauthenticated visitor is sent to the login page', () {
      expect(
        guardLocation(const AuthState.unauthenticated(), '/learner'),
        '/login',
      );
      expect(
        guardLocation(
          const AuthState.unauthenticated(),
          '/learner/certificates',
        ),
        '/login',
      );
    });

    test('a learner reaches every learner destination', () {
      final auth = AuthState.authenticated(testAccount());
      for (final route in const [
        '/learner',
        '/learner/programmes',
        '/learner/programmes/prog-finance',
        '/learner/courses',
        '/learner/courses/course-finance',
        '/learner/courses/course-finance/learn',
        '/learner/courses/course-finance/lessons/les-fin-5',
        '/learner/assessments',
        '/learner/results',
        '/learner/certificates',
        '/learner/credentials',
        '/learner/cpd',
        '/learner/notifications',
        '/learner/profile',
        '/learner/settings',
        '/learner/ai-mentor',
        '/learner/professional-network',
      ]) {
        expect(
          guardLocation(auth, route),
          isNull,
          reason: 'a learner should be allowed into $route',
        );
      }
    });

    test('other roles are turned away from the learner area', () {
      for (final role in const [
        UserRole.lecturer,
        UserRole.admin,
        UserRole.applicant,
        UserRole.professionalMember,
      ]) {
        final auth = AuthState.authenticated(testAccount(role: role));
        expect(
          guardLocation(auth, '/learner'),
          role.landingRoute,
          reason: '${role.label} must not reach the learner dashboard',
        );
        expect(guardLocation(auth, '/learner/results'), role.landingRoute);
      }
    });

    test('a learner cannot reach lecturer or administrator areas', () {
      final auth = AuthState.authenticated(testAccount());
      expect(guardLocation(auth, '/lecturer'), '/learner');
      expect(guardLocation(auth, '/admin'), '/learner');
      expect(guardLocation(auth, '/super-admin'), '/learner');
    });

    test('an unverified learner is held at email verification', () {
      final auth = AuthState.emailUnverified(testAccount());
      expect(guardLocation(auth, '/learner'), '/verify-email');
    });

    test('a signed-in learner is redirected away from the login page', () {
      final auth = AuthState.authenticated(testAccount());
      expect(guardLocation(auth, '/login'), '/learner');
    });

    test('a transient operation leaves the learner where they are', () {
      // Saving a profile or changing a password passes through AuthLoading.
      // Redirecting on it would throw the learner back to their dashboard
      // mid-edit as soon as the backend takes a moment to answer.
      const saving = AuthState.loading('Saving profile…');
      expect(guardLocation(saving, '/learner/profile'), isNull);
      expect(guardLocation(saving, '/learner/settings'), isNull);
      expect(guardLocation(saving, '/login'), isNull);
    });
  });

  group('dashboard', () {
    testWidgets('greets the signed-in learner by name and shows their figures', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(tester);

        expect(find.byType(LearnerDashboardPage), findsOneWidget);
        expect(find.textContaining('Ada.'), findsOneWidget);
        expect(find.text('Active programmes'), findsOneWidget);
        expect(find.text('CPD points'), findsOneWidget);
        expect(find.byType(ContinueLearningCard), findsOneWidget);
        expect(find.text('CONTINUE LEARNING'), findsOneWidget);
      });
    });

    testWidgets('offers both future-module entry points', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(tester);
        expect(find.byType(FeatureEntryCard), findsNWidgets(2));
        expect(find.text('WEA AI MENTOR'), findsOneWidget);
        expect(find.text('WEA PROFESSIONAL NETWORK'), findsOneWidget);
      });
    });

    testWidgets('shows empty states rather than blank panels', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(tester, data: LearnerDataMode.empty);

        expect(find.text('No course in progress'), findsOneWidget);
        expect(find.text('No active programmes'), findsOneWidget);
        expect(find.text('Nothing scheduled'), findsOneWidget);
        expect(find.byType(LearnerErrorState), findsNothing);
      });
    });

    testWidgets('shows a recoverable error state, never a raw exception', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(tester, data: LearnerDataMode.failing);

        expect(find.byType(LearnerErrorState), findsWidgets);
        expect(find.text(kLearnerNetworkMessage), findsWidgets);
        expect(find.text('TRY AGAIN'), findsWidgets);
        expect(find.textContaining('StubFailure'), findsNothing);
      });
    });
  });

  group('learner shell', () {
    testWidgets('shows a persistent sidebar on desktop', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(tester, size: const Size(1440, 1000));

        expect(find.byType(LearnerSidebar), findsOneWidget);
        expect(find.byType(Drawer), findsNothing);
        expect(find.text('My Programmes'), findsOneWidget);
      });
    });

    testWidgets('collapses to an icon rail on tablet', (tester) async {
      await mockNetworkImagesFor(() async {
        // Both portrait and landscape tablet widths keep persistent
        // navigation; only phones fall back to the drawer.
        for (final size in const [Size(768, 1024), Size(1000, 900)]) {
          await pumpLearnerApp(tester, size: size);

          final sidebar = tester.widget<LearnerSidebar>(
            find.byType(LearnerSidebar),
          );
          expect(sidebar.collapsed, isTrue, reason: '${size.width}px');
          // Labels are dropped in the rail; the icons carry tooltips instead.
          expect(find.text('My Programmes'), findsNothing);
        }
      });
    });

    testWidgets('moves navigation into a drawer on mobile', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(tester, size: const Size(390, 844));

        expect(find.byType(LearnerSidebar), findsNothing);
        expect(find.byTooltip('Open navigation'), findsOneWidget);

        await tester.tap(find.byTooltip('Open navigation'));
        await tester.pumpAndSettle();

        expect(find.byType(Drawer), findsOneWidget);
        expect(find.byType(LearnerSidebar), findsOneWidget);
        expect(find.text('My Courses'), findsOneWidget);
      });
    });

    testWidgets('drawer navigation reaches another page and closes itself', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final router = await pumpLearnerApp(
          tester,
          size: const Size(390, 844),
        );

        await tester.tap(find.byTooltip('Open navigation'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Certificates'));
        await tester.pumpAndSettle();

        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/learner/certificates',
        );
        expect(find.byType(Drawer), findsNothing);
      });
    });
  });

  group('dashboard layout', () {
    testWidgets('renders without overflow at every supported width', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        for (final width in [
          360.0,
          390.0,
          430.0,
          768.0,
          1024.0,
          1280.0,
          1440.0,
          1920.0,
        ]) {
          await pumpLearnerApp(tester, size: Size(width, 1200));
          expect(
            tester.takeException(),
            isNull,
            reason: 'dashboard overflowed at ${width}px',
          );
          expect(find.byType(LearnerPageBody), findsOneWidget);
        }
      });
    });
  });
}
