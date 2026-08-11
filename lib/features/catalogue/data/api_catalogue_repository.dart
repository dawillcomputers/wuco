import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/session_store.dart';
import '../domain/catalogue_models.dart';
import '../domain/registration_models.dart';
import 'catalogue_repository.dart';

/// Talks to the Worker catalogue API.
///
/// The Worker decides what is published and who may edit it; nothing here is a
/// security control. Draft content is never sent to this client, so it cannot
/// be revealed by tampering with the app.
class ApiCatalogueRepository
    implements CatalogueRepository, CatalogueAdminRepository {
  ApiCatalogueRepository({
    required String baseUrl,
    required SessionStore sessionStore,
    http.Client? client,
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _sessions = sessionStore,
       _client = client ?? http.Client();

  final String _baseUrl;
  final SessionStore _sessions;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse(
    '$_baseUrl$path',
  ).replace(queryParameters: query == null || query.isEmpty ? null : query);

  Future<Map<String, String>> _headers() async {
    final token = await _sessions.read();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  CatalogueFailure _mapError(int status, Map<String, dynamic> body) {
    final code = (body['error'] as Map?)?['code'] as String? ?? '';
    final detail = (body['error'] as Map?)?['message'] as String?;
    return switch (code) {
      'NOT_FOUND' => CatalogueFailure(CatalogueFailureKind.notFound, detail),
      'NOT_AUTHORISED' || 'SESSION_EXPIRED' => CatalogueFailure(
        CatalogueFailureKind.notAuthorised,
        detail,
      ),
      'ALREADY_REGISTERED' => CatalogueFailure(
        CatalogueFailureKind.alreadyRegistered,
        detail,
      ),
      'REGISTRATION_CLOSED' => CatalogueFailure(
        CatalogueFailureKind.registrationClosed,
        detail,
      ),
      'MISSING_ANSWER' => CatalogueFailure(
        CatalogueFailureKind.missingAnswer,
        detail,
      ),
      'INVALID_REQUEST' ||
      'INVALID_STATUS' ||
      'INVALID_PAYMENT_METHOD' ||
      'UNSUPPORTED_TYPE' ||
      'FILE_TOO_LARGE' => CatalogueFailure(
        CatalogueFailureKind.invalidRequest,
        detail,
      ),
      _ => CatalogueFailure(
        status >= 500
            ? CatalogueFailureKind.server
            : CatalogueFailureKind.invalidRequest,
        detail,
      ),
    };
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    late http.Response response;
    try {
      final uri = _uri(path, query);
      final headers = await _headers();
      final encoded = body == null ? null : jsonEncode(body);
      response = switch (method) {
        'GET' => await _client.get(uri, headers: headers),
        'POST' => await _client.post(uri, headers: headers, body: encoded),
        'PUT' => await _client.put(uri, headers: headers, body: encoded),
        'PATCH' => await _client.patch(uri, headers: headers, body: encoded),
        'DELETE' => await _client.delete(uri, headers: headers),
        _ => throw ArgumentError('Unsupported method $method'),
      };
    } catch (_) {
      throw const CatalogueFailure(CatalogueFailureKind.network);
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

  // --- Public reads ---------------------------------------------------------

  @override
  Future<CatalogueOverview> overview() async =>
      CatalogueOverview.fromMap(await _send('GET', '/api/catalogue'));

  @override
  Future<AreaDetail> area(String slug) async =>
      AreaDetail.fromMap(await _send('GET', '/api/catalogue/areas/$slug'));

  @override
  Future<List<CatalogueProgramme>> programmes({
    String? area,
    String? type,
    String? query,
    bool featuredOnly = false,
    int? limit,
  }) async {
    final response = await _send(
      'GET',
      '/api/catalogue/programmes',
      query: {
        if (area != null && area.isNotEmpty) 'area': area,
        if (type != null && type.isNotEmpty) 'type': type,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (featuredOnly) 'featured': 'true',
        if (limit != null) 'limit': '$limit',
      },
    );
    return _rows(response['programmes']).map(CatalogueProgramme.fromMap).toList();
  }

  @override
  Future<ProgrammeDetail> programme(String slug) async =>
      ProgrammeDetail.fromMap(await _send('GET', '/api/catalogue/programmes/$slug'));

  @override
  Future<List<FacultyProfile>> faculty() async {
    final response = await _send('GET', '/api/catalogue/faculty');
    return _rows(response['faculty']).map(FacultyProfile.fromMap).toList();
  }

  @override
  Future<List<PaymentMethod>> paymentMethods() async {
    final response = await _send('GET', '/api/payment-methods');
    return _rows(response['payment_methods']).map(PaymentMethod.fromMap).toList();
  }

  // --- Registration ---------------------------------------------------------

  @override
  Future<RegistrationContext> registrationContext(String programmeId) async =>
      RegistrationContext.fromMap(
        await _send(
          'GET',
          '/api/registrations/context',
          query: {'programme_id': programmeId},
        ),
      );

  @override
  Future<RegistrationRecord> register({
    required String programmeId,
    required Map<String, String> answers,
    String? paymentMethodId,
  }) async {
    final response = await _send(
      'POST',
      '/api/registrations',
      body: {
        'programme_id': programmeId,
        'answers': answers,
        'payment_method_id': ?paymentMethodId,
      },
    );
    return RegistrationRecord.fromMap(
      Map<String, dynamic>.from(response['registration'] as Map),
    );
  }

  @override
  Future<List<RegistrationRecord>> myRegistrations() async {
    final response = await _send('GET', '/api/registrations');
    return _rows(response['registrations']).map(RegistrationRecord.fromMap).toList();
  }

  // --- Administration -------------------------------------------------------

  @override
  Future<List<Map<String, dynamic>>> list(
    String resource, {
    Map<String, String>? filters,
  }) async {
    final response = await _send(
      'GET',
      '/api/admin/$resource',
      query: filters,
    );
    return _rows(response['items']);
  }

  @override
  Future<Map<String, dynamic>> create(
    String resource,
    Map<String, dynamic> values,
  ) async {
    final response = await _send('POST', '/api/admin/$resource', body: values);
    return Map<String, dynamic>.from(response['item'] as Map);
  }

  @override
  Future<Map<String, dynamic>> update(
    String resource,
    String id,
    Map<String, dynamic> values,
  ) async {
    final response = await _send(
      'PATCH',
      '/api/admin/$resource/$id',
      body: values,
    );
    return Map<String, dynamic>.from(response['item'] as Map);
  }

  @override
  Future<void> delete(String resource, String id) =>
      _send('DELETE', '/api/admin/$resource/$id');

  @override
  Future<void> reorder(String resource, List<String> ids) =>
      _send('POST', '/api/admin/$resource/reorder', body: {'ids': ids});

  @override
  Future<String> uploadImage({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    // Sent as a raw body rather than multipart: the Worker accepts both, and
    // this avoids pulling a multipart encoder into the web bundle.
    final token = await _sessions.read();
    late http.Response response;
    try {
      response = await _client.post(
        _uri('/api/admin/media'),
        headers: {
          'Content-Type': contentType,
          'X-Filename': filename,
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: bytes,
      );
    } catch (_) {
      throw const CatalogueFailure(CatalogueFailureKind.network);
    }
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw _mapError(response.statusCode, decoded);
    }
    return (decoded['asset'] as Map)['key'] as String;
  }

  @override
  Future<List<Map<String, dynamic>>> mediaLibrary() async {
    final response = await _send('GET', '/api/admin/media');
    return _rows(response['assets']);
  }

  @override
  Future<void> setProgrammeFaculty(
    String programmeId,
    List<String> facultyIds,
  ) => _send(
    'PUT',
    '/api/admin/programme-faculty',
    body: {'programme_id': programmeId, 'faculty_ids': facultyIds},
  );

  @override
  Future<List<RegistrationRecord>> registrations({String? status}) async {
    final response = await _send(
      'GET',
      '/api/admin/registrations',
      query: {'status': ?status},
    );
    return _rows(response['registrations']).map(RegistrationRecord.fromMap).toList();
  }

  @override
  Future<void> reviewRegistration(
    String registrationId, {
    required RegistrationStatus status,
    String note = '',
  }) => _send(
    'PATCH',
    '/api/admin/registrations/$registrationId',
    body: {'status': status.wireName, 'review_note': note},
  );

  @override
  Future<Map<String, String>> settings() async {
    final response = await _send('GET', '/api/admin/settings');
    return {
      for (final row in _rows(response['settings']))
        '${row['key']}': '${row['value'] ?? ''}',
    };
  }

  @override
  Future<void> saveSettings(Map<String, String> values) =>
      _send('PUT', '/api/admin/settings', body: values);
}
