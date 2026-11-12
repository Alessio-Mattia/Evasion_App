import 'dart:typed_data';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_photo_picker.dart';

Uint8List bytesOf(List<int> start, {int totalLength = 16}) =>
    Uint8List(totalLength)..setRange(0, start.length, start);

void main() {
  group('detectPhotoFormat', () {
    test('reads the signature of each accepted format', () {
      expect(detectPhotoFormat(jpegBytes), PhotoFormat.jpeg);
      expect(
        detectPhotoFormat(
          bytesOf([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ),
        PhotoFormat.png,
      );
      expect(
        detectPhotoFormat(
          bytesOf([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]),
        ),
        PhotoFormat.webp,
      );
    });

    test('refuses other formats, such as an iPhone HEIC photo', () {
      expect(detectPhotoFormat(heicBytes), isNull);
      expect(
        detectPhotoFormat(
          bytesOf([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WAVE'.codeUnits]),
        ),
        isNull,
      );
      expect(detectPhotoFormat(Uint8List(0)), isNull);
      expect(detectPhotoFormat(Uint8List.fromList([0xFF, 0xD8])), isNull);
    });
  });

  group('checkPhoto', () {
    test('accepts a JPEG within the size limit', () {
      expect(checkPhoto(jpegBytes), isNull);
    });

    test('refuses an unsupported format', () {
      expect(checkPhoto(heicBytes), PhotoProblem.unsupportedFormat);
    });

    test('refuses a photo over the size limit', () {
      final tooLarge = bytesOf(
        jpegBytes,
        totalLength: BusinessRules.avatarMaxBytes + 1,
      );

      expect(checkPhoto(tooLarge), PhotoProblem.tooLarge);
    });
  });

  test('every format is accepted by the bucket', () {
    expect(
      PhotoFormat.values.map((format) => format.mimeType),
      unorderedEquals(BusinessRules.avatarMimeTypes),
    );
  });

  test('the path follows the server rule, for every format', () {
    const userId = '6f1c2e9a-1b2c-4d5e-8f90-123456789abc';
    // Same expression as the profiles_avatar_path_own_folder constraint.
    final serverRule = RegExp(
      '^$userId/[^/]+\\.(jpe?g|png|webp)\$',
      caseSensitive: false,
    );

    for (final format in PhotoFormat.values) {
      final path = userPhotoPath(
        userId: userId,
        fileName: uniquePhotoFileName(),
        format: format,
      );
      expect(path, matches(serverRule), reason: format.name);
    }
  });

  test('page photos accept the same formats as avatars', () {
    expect(
      BusinessRules.profilePhotoMimeTypes,
      unorderedEquals(BusinessRules.avatarMimeTypes),
    );
    expect(BusinessRules.profilePhotoMaxBytes, BusinessRules.avatarMaxBytes);
  });

  test('each upload gets a new file name', () {
    final names = {for (var i = 0; i < 100; i++) uniquePhotoFileName()};
    expect(names, hasLength(100));
  });
}
