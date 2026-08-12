import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:wea_lms/app/theme/app_theme.dart';
import 'package:wea_lms/features/contact/application/contact_providers.dart';
import 'package:wea_lms/features/contact/domain/contact_models.dart';
import 'package:wea_lms/features/contact/presentation/contact_screen.dart';
import 'package:wea_lms/features/contact/presentation/widgets/enquiry_thread.dart';

Future<void> _pumpContact(WidgetTester tester, {Size size = const Size(1280, 1400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/contact',
    routes: [
      GoRoute(path: '/contact', builder: (_, _) => const ContactScreen()),
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: WEAAppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The mock catalogue repository answers after a deliberate delay, and that
  // timer is not an animation, so pumpAndSettle does not wait for it. Without
  // this the settings-backed copy has not arrived yet and the timer is still
  // pending when the test ends.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  group('enquiry model', () {
    test('parses a thread, its status and whether the sender has an account', () {
      final enquiry = Enquiry.fromMap({
        'id': 'enq-1',
        'reference': 'WEA-ENQ-00007',
        'name': 'Ada Obi',
        'email': 'ada@example.com',
        'subject': 'Programme dates',
        'message': 'When does the trade certificate begin?',
        'status': 'REPLIED',
        'user_id': 'user-1',
        'created_at': '2026-08-11T09:00:00Z',
        'replies': [
          {
            'id': 'rep-1',
            'body': 'The next intake opens in September.',
            'from_academy': 1,
            'author_name': 'WEA Office',
            'created_at': '2026-08-11T10:00:00Z',
          },
        ],
      });

      expect(enquiry.reference, 'WEA-ENQ-00007');
      expect(enquiry.status, EnquiryStatus.replied);
      expect(enquiry.awaitingReply, isFalse);
      expect(enquiry.hasAccount, isTrue);
      expect(enquiry.replies.single.fromAcademy, isTrue);
      expect(enquiry.replies.single.authorName, 'WEA Office');
    });

    test('an anonymous enquiry is marked as having no account', () {
      final enquiry = Enquiry.fromMap({
        'id': 'enq-2',
        'reference': 'WEA-ENQ-00008',
        'name': 'Visitor',
        'email': 'visitor@example.com',
        'message': 'Please send a brochure.',
        'status': 'NEW',
      });

      expect(enquiry.hasAccount, isFalse);
      expect(enquiry.awaitingReply, isTrue);
      expect(enquiry.replies, isEmpty);
    });

    test('every status survives a round trip to the wire and back', () {
      for (final status in EnquiryStatus.values) {
        expect(EnquiryStatus.parse(status.wireName), status);
      }
    });
  });

  group('contact page', () {
    testWidgets('shows the enquiries address', (tester) async {
      await mockNetworkImagesFor(() async {
        await _pumpContact(tester);
        expect(find.text('enquiries@wucoacademy.org'), findsOneWidget);
      });
    });

    testWidgets('will not send an enquiry without a message', (tester) async {
      await mockNetworkImagesFor(() async {
        await _pumpContact(tester);

        await tester.tap(find.widgetWithText(ElevatedButton, 'SEND ENQUIRY'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please include a little more detail.'),
          findsOneWidget,
        );
        expect(find.text('Please give your name.'), findsOneWidget);
      });
    });

    testWidgets('accepts an enquiry and returns a reference', (tester) async {
      await mockNetworkImagesFor(() async {
        await _pumpContact(tester);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Your name'),
          'Ada Obi',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email address'),
          'ada@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Your message'),
          'Please send details of the next trade certificate intake.',
        );

        final send = find.widgetWithText(ElevatedButton, 'SEND ENQUIRY');
        await tester.ensureVisible(send);
        await tester.pumpAndSettle();
        await tester.tap(send);
        await tester.pumpAndSettle();

        expect(find.text('ENQUIRY RECEIVED'), findsOneWidget);
        expect(find.textContaining('WEA-ENQ-'), findsOneWidget);
      });
    });

    testWidgets('renders without overflow across supported widths', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        for (final width in [360.0, 390.0, 768.0, 1024.0, 1440.0, 1920.0]) {
          await _pumpContact(tester, size: Size(width, 1600));
          expect(
            tester.takeException(),
            isNull,
            reason: 'contact page overflowed at ${width}px',
          );
        }
      });
    });
  });

  group('enquiry thread', () {
    testWidgets('separates the academy reply from the sender message', (
      tester,
    ) async {
      final enquiry = Enquiry.fromMap({
        'id': 'enq-1',
        'reference': 'WEA-ENQ-00007',
        'name': 'Ada Obi',
        'email': 'ada@example.com',
        'subject': 'Programme dates',
        'message': 'When does the trade certificate begin?',
        'status': 'REPLIED',
        'created_at': '2026-08-11T09:00:00Z',
        'replies': [
          {
            'id': 'rep-1',
            'body': 'The next intake opens in September.',
            'from_academy': 1,
            'author_name': 'WEA Office',
            'created_at': '2026-08-11T10:00:00Z',
          },
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: WEAAppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: EnquiryThread(enquiry: enquiry, initiallyExpanded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('When does the trade certificate begin?'), findsOneWidget);
      expect(find.text('The next intake opens in September.'), findsOneWidget);
      expect(find.textContaining('WEA Office'), findsOneWidget);
      // Without a follow-up callback the reply box is not offered.
      expect(find.widgetWithText(ElevatedButton, 'SEND FOLLOW-UP'), findsNothing);
    });
  });

  group('offline contact repository', () {
    test('issues a reference and remembers the enquiry', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final actions = container.read(contactActionsProvider);
      final reference = await actions.send(
        const EnquiryDraft(
          name: 'Ada Obi',
          email: 'ada@example.com',
          message: 'Please send details of the next intake.',
        ),
      );

      expect(reference, startsWith('WEA-ENQ-'));
      final mine = await container.read(contactRepositoryProvider).myEnquiries();
      expect(mine.first.reference, reference);
      expect(mine.first.status, EnquiryStatus.isNew);
    });
  });
}
