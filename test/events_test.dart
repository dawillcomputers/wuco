import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:wea_lms/app/router.dart';
import 'package:wea_lms/app/theme/app_theme.dart';
import 'package:wea_lms/features/authentication/domain/account_status.dart';
import 'package:wea_lms/features/authentication/domain/auth_state.dart';
import 'package:wea_lms/features/authentication/domain/user_profile.dart';
import 'package:wea_lms/features/authentication/domain/user_role.dart';
import 'package:wea_lms/features/events/data/events_repository.dart';
import 'package:wea_lms/features/events/data/offline_events_repository.dart';
import 'package:wea_lms/features/events/domain/event_models.dart';
import 'package:wea_lms/features/events/presentation/event_dashboard_screen.dart';
import 'package:wea_lms/features/events/presentation/event_detail_screen.dart';
import 'package:wea_lms/features/events/presentation/event_registration_screen.dart';
import 'package:wea_lms/features/events/presentation/events_screen.dart';
import 'package:wea_lms/features/events/presentation/widgets/event_share_bar.dart';

/// A paid event, as the API returns it.
Map<String, dynamic> _summitMap() => {
  'id': 'evt-1',
  'slug': 'africa-trade-and-investment-summit',
  'title': 'Africa Trade and Investment Summit',
  'subtitle': 'Cross-border growth under AfCFTA',
  'event_type': 'SUMMIT',
  'summary': 'A one-day executive summit.',
  'starts_at': '2026-09-25 09:00:00',
  'ends_at': '2026-09-25 17:00:00',
  'timezone': 'WAT',
  'venue': 'Lagos Continental',
  'format': 'HYBRID',
  'fee_amount': 250000,
  'fee_currency': 'NGN',
  'status': 'PUBLISHED',
  'featured': 1,
  'capacity': 300,
};

Future<void> _pump(WidgetTester tester, Widget child, String location) async {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: location, builder: (_, _) => child),
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
}

