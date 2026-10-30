/// Supabase config, passed at build time:
/// flutter run --dart-define-from-file=env.json
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgent = 'ph.refilly.app';
  /// Public web URL used in rider links (set APP_URL in env.json for production).
  static const _appUrl = String.fromEnvironment('APP_URL');
  static String get appUrl => _appUrl.isNotEmpty ? _appUrl : Uri.base.origin;
  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
