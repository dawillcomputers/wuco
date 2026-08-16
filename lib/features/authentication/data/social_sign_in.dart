import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

/// Signing in with a Google account.
///
/// The academy's client id is not compiled in. It comes from the API, which
/// already reports which providers this deployment can actually complete a
/// sign-in with — so a deployment with no Google client configured offers no
/// Google button, rather than one that fails when it is pressed.
///
/// Two shapes of flow, because Google requires it:
///
///   On the web, Google Identity Services will only start a sign-in from a
///   button it renders itself. It cannot be triggered from our own code, and
///   it cannot be restyled. `supportsAuthenticate` is false there, and the
///   sign-in arrives asynchronously on [events].
///
///   Everywhere else, [authenticate] opens the account chooser directly and
///   returns the result.
///
/// Both paths end the same way: an ID token, which is sent to the API and
/// verified there against Google's public keys. The token is the only thing
/// that crosses; this class never sees a password and never issues a session.
class SocialSignIn {
  SocialSignIn._();

  static final SocialSignIn instance = SocialSignIn._();

  String? _initialisedFor;
  Future<void>? _initialising;

  /// Whether this platform can start a sign-in from our own button.
  ///
  /// False on the web, where Google's rendered button is the only way in.
  bool get canPrompt => GoogleSignIn.instance.supportsAuthenticate();

  /// Prepares the SDK for a client id, once.
  ///
  /// `initialize` may only be called once per process, so a second call with
  /// the same id is ignored rather than repeated. A different id means the
  /// deployment was reconfigured mid-session, which cannot be honoured without
  /// a restart — the first one continues to apply.
  Future<void> ensureInitialised(String clientId) {
    if (_initialisedFor == clientId && _initialising != null) {
      return _initialising!;
    }
    if (_initialisedFor != null) return _initialising ?? Future.value();

    _initialisedFor = clientId;
    _initialising = GoogleSignIn.instance.initialize(clientId: clientId);
    return _initialising!;
  }

  /// ID tokens as sign-ins complete.
  ///
  /// This is the only route on the web, and a second route everywhere else.
  /// A sign-in that yields no ID token is dropped rather than surfaced: there
  /// is nothing the API could verify.
  Stream<String> get idTokens => GoogleSignIn.instance.authenticationEvents
      .where((event) => event is GoogleSignInAuthenticationEventSignIn)
      .cast<GoogleSignInAuthenticationEventSignIn>()
      .map((event) => event.user.authentication.idToken)
      .where((token) => token != null && token.isNotEmpty)
      .cast<String>();

  /// Opens the account chooser. Only where [canPrompt] is true.
  ///
  /// Returns null when the person closed the chooser without picking an
  /// account, which is a decision rather than a failure and is not reported as
  /// an error.
  Future<String?> authenticate() async {
    if (!canPrompt) return null;
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Forgets the Google account, so the next sign-in asks again.
  ///
  /// Called alongside WEA's own sign-out: leaving the Google session behind
  /// would sign the same person straight back in, which is not what anybody
  /// pressing "sign out" on a shared machine means.
  Future<void> signOut() async {
    if (_initialisedFor == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Nothing to sign out of, or the SDK never loaded. Either way WEA's own
      // session has already gone, which is the part that matters.
    }
  }
}
