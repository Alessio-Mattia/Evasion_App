import 'dart:typed_data';

import 'package:evasion/core/config/business_rules.dart';

/// Photo formats accepted by the `avatars` bucket.
enum PhotoFormat {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  webp('image/webp', 'webp');

  const PhotoFormat(this.mimeType, this.extension);

  /// Declared to the server; must match [extension], or the upload is refused.
  final String mimeType;
  final String extension;
}

/// Reads the format from the first bytes of the file, its "signature", rather
/// than trusting a file name. Null for any other format, such as HEIC.
PhotoFormat? detectPhotoFormat(Uint8List bytes) {
  bool startsWith(List<int> signature, [int offset = 0]) {
    if (bytes.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0xFF, 0xD8, 0xFF])) return PhotoFormat.jpeg;
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return PhotoFormat.png;
  }
  // "RIFF", then the file size on 4 bytes, then "WEBP".
  if (startsWith('RIFF'.codeUnits) && startsWith('WEBP'.codeUnits, 8)) {
    return PhotoFormat.webp;
  }
  return null;
}

enum PhotoProblem { unsupportedFormat, tooLarge }

/// Why the server would refuse this photo, or null if it is acceptable.
PhotoProblem? checkPhoto(Uint8List bytes) {
  if (detectPhotoFormat(bytes) == null) return PhotoProblem.unsupportedFormat;
  if (bytes.length > BusinessRules.avatarMaxBytes) return PhotoProblem.tooLarge;
  return null;
}

/// Path of a photo in the `avatars` bucket, as the server requires:
/// `<user id>/<file name>.<extension>`. Also stored as `avatar_path`.
String avatarPath({
  required String userId,
  required String fileName,
  required PhotoFormat format,
}) => '$userId/$fileName.${format.extension}';
