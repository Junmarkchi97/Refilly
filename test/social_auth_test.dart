import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/services/social_auth.dart';

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
    test('keeps root web URLs for separately hosted builds', () {
      expect(SocialAuth.redirectUrl(
        isWeb: true,
        browserUrl: Uri.parse('http://localhost:4000/?debug=true'),
      ), 'http://localhost:4000/');
    });
  });
}
