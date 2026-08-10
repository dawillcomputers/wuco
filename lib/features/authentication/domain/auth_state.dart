import 'auth_failure.dart';
import 'user_profile.dart';

/// Central authentication state. Widgets read this rather than reasoning about
/// sessions themselves.
sealed class AuthState {
  const AuthState();

  /// Before the stored session has been inspected. The router holds the splash
  /// here so the login page never flashes for an already-signed-in user.
  const factory AuthState.initial() = AuthInitial;

  const factory AuthState.loading([String? message]) = AuthLoading;

  const factory AuthState.unauthenticated() = AuthUnauthenticated;

  const factory AuthState.authenticated(UserProfile profile) = Authenticated;

  const factory AuthState.emailUnverified(UserProfile profile) =
      AuthEmailUnverified;

  const factory AuthState.error(AuthFailure failure) = AuthError;

  UserProfile? get profile => switch (this) {
    Authenticated(:final profile) => profile,
    AuthEmailUnverified(:final profile) => profile,
    _ => null,
  };

  /// True only for a fully usable session. An unverified account is signed in
  /// but must not reach protected areas.
  bool get isAuthenticated => this is Authenticated;

  bool get isResolved => this is! AuthInitial && this is! AuthLoading;
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading([this.message]);
  final String? message;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class Authenticated extends AuthState {
  const Authenticated(this.profile);
  @override
  final UserProfile profile;
}

class AuthEmailUnverified extends AuthState {
  const AuthEmailUnverified(this.profile);
  @override
  final UserProfile profile;
}

class AuthError extends AuthState {
  const AuthError(this.failure);
  final AuthFailure failure;
}
