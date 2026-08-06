sealed class AppError implements Exception {
  const AppError(this.message);
  final String message;
}

class NetworkError extends AppError {
  const NetworkError([
    super.message = 'Please check your internet connection and try again.',
  ]);
}

class AuthenticationError extends AppError {
  const AuthenticationError([
    super.message = 'Your session could not be verified.',
  ]);
}

class ValidationError extends AppError {
  const ValidationError([
    super.message = 'Please review the highlighted information.',
  ]);
}

class UnknownAppError extends AppError {
  const UnknownAppError([
    super.message = 'Something went wrong. Please try again.',
  ]);
}
