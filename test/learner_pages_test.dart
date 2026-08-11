import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:wea_lms/features/learner/presentation/pages/learning_page.dart';
import 'package:wea_lms/features/learner/presentation/widgets/assessment_cards.dart';
import 'package:wea_lms/features/learner/presentation/widgets/certificate_document.dart';
import 'package:wea_lms/features/learner/presentation/widgets/credential_cards.dart';
import 'package:wea_lms/features/learner/presentation/widgets/learner_cards.dart';
import 'package:wea_lms/features/learner/presentation/widgets/learner_states.dart';
import 'package:wea_lms/features/learner/presentation/widgets/lesson_player.dart';

import 'support/learner_harness.dart';

/// Finds a button by its label, matching subclasses.
///
/// `find.widgetWithText` compares runtime types exactly, so it misses the
/// private subclasses that `ElevatedButton.icon` and friends return.
Finder buttonLabelled<T extends ButtonStyleButton>(String label) =>
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((widget) => widget is T),
    );

/// Every learner destination, with a phrase that proves the page actually
/// rendered rather than merely routing.
const _pages = <(String, String)>[
  ('/learner/programmes', 'Your executive programmes'),
  ('/learner/programmes/prog-finance', 'Overall progress'),
  ('/learner/courses', 'Your courses'),
  ('/learner/courses/course-finance', 'Your progress'),
  ('/learner/assessments', 'Your assessments'),
  ('/learner/assessments/ass-1', 'Before you begin'),
  ('/learner/results', 'Your results'),
  ('/learner/results/res-1', 'Faculty feedback'),
  ('/learner/certificates', 'Your certificates'),
  ('/learner/certificates/cert-trade', 'Certificate record'),
  ('/learner/credentials', 'Your verifiable credentials'),
  ('/learner/cpd', 'CPD history'),
  ('/learner/notifications', 'Your notifications'),
  ('/learner/profile', 'Your professional profile'),
  ('/learner/settings', 'Your settings'),
  ('/learner/ai-mentor', 'What the AI Mentor will do'),
  ('/learner/professional-network', 'What the network will offer'),
];