void main() {
  group('event model', () {
    test('parses an event, including SQLite timestamps without a T', () {
      final event = WeaEvent.fromMap(_summitMap());

      expect(event.slug, 'africa-trade-and-investment-summit');
      expect(event.format, EventFormat.hybrid);
      expect(event.startsAt, DateTime(2026, 9, 25, 9));
      expect(event.isPaid, isTrue);
      expect(event.feeLabel, '₦250,000');
    });

    test('a zero fee reads as free rather than as an amount', () {
      final event = WeaEvent.fromMap({..._summitMap(), 'fee_amount': 0});

      expect(event.isPaid, isFalse);
      expect(event.feeLabel, 'Free to attend');
    });

    test('formats money per currency, grouping digits', () {
      expect(formatMoney(250000, 'NGN'), '₦250,000');
      expect(formatMoney(1250.5, 'USD'), r'$1,250.50');
      expect(formatMoney(99, 'KES'), 'KES 99');
    });

    test('describes when an event runs, omitting what is not known', () {
      expect(
        formatEventWhen(DateTime(2026, 9, 25, 9), DateTime(2026, 9, 25, 17), 'WAT'),
        '25 September 2026 · 09:00–17:00 WAT',
      );
      // A date with no time should not invent one.
      expect(formatEventWhen(DateTime(2026, 9, 25), null, 'WAT'), '25 September 2026');
      expect(formatEventWhen(null, null, 'WAT'), 'Date to be announced');
    });
  });

  group('registration state', () {
    test('a paid, completed registration is confirmed', () {
      final registration = EventRegistration.fromMap({
        'id': 'evtreg-1',
        'reference': 'WEA-EVT-2026-00123',
        'event_id': 'evt-1',
        'first_name': 'John',
        'last_name': 'Williams',
        'email': 'john@example.com',
        'status': 'COMPLETED',
        'payment_status': 'PAID',
        'amount': 250000,
        'currency': 'NGN',
      });

      expect(registration.isConfirmed, isTrue);
      expect(registration.requiresPayment, isTrue);
      expect(registration.amountLabel, '₦250,000');
    });

    test('an abandoned registration is kept, and is not confirmed', () {
      final registration = EventRegistration.fromMap({
        'reference': 'WEA-EVT-2026-00124',
        'first_name': 'Jane',
        'last_name': 'Smith',
        'email': 'jane@example.com',
        'phone': '0801234567',
        'status': 'ABANDONED',
        'payment_status': 'PENDING',
        'amount': 250000,
        'currency': 'NGN',
      });

      // The whole point of the abandoned state: the details survive.
      expect(registration.phone, '0801234567');
      expect(registration.isConfirmed, isFalse);
      expect(registration.status.label, 'Abandoned');
    });

    test('a free event needs no payment to be confirmed', () {
      final registration = EventRegistration.fromMap({
        'reference': 'WEA-EVT-2026-00125',
        'status': 'COMPLETED',
        'payment_status': 'NOT_REQUIRED',
        'amount': 0,
      });

      expect(registration.requiresPayment, isFalse);
      expect(registration.isConfirmed, isTrue);
    });

    test('only a verified payment counts as settled', () {
      expect(EventPaymentStatus.paid.settled, isTrue);
      expect(EventPaymentStatus.notRequired.settled, isTrue);
      // Everything short of verification does not entitle anybody to anything.
      expect(EventPaymentStatus.pending.settled, isFalse);
      expect(EventPaymentStatus.processing.settled, isFalse);
      expect(EventPaymentStatus.failed.settled, isFalse);
      expect(EventPaymentStatus.refunded.settled, isFalse);
    });

    test('a payment outcome distinguishes success, pending and failure', () {
      final paid = EventPaymentOutcome.fromMap({
        'status': 'PAID',
        'registration_status': 'COMPLETED',
        'payment_status': 'PAID',
      });
      final failed = EventPaymentOutcome.fromMap({
        'status': 'FAILED',
        'registration_status': 'PAYMENT_FAILED',
        'payment_status': 'FAILED',
        'reason': 'Card declined',
      });

      expect(paid.succeeded, isTrue);
      expect(failed.succeeded, isFalse);
      expect(failed.pending, isFalse);
      expect(failed.reason, 'Card declined');
    });
  });

  group('registration draft', () {
    test('a partial save is marked partial, so required answers are not enforced', () {
      const draft = EventRegistrationDraft(
        firstName: 'John',
        lastName: 'Williams',
        email: 'john@example.com',
      );

      expect(draft.toMap()['stage'], 'PARTIAL');
    });

    test('the final save is marked complete and carries campaign attribution', () {
      const draft = EventRegistrationDraft(
        firstName: 'John',
        lastName: 'Williams',
        email: 'john@example.com',
        phone: '0801234567',
        complete: true,
        campaign: {'utm_source': 'linkedin', 'utm_campaign': 'summit-2026'},
      );
      final map = draft.toMap();

      expect(map['stage'], 'COMPLETE');
      expect(map['utm_source'], 'linkedin');
      expect(map['utm_campaign'], 'summit-2026');
      // Never sent: the amount is decided by the server from the event row.
      expect(map.containsKey('amount'), isFalse);
    });
  });

  group('registration context', () {
    test('reuses what WEA already holds instead of asking again', () {
      final context = EventRegistrationContext.fromMap({
        'event': _summitMap(),
        'known': {
          'first_name': 'John',
          'last_name': 'Williams',
          'email': 'john@example.com',
          'phone': '0801234567',
          'organisation': 'Trade Board',
        },
        'fields': [
          {
            'id': 'evtfield-1',
            'field_key': 'dietary',
            'label': 'Dietary requirements',
            'field_type': 'TEXT',
            'required': 0,
            'prefill': 'Vegetarian',
          },
        ],
        'registration_open': true,
      });

      expect(context.isReturning, isTrue);
      expect(context.firstName, 'John');
      expect(context.fields.single.prefill, 'Vegetarian');
      expect(context.registrationOpen, isTrue);
    });

    test('a closed event says so, with the reason', () {
      final context = EventRegistrationContext.fromMap({
        'event': _summitMap(),
        'known': const {},
        'fields': const [],
        'registration_open': false,
        'closed_reason': 'EVENT_FULL',
      });

      expect(context.registrationOpen, isFalse);
      expect(context.closedReason, 'EVENT_FULL');
    });
  });

  group('participant entitlement', () {
    test('an unpaid registration is not entitled to participant material', () {
      final dashboard = EventDashboard.fromMap({
        'event': _summitMap(),
        'registration': {
          'reference': 'WEA-EVT-2026-00126',
          'status': 'PAYMENT_PENDING',
          'payment_status': 'PENDING',
          'amount': 250000,
        },
        // The API withholds participant material rather than flagging it, so
        // an unpaid dashboard simply has less in it.
        'materials': const [],
        'sessions': const [],
        'entitled': false,
      });

      expect(dashboard.entitled, isFalse);
      expect(dashboard.materials, isEmpty);
    });

    test('a live session is surfaced only when the host has opened it', () {
      final dashboard = EventDashboard.fromMap({
        'event': _summitMap(),
        'registration': {'reference': 'r', 'payment_status': 'PAID'},
        'materials': const [],
        'sessions': [
          {'id': 'evtses-1', 'title': 'Opening', 'is_live': 0},
          {'id': 'evtses-2', 'title': 'Panel', 'is_live': 1},
        ],
        'entitled': true,
      });

      expect(dashboard.liveNow?.id, 'evtses-2');
      // No join link ever reaches the client through the dashboard payload.
      expect(dashboard.sessions.first.recordingUrl, isNull);
    });
  });

  group('administration', () {
    test('revenue counts only what was verified', () {
      final overview = EventOverview.fromMap({
        'total_attempts': 324,
        'completed': 187,
        'payment_pending': 43,
        'abandoned': 71,
        'payment_failed': 23,
        'revenue': [
          {'currency': 'NGN', 'total': 46750000},
        ],
      });

      expect(overview.totalAttempts, 324);
      expect(overview.abandoned, 71);
      expect(overview.revenue['NGN'], 46750000);
    });

    test('a registrant who did not pay is a lead, not a loss', () {
      final lead = EventRegistrant.fromMap({
        'id': 'evtreg-2',
        'reference': 'WEA-EVT-2026-00127',
        'first_name': 'Jane',
        'last_name': 'Smith',
        'email': 'jane@example.com',
        'phone': '0812345678',
        'status': 'ABANDONED',
        'payment_status': 'PENDING',
      });
      final paid = EventRegistrant.fromMap({
        'id': 'evtreg-3',
        'first_name': 'Michael',
        'last_name': 'Brown',
        'status': 'COMPLETED',
        'payment_status': 'PAID',
      });

      expect(lead.isLead, isTrue);
      expect(lead.phone, '0812345678');
      expect(paid.isLead, isFalse);
    });

    test('a funnel with no visitors reports no rate rather than zero', () {
      final funnel = EventFunnel.fromMap({
        'landing_page_visitors': 0,
        'conversion_rate': null,
      });

      expect(funnel.conversionRate, isNull);
    });
  });

  group('share links', () {
    test('carries the channel so a registration can be attributed to it', () {
      final url = buildShareUrl(
        kind: 'event',
        slug: 'africa-trade-and-investment-summit',
        utmSource: 'linkedin',
        campaign: 'summit-2026',
      );

      expect(url, contains('utm_source=linkedin'));
      expect(url, contains('utm_medium=social'));
      expect(url, contains('utm_campaign=summit-2026'));
      expect(url, contains('africa-trade-and-investment-summit'));
    });
  });

  group('route protection', () {
    const guest = AuthUnauthenticated();
    const learner = Authenticated(
      UserProfile(
        id: 'u1',
        email: 'learner@example.com',
        firstName: 'Ada',
        lastName: 'Obi',
        role: UserRole.learner,
        status: AccountStatus.active,
        emailVerified: true,
      ),
    );

    test('event pages and registration are open to a signed-out visitor', () {
      // Requiring an account before somebody can register is precisely what
      // loses registrations, so these must not redirect.
      expect(guardLocation(guest, '/events'), isNull);
      expect(guardLocation(guest, '/events/africa-trade-summit'), isNull);
      expect(guardLocation(guest, '/events/africa-trade-summit/register'), isNull);
      expect(
        guardLocation(guest, '/events/registration/WEA-EVT-2026-00123'),
        isNull,
      );
    });

    test('a learner may reach an event page without leaving their area', () {
      expect(guardLocation(learner, '/events'), isNull);
      expect(guardLocation(learner, '/events/africa-trade-summit'), isNull);
    });

    test('event administration is still Super Admin only', () {
      expect(guardLocation(learner, '/super-admin/content'), '/learner');
      expect(guardLocation(guest, '/super-admin/content'), '/login');
    });
  });

  group('offline backend', () {
    test('saving twice for one address updates the registration, never doubles it', () async {
      final repository = OfflineEventsRepository();
      const slug = 'africa-trade-and-investment-summit';

      final first = await repository.saveRegistration(
        slug,
        const EventRegistrationDraft(
          firstName: 'John',
          lastName: 'Williams',
          email: 'john@example.com',
        ),
      );
      final second = await repository.saveRegistration(
        slug,
        const EventRegistrationDraft(
          firstName: 'John',
          lastName: 'Williams',
          email: 'john@example.com',
          phone: '0801234567',
          complete: true,
        ),
      );

      expect(second.registration.reference, first.registration.reference);
      expect(second.registration.phone, '0801234567');
      expect((await repository.registrants()).length, 1);
    });

    test('a half-finished registration is still visible to the academy', () async {
      final repository = OfflineEventsRepository();
      await repository.saveRegistration(
        'africa-trade-and-investment-summit',
        const EventRegistrationDraft(
          firstName: 'Jane',
          lastName: 'Smith',
          email: 'jane@example.com',
        ),
      );

      final leads = await repository.registrants();
      expect(leads.single.name, 'Jane Smith');
      expect(leads.single.isLead, isTrue);
    });

    test('verification never reports success without a processor to ask', () async {
      final repository = OfflineEventsRepository();
      final saved = await repository.saveRegistration(
        'africa-trade-and-investment-summit',
        const EventRegistrationDraft(
          firstName: 'John',
          lastName: 'Williams',
          email: 'john@example.com',
          phone: '0801234567',
          complete: true,
        ),
      );

      final outcome = await repository.verifyPayment(saved.registration.reference);
      expect(outcome.succeeded, isFalse);
    });
  });

  group('screens', () {
    testWidgets('the calendar lists published events with their fee', (tester) async {
      await mockNetworkImagesFor(
        () => _pump(tester, const EventsScreen(), '/events'),
      );

      expect(find.text('Africa Trade and Investment Summit'), findsOneWidget);
      expect(find.text('₦250,000'), findsOneWidget);
      expect(find.text('Free to attend'), findsOneWidget);
    });

    testWidgets('an event page states the fee and offers registration', (tester) async {
      await mockNetworkImagesFor(
        () => _pump(
          tester,
          const EventDetailScreen(slug: 'africa-trade-and-investment-summit'),
          '/events/africa-trade-and-investment-summit',
        ),
      );

      expect(find.text('REGISTER NOW'), findsWidgets);
      expect(find.textContaining('250,000'), findsWidgets);
    });

    testWidgets('registration asks only for the essentials first', (tester) async {
      await mockNetworkImagesFor(
        () => _pump(
          tester,
          const EventRegistrationScreen(slug: 'africa-trade-and-investment-summit'),
          '/events/africa-trade-and-investment-summit/register',
        ),
      );

      expect(find.text('First name'), findsOneWidget);
      expect(find.text('Last name'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      // Deliberately not on the first screen: the form stays short.
      expect(find.text('Phone number'), findsNothing);
      expect(find.text('CONTINUE'), findsOneWidget);
    });

    testWidgets('a missing registration is reported, not invented', (tester) async {
      await mockNetworkImagesFor(
        () => _pump(
          tester,
          const EventDashboardScreen(reference: 'WEA-EVT-2026-99999'),
          '/events/registration/WEA-EVT-2026-99999',
        ),
      );

      expect(find.textContaining('no longer available'), findsOneWidget);
    });
  });
}
