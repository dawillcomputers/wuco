import '../domain/account_status.dart';
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/auth_failure.dart';
import '../domain/password_policy.dart';
import '../domain/programme_enrolment.dart';
import '../domain/user_profile.dart';
import '../domain/user_role.dart';
import 'auth_repository.dart';
import 'session_store.dart';

/// Talks to the Cloudflare Worker API backed by D1.
///
/// The Worker is the authority on credentials, roles and permissions; the
/// checks mirrored here are for a responsive interface, not for security.
class CloudflareAuthRepository implements AuthRepository {
  CloudflareAuthRepository({
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
  final _controller = StreamController<UserProfile?>.broadcast();

  @override
  Stream<UserProfile?> get changes => _controller.stream;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await _sessions.read();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
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
        'PATCH' => await _client.patch(uri, headers: headers, body: encoded),
        'DELETE' => await _client.delete(uri, headers: headers, body: encoded),
        _ => throw ArgumentError('Unsupported method $method'),
      };
    } catch (_) {
      throw const AuthFailure(AuthFailureKind.network);
    }

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw _mapError(response.statusCode, decoded);
    }
    return decoded;
  }

  AuthFailure _mapError(int status, Map<String, dynamic> body) {
    final error = body['error'] as Map<String, dynamic>?;
    final code = error?['code'] as String? ?? '';
    final message = error?['message'] as String?;
    final kind = switch (code) {
      'INVALID_CREDENTIALS' => AuthFailureKind.invalidCredentials,
      'EMAIL_EXISTS' => AuthFailureKind.emailAlreadyRegistered,
      'WEAK_PASSWORD' => AuthFailureKind.weakPassword,
      'EXPIRED_LINK' => AuthFailureKind.expiredLink,
      'INVALID_LINK' => AuthFailureKind.invalidLink,
      'SESSION_EXPIRED' => AuthFailureKind.sessionExpired,
      'NOT_AUTHORISED' => AuthFailureKind.notAuthorised,
      'ACCOUNT_SUSPENDED' => AuthFailureKind.accountSuspended,
      'ACCOUNT_DISABLED' => AuthFailureKind.accountDisabled,
      'ACCOUNT_PENDING_APPROVAL' => AuthFailureKind.accountPendingApproval,
      'ACCOUNT_PENDING' => AuthFailureKind.emailNotVerified,
      'ALREADY_ENROLLED' => AuthFailureKind.unknown,
      _ when status >= 500 => AuthFailureKind.server,
      _ => AuthFailureKind.unknown,
    };
    return AuthFailure(kind, message);
  }

  UserProfile _profile(Map<String, dynamic> body) =>
      UserProfile.fromMap(body['profile'] as Map<String, dynamic>);

  Future<void> _storeSession(Map<String, dynamic> body) async {
    final session = body['session'] as Map<String, dynamic>?;
    final token = session?['token'] as String?;
    if (token != null) await _sessions.write(token);
  }

  @override
  Future<UserProfile?> restoreSession() async {
    if (await _sessions.read() == null) return null;
    try {
      final body = await _send('GET', '/api/auth/session');
      final profile = _profile(body);
      _controller.add(profile);
      return profile;
    } on AuthFailure catch (failure) {
      // A rejected token is simply a signed-out user, not an error to surface.
      if (failure.kind == AuthFailureKind.sessionExpired) {
        await _sessions.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final body = await _send(
      'POST',
      '/api/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    await _storeSession(body);
    final profile = _profile(body);
    _controller.add(profile);
    return profile;
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
    if (!PasswordPolicy.isValid(password)) {
      throw const AuthFailure(AuthFailureKind.weakPassword);
    }
    final body = await _send(
      'POST',
      '/api/auth/register',
      body: {
        'email': email.trim(),
        'password': password,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'phone': phone,
        'country': country,
        'role': role.wireName,
      },
    );
    await _storeSession(body);
    final profile = _profile(body);
    _controller.add(profile);
    return profile;
  }

  @override
  Future<void> signOut() async {
    try {
      await _send('POST', '/api/auth/logout');
    } on AuthFailure {
      // Losing the server round-trip must not strand the user signed in.
    }
    await _sessions.clear();
    _controller.add(null);
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _send('POST', '/api/auth/forgot-password', body: {'email': email.trim()});

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _send(
      'POST',
      '/api/auth/reset-password',
      body: {'token': token, 'password': newPassword},
    );
    // The server dropped every session; force a fresh sign-in.
    await _sessions.clear();
    _controller.add(null);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final body = await _send(
      'POST',
      '/api/auth/change-password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
    _controller.add(_profile(body));
  }

  @override
  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? country,
    String? avatarUrl,
  }) async {
    final body = await _send(
      'PATCH',
      '/api/profile',
      body: {
        'first_name': ?firstName,
        'last_name': ?lastName,
        'phone': ?phone,
        'country': ?country,
        'avatar_url': ?avatarUrl,
      },
    );
    final profile = _profile(body);
    _controller.add(profile);
    return profile;
  }

  @override
  Future<List<UserProfile>> listUsers() async {
    final body = await _send('GET', '/api/admin/users');
    return (body['users'] as List<dynamic>)
        .map((row) => UserProfile.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<({UserProfile profile, String temporaryPassword})> adminCreateUser({
    required String email,
    required UserRole role,
    String firstName = '',
    String lastName = '',
  }) async {
    final body = await _send(
      'POST',
      '/api/admin/users',
      body: {
        'email': email.trim(),
        'role': role.wireName,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
      },
    );
    return (
      profile: _profile(body),
      temporaryPassword: body['temporary_password'] as String? ?? '',
    );
  }

  @override
  Future<void> adminDeleteUser(String userId) =>
      _send('DELETE', '/api/admin/users/$userId');

  @override
  Future<UserProfile> adminSetStatus({
    required String userId,
    required AccountStatus status,
  }) async {
    final body = await _send(
      'PATCH',
      '/api/admin/users/$userId',
      body: {'status': status.wireName},
    );
    return _profile(body);
  }

  @override
  Future<UserProfile> adminSetRole({
    required String userId,
    required UserRole role,
  }) async {
    final body = await _send(
      'PATCH',
      '/api/admin/users/$userId',
      body: {'role': role.wireName},
    );
    return _profile(body);
  }

  @override
  Future<List<ProgrammeEnrolment>> listEnrolments({String? userId}) async {
    final body = await _send(
      'GET',
      '/api/enrolments',
      query: userId == null ? null : {'user_id': userId},
    );
    return (body['enrolments'] as List<dynamic>)
        .map((row) => ProgrammeEnrolment.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ProgrammeEnrolment> enrol({
    required String userId,
    required String programmeId,
    bool waivePayment = false,
  }) async {
    final body = await _send(
      'POST',
      '/api/enrolments',
      body: {
        'user_id': userId,
        'programme_id': programmeId,
        'waive_payment': waivePayment,
      },
    );
    return ProgrammeEnrolment.fromMap(
      body['enrolment'] as Map<String, dynamic>,
    );
  }

  void dispose() {
    _controller.close();
    _client.close();
  }
}
