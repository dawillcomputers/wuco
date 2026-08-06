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
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get hasSupabaseConfiguration =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
