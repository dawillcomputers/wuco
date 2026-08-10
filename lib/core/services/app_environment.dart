enum AppEnvironment { development, staging, production }

abstract final class AppEnvironmentConfig {
  static const String _environment = String.fromEnvironment(
    'WEA_ENV',
    defaultValue: 'development',
  );
  static AppEnvironment get current => switch (_environment) {
    'production' => AppEnvironment.production,
    'staging' => AppEnvironment.staging,
    _ => AppEnvironment.development,
  };

  static bool get isProduction => current == AppEnvironment.production;

  /// Base URL of the Cloudflare Worker API backing authentication and data.
  ///
  /// Supplied with `--dart-define=WEA_API_BASE_URL=…`. When absent the app runs
  /// against the offline development backend so the interface stays usable
  /// without a deployed API.
  static const apiBaseUrl = String.fromEnvironment('WEA_API_BASE_URL');

  static bool get hasApiConfiguration => apiBaseUrl.isNotEmpty;

  /// Account seeded as the first Super Admin.
  static const seedSuperAdminEmail = String.fromEnvironment(
    'WEA_SUPERADMIN_EMAIL',
    defaultValue: 'proptgoservices@gmail.com',
  );

  /// One-time password for the seeded Super Admin.
  ///
  /// Supplied with `--dart-define=WEA_SUPERADMIN_PASSWORD=…` so no credential
  /// lives in source control. The fallback exists only for the offline
  /// development backend, which holds no real data; the account is flagged
  /// `mustChangePassword`, so it has to be replaced at first sign-in.
  static const seedSuperAdminPassword = String.fromEnvironment(
    'WEA_SUPERADMIN_PASSWORD',
    defaultValue: 'WeaSetup!2026',
  );
}
