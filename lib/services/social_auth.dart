import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

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

  /// Null when the provider can be offered. A sentence when Supabase has it turned off,
  /// so the app can explain that instead of following the link to a raw error page.
  static String? unavailableMessage(OAuthProvider provider, Map<String, dynamic> settings) {
    final external = settings['external'];
    if (external is Map && external[provider.name] == false) {
      final name = provider == OAuthProvider.apple ? 'Apple' : 'Google';
      return '$name sign-in is turned off for this Refilly project. Use your email and password for now.';
    }
    return null;
  }

  static Future<String?> unavailableReason(OAuthProvider provider) async {
    if (!AppConfig.isConfigured) return 'Sign-in is not configured for this build.';
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.supabaseUrl}/auth/v1/settings'),
            headers: {'apikey': AppConfig.supabaseAnonKey},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      return unavailableMessage(provider, body);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> signIn(OAuthProvider provider) async {
    if (provider == OAuthProvider.apple && !appleAvailable) {
      throw StateError('Apple sign-in is only available on iOS devices.');
    }
    final blocked = await unavailableReason(provider);
    if (blocked != null) throw StateError(blocked);
    return Supabase.instance.client.auth.signInWithOAuth(
      provider,
      redirectTo: redirectUrl(isWeb: kIsWeb, browserUrl: Uri.base),
    );
  }
}
