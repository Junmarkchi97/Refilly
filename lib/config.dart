/// Supabase config, passed at build time:
/// flutter run --dart-define-from-file=env.json
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgent = 'ph.refilly.app';

  /// Public web URL used in rider links and OAuth redirects (set APP_URL for production).
  static const _appUrl = String.fromEnvironment('APP_URL');
  /// Build-time APP_URL only (empty for local runs that did not pass it).
  static String get configuredAppUrl => _appUrl.trim();
  static String get appUrl => configuredAppUrl.isNotEmpty ? configuredAppUrl : Uri.base.origin;
  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
