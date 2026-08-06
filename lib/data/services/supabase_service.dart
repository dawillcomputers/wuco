import '../../core/services/app_environment.dart';

/// Backend boundary for future Supabase integrations. Credentials are injected
/// with Dart environment variables and never committed to source control.
class SupabaseService {
  const SupabaseService();

  bool get isConfigured => AppEnvironmentConfig.hasSupabaseConfiguration;
}
