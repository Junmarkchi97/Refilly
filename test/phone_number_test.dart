import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/services/api.dart';

void main() {
  group('Philippine phone normalization', () {
    test('normalizes local mobile', () {
      expect(Api.toE164('09171234567'), '+639171234567');
    });
    test('normalizes country code', () {
      expect(Api.toE164('639171234567'), '+639171234567');
    });
    test('preserves international format', () {
      expect(Api.toE164('+639171234567'), '+639171234567');
    });
  });
}
