import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/brand.dart';
import 'package:refilly/services/social_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Apple sign-in visibility', () {
    test('is shown on native iOS', () {
      expect(SocialAuth.showApple(isWeb: false, platform: TargetPlatform.iOS), isTrue);
    });
    test('is shown on iOS Safari only, not other browser platforms', () {
      expect(SocialAuth.showApple(isWeb: true, platform: TargetPlatform.iOS), isTrue);
      expect(SocialAuth.showApple(isWeb: true, platform: TargetPlatform.android), isFalse);
      expect(SocialAuth.showApple(isWeb: true, platform: TargetPlatform.macOS), isFalse);
      expect(SocialAuth.showApple(isWeb: true, platform: TargetPlatform.windows), isFalse);
      expect(SocialAuth.showApple(isWeb: true, platform: TargetPlatform.linux), isFalse);
    });
    test('is not shown on native Android', () {
      expect(SocialAuth.showApple(isWeb: false, platform: TargetPlatform.android), isFalse);
    });
  });

  group('OAuth callback URL safety', () {
    test('uses a native app callback on mobile', () {
      expect(SocialAuth.redirectUrl(
        isWeb: false,
        browserUrl: Uri.parse('https://junmarkchi97.github.io/Refilly/'),
      ), SocialAuth.mobileRedirect);
    });
    test('keeps GitHub Pages subpath but strips query/fragment', () {
      expect(SocialAuth.redirectUrl(
        isWeb: true,
        browserUrl: Uri.parse('https://junmarkchi97.github.io/Refilly/?from=signup#token=secret'),
      ), 'https://junmarkchi97.github.io/Refilly/');
    });

    test('prefers the production APP_URL over the current browser location', () {
      expect(
        SocialAuth.redirectUrl(
          isWeb: true,
          browserUrl: Uri.parse('https://junmarkchi97.github.io/Refilly/login'),
          configuredAppUrl: 'https://junmarkchi97.github.io/Refilly',
        ),
        'https://junmarkchi97.github.io/Refilly/',
      );
    });
    test('explains a turned-off Google provider instead of following its error page', () {
      final message = SocialAuth.unavailableMessage(OAuthProvider.google, {
        'external': {'google': false, 'apple': false},
      });
      expect(message, contains('Google sign-in is turned off'));
      expect(SocialAuth.unavailableMessage(OAuthProvider.google, {
        'external': {'google': true},
      }), isNull);
    });

    test('the Google mark draws all four brand colors', () {
      final colors = <int>{};
      for (final (color, data) in GoogleMark.parts) {
        colors.add(color.toARGB32());
        expect(svgPath(data).getBounds().width, greaterThan(10));
      }
      expect(colors, {0xFFFBBC05, 0xFFEA4335, 0xFF34A853, 0xFF4285F4});
    });

    test('keeps root web URLs for separately hosted builds', () {
      expect(SocialAuth.redirectUrl(
        isWeb: true,
        browserUrl: Uri.parse('http://localhost:4000/?debug=true'),
      ), 'http://localhost:4000/');
    });
  });
}