void main() {
  group('every learner page loads its own data', () {
    for (final (route, marker) in _pages) {
      testWidgets(route, (tester) async {
        await mockNetworkImagesFor(() async {
          final router = await pumpLearnerApp(tester, location: route);

          expect(
            router.routerDelegate.currentConfiguration.uri.path,
            route,
            reason: 'the guard should have allowed $route',
          );
          expect(
            find.text(marker),
            findsWidgets,
            reason: '$route did not render its content',
          );
          expect(tester.takeException(), isNull);
        });
      });
    }
  });

  group('programmes', () {
    testWidgets('lists enrolled programmes and opens one', (tester) async {
      await mockNetworkImagesFor(() async {
        final router = await pumpLearnerApp(
          tester,
          location: '/learner/programmes',
        );

        expect(find.byType(LearnerProgrammeCard), findsNWidgets(3));
        await tester.tap(find.text('Corporate Finance for Executives').first);
        await tester.pumpAndSettle();

        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/learner/programmes/prog-finance',
        );
        expect(find.text('Courses in this programme'), findsOneWidget);
      });
    });

    testWidgets('invites enrolment when there are none', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(
          tester,
          location: '/learner/programmes',
          data: LearnerDataMode.empty,
        );
        expect(find.text('No active programmes'), findsOneWidget);
        expect(find.text('EXPLORE PROGRAMMES'), findsOneWidget);
      });
    });
  });

  group('courses', () {
    testWidgets('filters by status and can be cleared', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(tester, location: '/learner/courses');
        expect(find.byType(LearnerCourseCard), findsNWidgets(4));

        await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
        await tester.pumpAndSettle();
        expect(find.byType(LearnerCourseCard), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Not started'));
        await tester.pumpAndSettle();
        expect(find.byType(LearnerCourseCard), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
        await tester.pumpAndSettle();
        expect(find.byType(LearnerCourseCard), findsNWidgets(4));
      });
    });

    testWidgets('searches within the learner’s own courses', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(tester, location: '/learner/courses');

        await tester.enterText(find.byType(TextField).last, 'board');
        await tester.pumpAndSettle();
        expect(find.byType(LearnerCourseCard), findsOneWidget);

        await tester.enterText(find.byType(TextField).last, 'zzzz');
        await tester.pumpAndSettle();
        expect(find.text('No courses match'), findsOneWidget);
      });
    });
  });

  group('learning interface', () {
    testWidgets('opens the curriculum beside the lesson on desktop', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(
          tester,
          location: '/learner/courses/course-finance/learn',
          size: const Size(1440, 1100),
        );

        expect(find.byType(LearningPage), findsOneWidget);
        expect(find.text('COURSE CURRICULUM'), findsOneWidget);
        // Resumes on the course's current lesson.
        expect(find.text('Internal rate of return'), findsWidgets);
        expect(find.byType(LessonPlayer), findsOneWidget);
      });
    });

    testWidgets('puts the curriculum behind a drawer on mobile', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(
          tester,
          location: '/learner/courses/course-finance/learn',
          size: const Size(390, 900),
        );

        expect(find.text('COURSE CURRICULUM'), findsNothing);
        await tester.tap(find.byTooltip('Course curriculum'));
        await tester.pumpAndSettle();
        expect(find.text('COURSE CURRICULUM'), findsOneWidget);
      });
    });

    testWidgets('will not complete a video lesson that was only opened', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(
          tester,
          location: '/learner/courses/course-finance/lessons/les-fin-5',
          size: const Size(1440, 1100),
        );

        final button = tester.widget<ElevatedButton>(
          buttonLabelled<ElevatedButton>('MARK AS COMPLETE'),
        );
        expect(
          button.onPressed,
          isNull,
          reason: 'opening a lesson must not be enough to complete it',
        );
        expect(find.textContaining('watched the lesson through'), findsOneWidget);
      });
    });

    testWidgets('completes a lesson once it has been watched, then advances', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final router = await pumpLearnerApp(
          tester,
          location: '/learner/courses/course-finance/lessons/les-fin-5',
          size: const Size(1440, 1100),
        );

        // Watch it through, as the player's completion criterion requires.
        final controller = tester
            .widget<LessonPlayer>(find.byType(LessonPlayer))
            .controller;
        controller.seek(controller.duration);
        await tester.pumpAndSettle();

        await tester.tap(buttonLabelled<ElevatedButton>('MARK AS COMPLETE'));
        await tester.pumpAndSettle();

        // Completion moves the learner on to the next lesson, which the
        // completion has just unlocked.
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/learner/courses/course-finance/lessons/les-fin-6',
        );
      });
    });

    testWidgets('locked lessons cannot be opened from the curriculum', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(
          tester,
          location: '/learner/courses/course-finance/lessons/les-fin-5',
          size: const Size(1440, 1100),
        );

        final next = tester.widget<OutlinedButton>(
          buttonLabelled<OutlinedButton>('NEXT LESSON'),
        );
        expect(next.onPressed, isNull);
        expect(
          find.text('The next lesson unlocks once you complete this one.'),
          findsOneWidget,
        );
      });
    });

    testWidgets('a learner keeps private notes against a lesson', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(
          tester,
          location: '/learner/courses/course-finance/lessons/les-fin-5',
          size: const Size(1440, 1400),
        );

        // ensureVisible rather than scrollUntilVisible: the shell has several
        // scrollables and only the element's own one should move.
        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'SAVE NOTE'),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Capture a thought while it is fresh…'),
          'Check the discount rate assumption.',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'SAVE NOTE'));
        await tester.pumpAndSettle();

        expect(
          find.text('Check the discount rate assumption.'),
          findsOneWidget,
        );
      });
    });
  });

  group('assessments and results', () {
    testWidgets('groups assessments by what needs attention', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(tester, location: '/learner/assessments');

        expect(find.text('Available now'), findsOneWidget);
        // "Upcoming" and "Completed" are also status-chip labels, so the
        // headings are not unique on this page.
        expect(find.text('Upcoming'), findsWidgets);
        expect(find.text('Completed'), findsWidgets);
        expect(find.byType(AssessmentCard), findsNWidgets(3));
      });
    });

    testWidgets('shows results as a table on desktop', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(
          tester,
          location: '/learner/results',
          size: const Size(1440, 1000),
        );

        expect(find.byType(ResultTableHeader), findsOneWidget);
        final rows = tester.widgetList<ResultRow>(find.byType(ResultRow));
        expect(rows.every((row) => row.asRow), isTrue);
      });
    });

    testWidgets('shows results as cards on mobile', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(
          tester,
          location: '/learner/results',
          size: const Size(390, 900),
        );

        expect(find.byType(ResultTableHeader), findsNothing);
        final rows = tester.widgetList<ResultRow>(find.byType(ResultRow));
        expect(rows.every((row) => !row.asRow), isTrue);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('states plainly that results are not editable', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(tester, location: '/learner/results/res-1');
        expect(find.text('Distinction'), findsWidgets);
        expect(find.textContaining('issued by WEA faculty'), findsOneWidget);
      });
    });
  });

  group('certificates and credentials', () {
    testWidgets('renders the certificate document with the learner’s name', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(
          tester,
          location: '/learner/certificates/cert-trade',
        );

        expect(find.byType(CertificateDocument), findsOneWidget);
        expect(find.text('Ada Obi'), findsWidgets);
        expect(find.text('WEA-ATI-2026-0148'), findsWidgets);
      });
    });

    testWidgets('a pending certificate cannot be opened', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(tester, location: '/learner/certificates');

        final buttons = tester
            .widgetList<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'VIEW CERTIFICATE'),
            )
            .toList();
        expect(buttons.length, 2);
        expect(
          buttons.where((button) => button.onPressed == null).length,
          1,
          reason: 'the unissued certificate must not be viewable',
        );
      });
    });

    testWidgets('lists verifiable credentials', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(tester, location: '/learner/credentials');
        expect(find.byType(CredentialCard), findsOneWidget);
        expect(find.textContaining('WEA-CRED-8842-ATI'), findsOneWidget);
      });
    });

    testWidgets('shows an invitation when nothing has been earned yet', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(
          tester,
          location: '/learner/certificates',
          data: LearnerDataMode.empty,
        );
        expect(find.text('No certificates yet'), findsOneWidget);
      });
    });
  });

  group('CPD', () {
    testWidgets('shows points against the goal and lets the goal change', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(tester, location: '/learner/cpd');

        expect(find.text('42'), findsOneWidget);
        expect(find.text('of 60 points'), findsOneWidget);

        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('80 points').last);
        await tester.pumpAndSettle();

        expect(find.text('of 80 points'), findsOneWidget);
        expect(
          find.text('42'),
          findsOneWidget,
          reason: 'changing the goal must not change awarded points',
        );
      });
    });
  });

  group('notifications', () {
    testWidgets('marks everything read and clears the badge', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(tester, location: '/learner/notifications');

        expect(find.textContaining('2 unread'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(OutlinedButton, 'MARK ALL AS READ'),
        );
        await tester.pumpAndSettle();

        expect(find.text('You are up to date.'), findsOneWidget);
      });
    });

    testWidgets('filters by category and explains an empty filter', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(tester, location: '/learner/notifications');

        await tester.tap(find.widgetWithText(ChoiceChip, 'Certificate'));
        await tester.pumpAndSettle();
        expect(find.text('Your certificate is ready'), findsOneWidget);
        expect(find.text('Results published'), findsNothing);

        await tester.tap(find.widgetWithText(ChoiceChip, 'AI Mentor'));
        await tester.pumpAndSettle();
        expect(find.text('Nothing in this view'), findsOneWidget);
      });
    });
  });

  group('profile and settings', () {
    testWidgets('edits the profile through the repositories', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(
          tester,
          location: '/learner/profile',
          size: const Size(1280, 1400),
        );

        await tester.tap(find.widgetWithText(OutlinedButton, 'EDIT PROFILE'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Professional title'),
          'Group Chief Executive',
        );
        final save = find.widgetWithText(ElevatedButton, 'SAVE PROFILE');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(find.textContaining('Group Chief Executive'), findsWidgets);
      });
    });

    testWidgets('rejects a malformed professional link', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(
          tester,
          location: '/learner/profile',
          size: const Size(1280, 1400),
        );

        await tester.tap(find.widgetWithText(OutlinedButton, 'EDIT PROFILE'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'LinkedIn profile'),
          'not-a-url',
        );
        final save = find.widgetWithText(ElevatedButton, 'SAVE PROFILE');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(
          find.text('Enter a full web address, including https://'),
          findsOneWidget,
        );
      });
    });

    testWidgets('never offers to change role or account status', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(
          tester,
          location: '/learner/settings',
          size: const Size(1280, 1600),
        );

        expect(find.text('Signed in as'.toUpperCase()), findsOneWidget);
        expect(
          find.textContaining('role and account status are set by WEA'),
          findsOneWidget,
        );
      });
    });

    testWidgets('persists a notification preference', (tester) async {
      await mockNetworkImagesFor(() async {
        await pumpLearnerApp(
          tester,
          location: '/learner/settings',
          size: const Size(1280, 1600),
        );

        final finder = find.widgetWithText(
          SwitchListTile,
          'Assessment reminders',
        );
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(finder).value, isTrue);

        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(finder).value, isFalse);
      });
    });
  });

  group('global search', () {
    testWidgets('finds a course and navigates to it', (tester) async {
      await mockNetworkImagesFor(() async {
        final router = await pumpLearnerApp(tester);

        await tester.tap(find.text('Search your learning'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Search programmes, courses, lessons…'),
          'governance',
        );
        await tester.pumpAndSettle();

        expect(find.text('Board Governance & Risk'), findsOneWidget);
        await tester.tap(find.text('Board Governance & Risk'));
        await tester.pumpAndSettle();
        // The destination starts a further repository read on its first build,
        // which pumpAndSettle has no frame to wait on.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/learner/courses/course-governance',
        );
      });
    });
  });

  group('responsive layout', () {
    const widths = [360.0, 390.0, 430.0, 768.0, 1024.0, 1280.0, 1440.0, 1920.0];

    for (final (route, _) in _pages) {
      testWidgets('$route survives every supported width', (tester) async {
        await mockNetworkImagesFor(() async {
          for (final width in widths) {
            await pumpLearnerApp(
              tester,
              location: route,
              size: Size(width, 1400),
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '$route overflowed at ${width}px',
            );
          }
        });
      });
    }

    testWidgets('the learning interface survives every supported width', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        for (final width in widths) {
          await pumpLearnerApp(
            tester,
            location: '/learner/courses/course-finance/learn',
            size: Size(width, 1400),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'the learning interface overflowed at ${width}px',
          );
        }
      });
    });
  });

  group('unknown records', () {
    for (final route in const [
      '/learner/programmes/does-not-exist',
      '/learner/courses/does-not-exist',
      '/learner/assessments/does-not-exist',
      '/learner/results/does-not-exist',
      '/learner/certificates/does-not-exist',
    ]) {
      testWidgets('$route explains itself instead of failing', (tester) async {
        await mockNetworkImagesFor(() async {
          await pumpLearnerApp(tester, location: route);
          expect(find.byType(LearnerEmptyState), findsOneWidget);
          expect(find.textContaining('no longer valid'), findsOneWidget);
        });
      });
    }
  });
}
