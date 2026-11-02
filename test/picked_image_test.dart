import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/services/picked_image.dart';

void main() {
  test('detects jpeg png and webp from magic bytes', () {
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final webp = Uint8List.fromList([
      0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50,
    ]);

    expect(imageKindFromBytes(jpeg)?.ext, 'jpg');
    expect(imageKindFromBytes(jpeg)?.contentType, 'image/jpeg');
    expect(imageKindFromBytes(png)?.ext, 'png');
    expect(imageKindFromBytes(webp)?.ext, 'webp');
  });

  test('rejects heic so station uploads do not hit the mime allow-list', () {
    final heic = Uint8List.fromList([
      0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63,
    ]);
    expect(looksLikeHeic(heic), isTrue);
    expect(imageKindFromBytes(heic), isNull);
  });

  test('falls back to the file name when bytes are ambiguous', () {
    expect(imageKindFromName('shop.PNG')?.contentType, 'image/png');
    expect(imageKindFromName('shot.jpeg')?.ext, 'jpg');
    expect(imageKindFromName('notes.txt'), isNull);
  });
}
