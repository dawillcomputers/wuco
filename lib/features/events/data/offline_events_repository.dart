import '../domain/event_models.dart';
import 'events_repository.dart';

/// In-memory events backend used when no API is configured.
///
/// It exists so the whole event experience — landing page, registration,
/// abandonment, payment, dashboard — can be walked through offline. It holds a
/// demonstration event rather than real content, and no money moves: a payment
/// here settles the way a bank transfer does, by staying pending until the
/// academy confirms it.
class OfflineEventsRepository
    implements EventsRepository, EventsAdminRepository, SiteAnalyticsRepository {
  OfflineEventsRepository() {
    _events.addAll([
      WeaEvent.fromMap({
        'id': 'evt-demo-summit',
        'slug': 'africa-trade-and-investment-summit',
        'title': 'Africa Trade and Investment Summit',
        'subtitle': 'Cross-border growth under AfCFTA',
        'event_type': 'SUMMIT',
        'summary':
            'A one-day executive summit on trade corridors, investment '
            'attraction and cross-border commercial practice across Africa.',
        'starts_at': '2026-09-25T09:00:00',
        'ends_at': '2026-09-25T17:00:00',
        'timezone': 'WAT',
        'venue': 'Lagos Continental, Victoria Island',
        'format': 'HYBRID',
        'fee_amount': 250000,
        'fee_currency': 'NGN',
        'status': 'PUBLISHED',
        'featured': 1,
        'capacity': 300,
      }),
      WeaEvent.fromMap({
        'id': 'evt-demo-masterclass',
        'slug': 'ai-governance-executive-masterclass',
        'title': 'AI Governance Executive Masterclass',
        'subtitle': 'Responsible adoption for boards and regulators',
        'event_type': 'MASTERCLASS',
        'summary':
            'A live online masterclass on governing artificial intelligence '
            'in regulated markets.',
        'starts_at': '2026-10-14T14:00:00',
        'ends_at': '2026-10-14T17:00:00',
        'timezone': 'WAT',
        'venue': 'Live online',
        'format': 'ONLINE',
        'fee_amount': 0,
        'fee_currency': 'NGN',
        'status': 'PUBLISHED',
        'featured': 0,
      }),
    ]);
  }

  final _events = <WeaEvent>[];
  final _registrations = <String, EventRegistration>{};
  var _sequence = 0;

  WeaEvent _find(String slug) => _events.firstWhere(
    (event) => event.slug == slug || event.id == slug,
    orElse: () => throw const EventFailure(EventFailureKind.notFound),
  );

  @override
  Future<List<WeaEvent>> events({
    bool upcomingOnly = false,
    bool featuredOnly = false,
    String? query,
  }) async {
    final search = (query ?? '').trim().toLowerCase();
    return [
      for (final event in _events)
        if ((!featuredOnly || event.featured) &&
            (search.isEmpty || event.title.toLowerCase().contains(search)))
          event,
    ];
  }

  @override
  Future<EventDetail> event(String slug) async {
    final event = _find(slug);
    return EventDetail(
      event: event,
      description:
          'This is a demonstration event served by the offline development '
          'backend. Published events, their pricing and their materials are '
          'created by a Super Admin against the live API.',
      whyAttend:
          'Meet the executives shaping cross-border trade, and leave with a '
          'practical view of where the opportunities actually are.',
      whoShouldAttend:
          'Executives, trade professionals, investment officers, regulators '
          'and senior advisers.',
      agenda: const [
        EventAgendaItem(time: '09:00', title: 'Registration and coffee', detail: ''),
        EventAgendaItem(time: '10:00', title: 'Opening address', detail: ''),
        EventAgendaItem(time: '11:30', title: 'Trade corridors panel', detail: ''),
        EventAgendaItem(time: '14:00', title: 'Investment roundtables', detail: ''),
      ],
      materials: const [],
      sessions: const [],
      contactEmail: 'enquiries@wucoacademy.org',
      contactPhone: '',
      terms: '',
      paymentInstructions:
          'Payment instructions are configured by the academy against the live API.',
      confirmedRegistrations: 0,
      placesRemaining: event.capacity,
      registrationOpen: true,
      allowGuestRegistration: true,
      registrationClosesAt: null,
    );
  }

  @override
  Future<EventRegistrationContext> registrationContext(String slug) async {
    final event = _find(slug);
    return EventRegistrationContext(
      event: event,
      known: const {
        'first_name': '',
        'last_name': '',
        'email': '',
        'phone': '',
        'organisation': '',
        'job_title': '',
        'country': '',
      },
      fields: const [],
      registrationOpen: true,
      closedReason: null,
    );
  }

  @override
  Future<SavedRegistration> saveRegistration(
    String slug,
    EventRegistrationDraft draft,
  ) async {
    final event = _find(slug);
    final existing = _registrations.values
        .where((row) => row.eventId == event.id && row.email == draft.email)
        .firstOrNull;

    final reference =
        existing?.reference ??
        'WEA-EVT-${DateTime.now().year}-${(++_sequence).toString().padLeft(5, '0')}';
    final paid = existing?.paymentStatus == EventPaymentStatus.paid;

    final registration = EventRegistration(
      id: existing?.id ?? 'evtreg-$reference',
      reference: reference,
      eventId: event.id,
      firstName: draft.firstName,
      lastName: draft.lastName,
      email: draft.email,
      phone: draft.phone.isEmpty ? (existing?.phone ?? '') : draft.phone,
      organisation: draft.organisation.isEmpty
          ? (existing?.organisation ?? '')
          : draft.organisation,
      jobTitle: draft.jobTitle.isEmpty ? (existing?.jobTitle ?? '') : draft.jobTitle,
      country: draft.country.isEmpty ? (existing?.country ?? '') : draft.country,
      answers: {...?existing?.answers, ...draft.answers},
      status: paid
          ? EventRegistrationStatus.completed
          : draft.complete
          ? (event.isPaid
                ? EventRegistrationStatus.paymentPending
                : EventRegistrationStatus.completed)
          : EventRegistrationStatus.started,
      paymentStatus: paid
          ? EventPaymentStatus.paid
          : event.isPaid
          ? EventPaymentStatus.pending
          : EventPaymentStatus.notRequired,
      amount: event.feeAmount,
      currency: event.feeCurrency,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    _registrations[reference] = registration;
    return SavedRegistration(registration: registration, resumeToken: 'offline');
  }

  EventRegistration _registration(String reference) =>
      _registrations[reference] ??
      (throw const EventFailure(EventFailureKind.notFound));

  @override
  Future<EventPaymentOptions> paymentMethods(
    String slug, {
    String? attendanceMode,
    String? country,
  }) async =>
      // Nothing is configured offline, so nothing is offered. Listing methods
      // that cannot complete would be the exact mistake the live path avoids.
      const EventPaymentOptions(methods: [], environment: 'SANDBOX');

  @override
  Future<EventPaymentIntent> beginPayment(
    String reference, {
    String? methodKey,
    String? attendanceMode,
  }) async {
    final registration = _registration(reference);
    return EventPaymentIntent(
      provider: 'MANUAL',
      paymentReference: '$reference-offline',
      amount: registration.amount,
      currency: registration.currency,
      instructions:
          'No payment processor is configured in this build. Against the live '
          'API the academy’s configured processor would take payment here.',
    );
  }

  @override
  Future<EventPaymentOutcome> verifyPayment(
    String reference, {
    String? paymentReference,
    String? transactionId,
  }) async {
    // Nothing to verify offline. Reporting success here would be the exact
    // mistake the live implementation exists to prevent.
    final registration = _registration(reference);
    return EventPaymentOutcome(
      status: 'PENDING',
      registrationStatus: registration.status,
      paymentStatus: registration.paymentStatus,
      reason: 'Awaiting confirmation by the academy office.',
    );
  }

  @override
  Future<EventDashboard> dashboard(String reference) async {
    final registration = _registration(reference);
    final event = _events.firstWhere((row) => row.id == registration.eventId);
    return EventDashboard(
      event: event,
      registration: registration,
      materials: const [],
      sessions: const [],
      entitled: registration.paymentStatus.settled,
      agenda: const [],
      successMessage: '',
    );
  }

  @override
  Future<String> joinSession(String reference, String sessionId) async =>
      throw const EventFailure(EventFailureKind.sessionNotLive);

  @override
  Future<List<MyEventRegistration>> myRegistrations() async => const [];

  // --- Administration -------------------------------------------------------

  @override
  Future<List<EventRegistrant>> registrants({
    String? eventId,
    String? status,
    String? paymentStatus,
    String? query,
  }) async => [
    for (final registration in _registrations.values)
      if (eventId == null || eventId.isEmpty || registration.eventId == eventId)
        EventRegistrant(
          id: registration.id,
          reference: registration.reference,
          eventTitle: _events
              .firstWhere((row) => row.id == registration.eventId)
              .title,
          name: registration.fullName,
          email: registration.email,
          phone: registration.phone,
          organisation: registration.organisation,
          jobTitle: registration.jobTitle,
          country: registration.country,
          status: registration.status,
          paymentStatus: registration.paymentStatus,
          amount: registration.amount,
          currency: registration.currency,
          campaign: '',
          createdAt: registration.createdAt,
          lastActivityAt: registration.createdAt,
          adminNote: '',
        ),
  ];

  @override
  Future<(EventOverview, EventFunnel)> overview({String? eventId}) async {
    final rows = await registrants(eventId: eventId);
    return (
      EventOverview(
        totalAttempts: rows.length,
        completed: rows
            .where((row) => row.status == EventRegistrationStatus.completed)
            .length,
        paymentPending: rows
            .where((row) => row.paymentStatus == EventPaymentStatus.pending)
            .length,
        paymentProcessing: 0,
        paymentFailed: 0,
        abandoned: 0,
        started: rows
            .where((row) => row.status == EventRegistrationStatus.started)
            .length,
        revenue: const {},
      ),
      EventFunnel(
        landingPageViews: 0,
        landingPageVisitors: 0,
        startedRegistration: rows.length,
        completedForm: rows
            .where((row) => row.status != EventRegistrationStatus.started)
            .length,
        paymentAttempts: 0,
        successfulPayments: 0,
        failedPayments: 0,
        abandoned: 0,
        completedRegistrations: rows
            .where((row) => row.status == EventRegistrationStatus.completed)
            .length,
        conversionRate: null,
      ),
    );
  }

  @override
  Future<void> setRegistrationStatus(
    String registrationId, {
    required EventRegistrationStatus status,
    String note = '',
  }) async {}

  @override
  Future<int> sweepAbandoned() async => 0;

  @override
  Future<String> exportRegistrations({String? eventId}) async =>
      'Reference,Name,Email\r\n';

  // --- Analytics ------------------------------------------------------------

  @override
  Future<void> recordPageView({
    required String path,
    String title = '',
    String? eventId,
    Map<String, String> campaign = const {},
  }) async {}

  @override
  Future<void> recordFunnelEvent({
    required String name,
    String path = '',
    String? eventId,
    String? registrationId,
    Map<String, String> campaign = const {},
  }) async {}

  @override
  Future<Map<String, dynamic>> siteAnalytics({int days = 30}) async => {
    'days': days,
    'views': 0,
    'visitors': 0,
    'series': const [],
    'pages': const [],
    'referrers': const [],
    'campaigns': const [],
    'devices': const [],
    'countries': const [],
  };

  @override
  Future<Map<String, dynamic>> shareLinks() async => {
    'links': const [],
    'site_url': '',
    'api_origin': '',
  };
}
