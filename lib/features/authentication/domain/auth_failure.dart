/// Authentication failures, already translated for display.
///
/// Backend messages never reach the interface: they leak implementation detail
/// and, for credential errors, help enumerate accounts.
enum AuthFailureKind {
  invalidCredentials,
  emailAlreadyRegistered,
  weakPassword,
  passwordMismatch,
  expiredLink,
  invalidLink,
  network,
  server,
  sessionExpired,
  emailNotVerified,
  accountSuspended,
  accountDisabled,
  accountPendingApproval,
  notAuthorised,
  rateLimited,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.kind, [String? message]) : _message = message;

  final AuthFailureKind kind;
  final String? _message;

  String get message => _message ?? _defaultMessage;

  String get _defaultMessage => switch (kind) {
    AuthFailureKind.invalidCredentials => 'Invalid email or password.',
    AuthFailureKind.emailAlreadyRegistered =>
      'An account already exists for this email address.',
    AuthFailureKind.weakPassword =>
      'Choose a stronger password using at least 8 characters, including an '
          'uppercase letter, a lowercase letter, a number and a symbol.',
    AuthFailureKind.passwordMismatch => 'Passwords do not match.',
    AuthFailureKind.expiredLink =>
      'This link has expired. Please request a new one.',
    AuthFailureKind.invalidLink =>
      'This link is not valid. Please request a new one.',
    AuthFailureKind.network =>
      'Unable to connect. Please check your internet connection and try again.',
    AuthFailureKind.server =>
      'Something went wrong on our side. Please try again shortly.',
    AuthFailureKind.sessionExpired =>
      'Your session has expired. Please sign in again.',
    AuthFailureKind.emailNotVerified =>
      'Please verify your email address to continue.',
    AuthFailureKind.accountSuspended =>
      'Your account has been temporarily suspended. Please contact WEA support.',
    AuthFailureKind.accountDisabled =>
      'Your account is currently disabled. Please contact WEA support.',
    AuthFailureKind.accountPendingApproval =>
      'Your account is awaiting administrative approval.',
    AuthFailureKind.notAuthorised =>
      'You do not have permission to perform this action.',
    AuthFailureKind.rateLimited =>
      'Too many attempts. Please wait a moment and try again.',
    AuthFailureKind.unknown => 'Something went wrong. Please try again.',
  };

  /// Whether offering a retry button makes sense.
  bool get isRetryable =>
      kind == AuthFailureKind.network || kind == AuthFailureKind.server;

  @override
  String toString() => 'AuthFailure(${kind.name}): $message';
}
