import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// A photo ready for upload to Refilly image buckets (JPG / PNG / WebP only).
class PickedImage {
  final Uint8List bytes;
  final String ext;
  final String contentType;
  const PickedImage({required this.bytes, required this.ext, required this.contentType});
}

class ImageKind {
  final String ext, contentType;
  const ImageKind(this.ext, this.contentType);
}

/// Detect JPG / PNG / WebP from magic bytes. Returns null for HEIC and other formats.
ImageKind? imageKindFromBytes(Uint8List bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return const ImageKind('jpg', 'image/jpeg');
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return const ImageKind('png', 'image/png');
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return const ImageKind('webp', 'image/webp');
  }
  return null;
}

bool looksLikeHeic(Uint8List bytes) {
  if (bytes.length < 12) return false;
  // ISO BMFF: size + 'ftyp' + brand
  final brand = String.fromCharCodes(bytes.sublist(4, 8));
  if (brand != 'ftyp') return false;
  final major = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
  return major.contains('heic') || major.contains('heif') || major == 'mif1' || major == 'msf1';
}

ImageKind? imageKindFromName(String name) {
  final ext = (name.contains('.') ? name.split('.').last : '').toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => const ImageKind('jpg', 'image/jpeg'),
    'png' => const ImageKind('png', 'image/png'),
    'webp' => const ImageKind('webp', 'image/webp'),
    _ => null,
  };
}

/// Opens the system image picker and validates the file for station / product uploads.
///
/// Uses [FileType.image] so iPhone Safari can open the photo library. Custom
/// extension filters often fail or return HEIC there, which our buckets reject.
Future<PickedImage?> pickAllowedImage({int maxBytes = 5 * 1024 * 1024}) async {
  final file = (await FilePicker.pickFiles(type: FileType.image)).firstOrNull;
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) {
    throw StateError('Could not read that photo. Please try another.');
  }
  if (bytes.length > maxBytes) {
    throw StateError('Image must be under 5 MB');
  }
  if (looksLikeHeic(bytes)) {
    throw StateError('HEIC photos are not supported. Choose a JPG or PNG, or share as Most Compatible.');
  }
  final kind = imageKindFromBytes(bytes) ?? imageKindFromName(file.name);
  if (kind == null) {
    throw StateError('Use a JPG, PNG, or WebP photo.');
  }
  return PickedImage(bytes: bytes, ext: kind.ext, contentType: kind.contentType);
}
