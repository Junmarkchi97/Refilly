import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// UI gating is a presentation rule only. OAuth provider configuration and
/// authenticated sessions are always validated by Supabase on the server.
class SocialAuth {
  static const mobileRedirect = 'io.refilly.app://login-callback/';

  /// Apple login should only appear on iPhones/iPads, including iOS Safari.
  /// Android, desktop and other web browsers should only offer Google.
  static bool showApple({required bool isWeb, required TargetPlatform platform}) =>
      platform == TargetPlatform.iOS;

  static bool get appleAvailable =>
      showApple(isWeb: kIsWeb, platform: defaultTargetPlatform);

  static String redirectUrl({required bool isWeb, required Uri browserUrl}) {
    if (!isWeb) return mobileRedirect;
    // Preserve the hosted app's base path, but never feed an OAuth token,
    // fragment, or query string back into the next login redirect.
    return '${browserUrl.origin}${browserUrl.path}';
  }

  static Future<bool> signIn(OAuthProvider provider) async {
    if (provider == OAuthProvider.apple && !appleAvailable) {
      throw StateError('Apple sign-in is only available on iOS devices.');
    }
    return Supabase.instance.client.auth.signInWithOAuth(
      provider,
      redirectTo: redirectUrl(isWeb: kIsWeb, browserUrl: Uri.base),
    );
  }
}
