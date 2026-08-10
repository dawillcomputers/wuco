import 'package:shared_preferences/shared_preferences.dart';

/// Persists the opaque session token across restarts and browser refreshes.
///
/// Only the session token is kept. Passwords are never written to the device.
class SessionStore {
  static const _tokenKey = 'wea.session.token';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> write(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}

/// Non-persistent store used by tests and the offline development backend.
class InMemorySessionStore implements SessionStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
