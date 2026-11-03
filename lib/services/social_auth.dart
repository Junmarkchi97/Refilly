import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  /// Native Sign in with Apple on the iOS app; browser OAuth on iOS Safari / web.
  static bool useNativeAppleSignIn({
    required bool isWeb,
    required TargetPlatform platform,
  }) =>
      !isWeb && platform == TargetPlatform.iOS;

  static String redirectUrl({
    required bool isWeb,
    required Uri browserUrl,
    String? configuredAppUrl,
  }) {
    if (!isWeb) return mobileRedirect;
    // Prefer the production APP_URL so GitHub Pages OAuth never falls back to
    // whatever Supabase has as Site URL (often http://localhost:3000).
    final configured = (configuredAppUrl ?? AppConfig.configuredAppUrl).trim();
    if (configured.isNotEmpty) {
      final uri = Uri.tryParse(configured);
      if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
        return _webOriginPath(uri);
      }
    }
    // Preserve the hosted app's base path, but never feed an OAuth token,
    // fragment, or query string back into the next login redirect.
    return _webOriginPath(browserUrl);
  }

  static String _webOriginPath(Uri uri) {
    final path = uri.path.isEmpty ? '/' : (uri.path.endsWith('/') ? uri.path : '${uri.path}/');
    return '${uri.origin}$path';
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

    if (provider == OAuthProvider.apple &&
        useNativeAppleSignIn(isWeb: kIsWeb, platform: defaultTargetPlatform)) {
      await signInWithAppleNative();
      return true;
    }

    return Supabase.instance.client.auth.signInWithOAuth(
      provider,
      redirectTo: redirectUrl(isWeb: kIsWeb, browserUrl: Uri.base),
    );
  }

  /// Native Apple credential → Supabase session via identity token.
  ///
  /// Exposed for tests that inject a fake credential exchange.
  @visibleForTesting
  static Future<void> signInWithAppleNative({
    Future<AuthorizationCredentialAppleID> Function({
      required List<AppleIDAuthorizationScopes> scopes,
      required String nonce,
    })? getCredential,
    Future<void> Function({
      required OAuthProvider provider,
      required String idToken,
      required String nonce,
    })? signInWithIdToken,
    Future<void> Function(String fullName)? saveFullName,
  }) async {
    final rawNonce = generateNonce();
    final hashedNonce = sha256ofString(rawNonce);
    final fetch = getCredential ??
        ({required scopes, required nonce}) => SignInWithApple.getAppleIDCredential(
              scopes: scopes,
              nonce: nonce,
            );
    final credential = await fetch(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Apple did not return an identity token. Please try again.');
    }

    final exchange = signInWithIdToken ??
        ({required provider, required idToken, required nonce}) async {
          await Supabase.instance.client.auth.signInWithIdToken(
            provider: provider,
            idToken: idToken,
            nonce: nonce,
          );
        };
    await exchange(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    final fullName = appleFullName(credential.givenName, credential.familyName);
    if (fullName == null) return;
    final persist = saveFullName ?? _persistAppleFullName;
    await persist(fullName);
  }

  static String? appleFullName(String? givenName, String? familyName) {
    final parts = [
      givenName?.trim() ?? '',
      familyName?.trim() ?? '',
    ].where((p) => p.isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  static Future<void> _persistAppleFullName(String fullName) async {
    final client = Supabase.instance.client;
    final data = Map<String, dynamic>.from(client.auth.currentUser?.userMetadata ?? {});
    data['full_name'] = fullName;
    await client.auth.updateUser(UserAttributes(data: data));
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    await client.from('profiles').update({'full_name': fullName}).eq('id', uid);
  }

  @visibleForTesting
  static String generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  @visibleForTesting
  static String sha256ofString(String input) => sha256.convert(utf8.encode(input)).toString();
}
