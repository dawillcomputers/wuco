import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the tokens that let a guest return to their own registration.
///
/// Someone who registers without a WEA account still owns their registration.
/// The API issues a token once, at creation; this keeps it on the device so
/// closing the tab and coming back later resumes the same registration rather
/// than starting a second one — and so nobody else can open it by guessing a
/// reference.
///
/// Only the token is kept. Nothing about the person is written here.
class RegistrationTokenStore {
  static const _key = 'wea.events.registration.tokens';

  Future<Map<String, String>> _all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final entry in decoded.entries) entry.key: '${entry.value}'};
    } catch (_) {
      return {};
    }
  }

  Future<String?> read(String reference) async => (await _all())[reference];

  Future<void> write(String reference, String token) async {
    final prefs = await SharedPreferences.getInstance();
    final tokens = await _all();
    tokens[reference] = token;
    await prefs.setString(_key, jsonEncode(tokens));
  }

  /// References this device holds a token for, newest first is not guaranteed;
  /// used to show a returning guest what they have already started.
  Future<List<String>> references() async => (await _all()).keys.toList();

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Non-persistent store for tests and the offline development backend.
class InMemoryRegistrationTokenStore implements RegistrationTokenStore {
  final _tokens = <String, String>{};

  @override
  Future<Map<String, String>> _all() async => _tokens;

  @override
  Future<String?> read(String reference) async => _tokens[reference];

  @override
  Future<void> write(String reference, String token) async =>
      _tokens[reference] = token;

  @override
  Future<List<String>> references() async => _tokens.keys.toList();

  @override
  Future<void> clear() async => _tokens.clear();
}
