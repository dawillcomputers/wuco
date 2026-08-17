import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/session_store.dart';
import '../domain/event_models.dart';
import 'events_repository.dart';
import 'registration_token_store.dart';

/// The Worker-backed events client.
///
/// Nothing here is a security control. The API decides what is published, who
/// owns a registration and whether a payment happened; this class only asks.
/// In particular it never computes a fee and never concludes that a payment
/// succeeded — both come back from the server or not at all.
class ApiEventsRepository
    implements EventsRepository, EventsAdminRepository, SiteAnalyticsRepository {
  ApiEventsRepository({
    required String baseUrl,
    required SessionStore sessionStore,
    required RegistrationTokenStore tokenStore,
    http.Client? client,
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _sessions = sessionStore,
       _tokens = tokenStore,
       _client = client ?? http.Client();

  final String _baseUrl;
  final SessionStore _sessions;
  final RegistrationTokenStore _tokens;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse(
    '$_baseUrl$path',
  ).replace(queryParameters: query == null || query.isEmpty ? null : query);

  Future<Map<String, String>> _headers({String? reference}) async {
    final token = await _sessions.read();
    // A guest proves ownership with the token issued when the registration was
    // created. Sent as a header rather than in the URL so it does not end up in
    // a browser history or a server log.
    final resume = reference == null ? null : await _tokens.read(reference);
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      'X-Registration-Token': ?resume,
    };
  }

  EventFailure _mapError(int status, Map<String, dynamic> body) {
    final code = (body['error'] as Map?)?['code'] as String? ?? '';
    final detail = (body['error'] as Map?)?['message'] as String?;
    return switch (code) {
      'NOT_FOUND' => EventFailure(EventFailureKind.notFound, detail),
      'NOT_AUTHORISED' || 'SESSION_EXPIRED' => EventFailure(
        EventFailureKind.notAuthorised,
        detail,
      ),
      'ACCOUNT_REQUIRED' => EventFailure(EventFailureKind.accountRequired, detail),
      'REGISTRATION_CLOSED' || 'REGISTRATION_NOT_OPEN' => EventFailure(
        EventFailureKind.registrationClosed,
        detail,
      ),
      'EVENT_FULL' => EventFailure(EventFailureKind.eventFull, detail),
      'MISSING_ANSWER' => EventFailure(EventFailureKind.missingAnswer, detail),
      'INVALID_EMAIL' => EventFailure(EventFailureKind.invalidEmail, detail),
      'ALREADY_PAID' => EventFailure(EventFailureKind.alreadyPaid, detail),
      'PAYMENT_REQUIRED' => EventFailure(EventFailureKind.paymentRequired, detail),
      'PAYMENT_INITIALISATION_FAILED' || 'PAYMENT_NOT_REQUIRED' => EventFailure(
        EventFailureKind.paymentFailed,
        detail,
      ),
      'SESSION_NOT_LIVE' || 'SESSION_NOT_READY' => EventFailure(
        EventFailureKind.sessionNotLive,
        detail,
      ),
      _ => EventFailure(
        status >= 500 ? EventFailureKind.server : EventFailureKind.invalidRequest,
        detail,
      ),
    };
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    String? reference,
  }) async {
    late http.Response response;
    try {
      final uri = _uri(path, query);
      final headers = await _headers(reference: reference);
      final encoded = body == null ? null : jsonEncode(body);
      response = switch (method) {
        'GET' => await _client.get(uri, headers: headers),
        'POST' => await _client.post(uri, headers: headers, body: encoded),
        'PATCH' => await _client.patch(uri, headers: headers, body: encoded),
        'DELETE' => await _client.delete(uri, headers: headers),
        _ => throw ArgumentError('Unsupported method $method'),
      };
    } catch (_) {
      throw const EventFailure(EventFailureKind.network);
    }

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw _mapError(response.statusCode, decoded);
    }
    return decoded;
  }

  List<Map<String, dynamic>> _rows(Object? value) => [
    for (final row in (value as List? ?? const []))
      Map<String, dynamic>.from(row as Map),
  ];

  // --- Public ---------------------------------------------------------------

  @override
  Future<List<WeaEvent>> events({
    bool upcomingOnly = false,
    bool featuredOnly = false,
    String? query,
  }) async {
    final response = await _send(
      'GET',
      '/api/events',
      query: {
        if (upcomingOnly) 'upcoming': 'true',
        if (featuredOnly) 'featured': 'true',
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    return _rows(response['events']).map(WeaEvent.fromMap).toList();
  }

  @override
  Future<EventDetail> event(String slug) async =>
      EventDetail.fromMap(await _send('GET', '/api/events/$slug'));

  // --- Registration ---------------------------------------------------------

  @override
  Future<EventRegistrationContext> registrationContext(String slug) async =>
      EventRegistrationContext.fromMap(
        await _send('GET', '/api/events/$slug/registration-context'),
      );

  @override
  Future<SavedRegistration> saveRegistration(
    String slug,
    EventRegistrationDraft draft,
  ) async {
    final response = await _send(
      'POST',
      '/api/events/$slug/registrations',
      body: draft.toMap(),
    );
    final registration = EventRegistration.fromMap(
      Map<String, dynamic>.from(response['registration'] as Map),
    );
    final resumeToken = response['resume_token'] as String?;
    if (resumeToken != null && resumeToken.isNotEmpty) {
      await _tokens.write(registration.reference, resumeToken);
    }

    // The API signs a new registrant in as part of completing. Persisting the
    // token here is what makes them signed in on the next screen.
    final session = response['session'] as Map?;
    final sessionToken = session?['token'] as String?;
    if (sessionToken != null && sessionToken.isNotEmpty) {
      await _sessions.write(sessionToken);
    }

    return SavedRegistration(
      registration: registration,
      resumeToken: resumeToken,
      temporaryPassword: response['temporary_password'] as String?,
      signedIn: sessionToken != null && sessionToken.isNotEmpty,
    );
  }

  @override
  Future<EventPaymentOptions> paymentMethods(
    String slug, {
    String? attendanceMode,
  }) async => EventPaymentOptions.fromMap(
    await _send(
      'GET',
      '/api/events/$slug/payment-methods',
      query: {
        // Which rate applies follows from the date, and which currency from
        // where the request came from — both decided server-side. This only
        // says how the registrant is attending.
        if (attendanceMode != null && attendanceMode.isNotEmpty)
          'attendance_mode': attendanceMode,
      },
    ),
  );

  @override
  Future<EventPaymentIntent> beginPayment(
    String reference, {
    String? methodKey,
    String? attendanceMode,
  }) async => EventPaymentIntent.fromMap(
    await _send(
      'POST',
      '/api/events/registrations/$reference/payment',
      body: {
        'payment_method': methodKey ?? '',
        // The server decides the amount, the rate and the currency. All this
        // says is how the registrant is attending.
        'attendance_mode': attendanceMode ?? '',
      },
      reference: reference,
    ),
  );

  @override
  Future<EventPaymentOutcome> verifyPayment(
    String reference, {
    String? paymentReference,
    String? transactionId,
  }) async => EventPaymentOutcome.fromMap(
    await _send(
      'POST',
      '/api/events/registrations/$reference/verify',
      body: {
        'payment_reference': paymentReference ?? '',
        // Flutterwave puts this on the return URL. It is what the API
        // verifies against — a browser saying "it worked" is only a hint that
        // it is worth asking.
        'transaction_id': transactionId ?? '',
      },
      reference: reference,
    ),
  );

  @override
  Future<EventDashboard> dashboard(String reference) async =>
      EventDashboard.fromMap(
        await _send(
          'GET',
          '/api/events/registrations/$reference',
          reference: reference,
        ),
      );

  @override
  Future<String> joinSession(String reference, String sessionId) async {
    final response = await _send(
      'POST',
      '/api/events/registrations/$reference/sessions/$sessionId/join',
      reference: reference,
    );
    return '${response['join_url'] ?? ''}';
  }

  @override
  Future<List<MyEventRegistration>> myRegistrations() async {
    final response = await _send('GET', '/api/my/event-registrations');
    return _rows(response['registrations']).map(MyEventRegistration.fromMap).toList();
  }

  // --- Administration -------------------------------------------------------

  @override
  Future<List<EventRegistrant>> registrants({
    String? eventId,
    String? status,
    String? paymentStatus,
    String? query,
  }) async {
    final response = await _send(
      'GET',
      '/api/admin/event-registrations',
      query: {
        if (eventId != null && eventId.isNotEmpty) 'event_id': eventId,
        if (status != null && status.isNotEmpty) 'status': status,
        if (paymentStatus != null && paymentStatus.isNotEmpty)
          'payment_status': paymentStatus,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    return _rows(response['registrations']).map(EventRegistrant.fromMap).toList();
  }

  @override
  Future<(EventOverview, EventFunnel)> overview({String? eventId}) async {
    final response = await _send(
      'GET',
      '/api/admin/event-overview',
      query: {if (eventId != null && eventId.isNotEmpty) 'event_id': eventId},
    );
    return (
      EventOverview.fromMap(
        Map<String, dynamic>.from(response['overview'] as Map? ?? const {}),
      ),
      EventFunnel.fromMap(
        Map<String, dynamic>.from(response['funnel'] as Map? ?? const {}),
      ),
    );
  }

  @override
  Future<void> setRegistrationStatus(
    String registrationId, {
    required EventRegistrationStatus status,
    String note = '',
  }) => _send(
    'PATCH',
    '/api/admin/event-registrations/$registrationId',
    body: {'status': status.wireName, 'note': note},
  );

  @override
  Future<int> sweepAbandoned() async {
    final response = await _send('POST', '/api/admin/event-registrations/sweep');
    return (response['updated'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<String> exportRegistrations({String? eventId}) async {
    // CSV rather than JSON, so this bypasses the shared decoder.
    late http.Response response;
    try {
      response = await _client.get(
        _uri('/api/admin/event-registrations/export', {
          if (eventId != null && eventId.isNotEmpty) 'event_id': eventId,
        }),
        headers: await _headers(),
      );
    } catch (_) {
      throw const EventFailure(EventFailureKind.network);
    }
    if (response.statusCode >= 400) {
      throw _mapError(response.statusCode, const {});
    }
    return response.body;
  }

  // --- Analytics ------------------------------------------------------------

  /// Reporting must never break the page it is measuring, so every failure
  /// here is swallowed rather than surfaced.
  Future<void> _report(String path, Map<String, dynamic> body) async {
    try {
      await _send('POST', path, body: body);
    } catch (_) {
      // Intentionally ignored.
    }
  }

  @override
  Future<void> recordPageView({
    required String path,
    String title = '',
    String? eventId,
    Map<String, String> campaign = const {},
  }) => _report('/api/analytics/page-view', {
    'path': path,
    'title': title,
    'event_id': eventId ?? '',
    ...campaign,
  });

  @override
  Future<void> recordFunnelEvent({
    required String name,
    String path = '',
    String? eventId,
    String? registrationId,
    Map<String, String> campaign = const {},
  }) => _report('/api/analytics/event', {
    'name': name,
    'path': path,
    'event_id': eventId ?? '',
    'registration_id': registrationId ?? '',
    ...campaign,
  });

  @override
  Future<Map<String, dynamic>> siteAnalytics({int days = 30}) =>
      _send('GET', '/api/admin/analytics', query: {'days': '$days'});

  @override
  Future<Map<String, dynamic>> shareLinks() =>
      _send('GET', '/api/admin/share-links/performance');
}
