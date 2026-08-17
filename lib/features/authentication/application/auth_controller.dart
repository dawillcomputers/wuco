import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_environment.dart';
import '../data/auth_repository.dart';
import '../data/cloudflare_auth_repository.dart';
import '../data/in_memory_auth_repository.dart';
import '../data/session_store.dart';
import '../data/social_sign_in.dart';
import '../domain/account_status.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_state.dart';
import '../domain/programme_enrolment.dart';
import '../domain/user_profile.dart';
import '../domain/user_role.dart';

/// Session token storage. Overridden in tests with an in-memory store.
final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// Chooses the live Worker API when configured, otherwise the offline
/// development backend so the interface remains usable and testable.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppEnvironmentConfig.hasApiConfiguration) {
    return CloudflareAuthRepository(
      baseUrl: AppEnvironmentConfig.apiBaseUrl,
      sessionStore: ref.watch(sessionStoreProvider),
    );
  }
  return InMemoryAuthRepository();
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// A temporary password this session has just issued, held until it is used.
///
/// Registering for an event can create an account, and the password it
/// generates is shown once and emailed. When that person is then asked to
/// choose their own, asking them to re-type a random string they were shown a
/// screen ago — or to go and find the email — is a needless way to lose them.
///
/// In memory only, and never persisted: it is a credential, and it stops
/// working the moment a real password replaces it.
class IssuedTemporaryPassword extends Notifier<String?> {
  @override
  String? build() => null;

  void remember(String? password) => state = password;

  /// Read once and forgotten, so it cannot be prefilled a second time for
  /// whoever next opens the screen.
  String? take() {
    final password = state;
    state = null;
    return password;
  }
}

final issuedTemporaryPasswordProvider =
    NotifierProvider<IssuedTemporaryPassword, String?>(
      IssuedTemporaryPassword.new,
    );

/// Convenience reads so widgets do not pattern-match state everywhere.
final currentProfileProvider = Provider<UserProfile?>(
  (ref) => ref.watch(authControllerProvider).profile,
);

final currentRoleProvider = Provider<UserRole?>(
  (ref) => ref.watch(currentProfileProvider)?.role,
);

/// Owns authentication for the whole application.
class AuthController extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    // Restoration begins immediately; the router waits on [AuthInitial] so the
    // login page never flashes for a signed-in user.
    Future.microtask(restore);
    return const AuthState.initial();
  }

  Future<void> restore() async {
    try {
      final profile = await _repository.restoreSession();
      state = _stateFor(profile);
    } on AuthFailure catch (failure) {
      state = AuthState.error(failure);
    }
  }

  AuthState _stateFor(UserProfile? profile) {
    if (profile == null) return const AuthState.unauthenticated();
    // Email verification no longer holds anybody back: accounts are created
    // active and verified, because a link in an inbox between a registrant and
    // their place cost more registrations than the check was worth. An account
    // left unverified by an older release is signed in like any other rather
    // than stranded in a state nothing now resolves.
    return AuthState.authenticated(profile);
  }

  /// Runs [action], mapping failures onto [AuthError]. Returns true on success
  /// so screens can decide whether to navigate.
  Future<bool> _guard(
    Future<void> Function() action, {
    String? loadingMessage,
  }) async {
    state = AuthState.loading(loadingMessage);
    try {
      await action();
      return true;
    } on AuthFailure catch (failure) {
      state = AuthState.error(failure);
      return false;
    } catch (_) {
      state = const AuthState.error(AuthFailure(AuthFailureKind.unknown));
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) =>
      _guard(() async {
        final profile = await _repository.signIn(
          email: email,
          password: password,
        );
        state = _stateFor(profile);
      }, loadingMessage: 'Signing in…');

  /// Completes a sign-in that a provider has already proved.
  ///
  /// The ID token is not a credential this application may interpret — it is
  /// passed to the API, which verifies it against the provider's own public
  /// keys and decides whether it names an account.
  Future<bool> signInWithProvider({
    required String provider,
    required String idToken,
  }) => _guard(() async {
    final profile = await _repository.signInWithProvider(
      provider: provider,
      idToken: idToken,
    );
    state = _stateFor(profile);
  }, loadingMessage: 'Signing in…');

  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    String? country,
  }) => _guard(() async {
    final profile = await _repository.signUp(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      country: country,
    );
    state = _stateFor(profile);
  }, loadingMessage: 'Creating account…');

  Future<void> signOut() async {
    state = const AuthState.loading('Signing out…');
    try {
      await _repository.signOut();
    } finally {
      // The Google session goes too. Leaving it would sign the same person
      // straight back in, which is not what anybody pressing "sign out" on a
      // shared machine means.
      await SocialSignIn.instance.signOut();
      state = const AuthState.unauthenticated();
    }
  }

  Future<bool> sendPasswordReset(String email) {
    final previous = state;
    return _guard(() async {
      await _repository.sendPasswordReset(email);
      state = previous;
    }, loadingMessage: 'Sending reset link…');
  }

  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) => _guard(() async {
    await _repository.resetPassword(token: token, newPassword: newPassword);
    state = const AuthState.unauthenticated();
  }, loadingMessage: 'Updating password…');

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    final profile = state.profile;
    return _guard(() async {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = profile == null
          ? const AuthState.unauthenticated()
          : AuthState.authenticated(
              profile.copyWith(mustChangePassword: false),
            );
    }, loadingMessage: 'Updating password…');
  }

  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? country,
  }) => _guard(() async {
    final profile = await _repository.updateProfile(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      country: country,
    );
    state = _stateFor(profile);
  }, loadingMessage: 'Saving profile…');

  /// Clears a displayed error without disturbing the session.
  void clearError() {
    if (state is AuthError) {
      final profile = state.profile;
      state = profile == null
          ? const AuthState.unauthenticated()
          : _stateFor(profile);
    }
  }

  // --- Administration ------------------------------------------------------

  Future<List<UserProfile>> listUsers() => _repository.listUsers();

  Future<({UserProfile profile, IssuedCredentials credentials})> createUser({
    required String email,
    required UserRole role,
    String firstName = '',
    String lastName = '',
  }) => _repository.adminCreateUser(
    email: email,
    role: role,
    firstName: firstName,
    lastName: lastName,
  );

  /// Resets somebody's password for them and returns the details to pass on.
  Future<IssuedCredentials> resetUserPassword(String userId, String email) =>
      _repository.adminResetPassword(userId, email);

  Future<void> deleteUser(String userId) => _repository.adminDeleteUser(userId);

  Future<UserProfile> setRole(String userId, UserRole role) =>
      _repository.adminSetRole(userId: userId, role: role);

  Future<UserProfile> setStatus(String userId, AccountStatus status) =>
      _repository.adminSetStatus(userId: userId, status: status);

  Future<List<ProgrammeEnrolment>> enrolments({String? userId}) =>
      _repository.listEnrolments(userId: userId);

  Future<ProgrammeEnrolment> enrol({
    required String userId,
    required String programmeId,
    bool waivePayment = false,
  }) => _repository.enrol(
    userId: userId,
    programmeId: programmeId,
    waivePayment: waivePayment,
  );
}
