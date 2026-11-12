import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/storage/storage_images.dart';
import 'package:flutter/widgets.dart';

import 'fake_photo_picker.dart';

/// Serves a tiny in-memory image instead of asking Supabase for a link.
class FakeStorageImages implements StorageImages {
  /// Set to make the next requests fail.
  AppFailure? failure;
  final List<(StorageBucket, String)> requested = [];

  @override
  Future<ImageProvider> fetch(StorageBucket bucket, String path) async {
    requested.add((bucket, path));
    if (failure case final failure?) throw failure;
    return MemoryImage(pngBytes);
  }
}
