import 'dart:convert';
import 'dart:typed_data';

import 'package:evasion/core/services/photo_picker.dart';

/// A real 1 x 1 pixel PNG image, which the preview can decode.
final pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8'
  'AAAAASUVORK5CYII=',
);

/// Start of a JPEG file, enough for format detection but not for display.
final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10]);

/// Start of an iPhone HEIC file: a box size, then "ftypheic".
final heicBytes = Uint8List.fromList([0, 0, 0, 0x18, ...'ftypheic'.codeUnits]);

/// Returns [result] instead of opening the phone's gallery or camera.
///
/// Set [result] to null to act as if the user cancelled, or [error] to make
/// the next pick fail.
class FakePhotoPicker implements PhotoPicker {
  Uint8List? result = pngBytes;
  Exception? error;
  final List<PhotoSource> requestedSources = [];
  final List<PhotoShape> requestedShapes = [];

  @override
  Future<Uint8List?> pickPhoto(
    PhotoSource source,
    PhotoShape shape,
    CropAppearance appearance,
  ) async {
    requestedSources.add(source);
    requestedShapes.add(shape);
    if (error case final error?) throw error;
    return result;
  }
}
