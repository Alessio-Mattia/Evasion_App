import 'dart:async';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/errors/failure_mapper.dart';
import 'package:evasion/core/supabase/supabase_client_provider.dart';
import 'package:flutter/painting.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'storage_images.g.dart';

/// Private storage buckets holding images.
enum StorageBucket {
  avatars('avatars'),
  profilePhotos('profile-photos'),
  postPhotos('post-photos');

  const StorageBucket(this.id);

  final String id;
}

/// Gives the images of private buckets. Every method throws an `AppFailure`
/// on error.
abstract interface class StorageImages {
  /// The image at [path] in [bucket], if the signed-in user may see it.
  Future<ImageProvider> fetch(StorageBucket bucket, String path);
}

@Riverpod(keepAlive: true)
StorageImages storageImages(Ref ref) =>
    SupabaseStorageImages(ref.watch(supabaseClientProvider));

/// Loads private images through signed URLs: temporary links that the server
/// only creates after checking the access rules of the bucket.
class SupabaseStorageImages implements StorageImages {
  SupabaseStorageImages(this._client);

  final SupabaseClient _client;

  @override
  Future<ImageProvider> fetch(StorageBucket bucket, String path) =>
      guard(() async {
        final url = await _client.storage
            .from(bucket.id)
            .createSignedUrl(
              path,
              BusinessRules.signedUrlLifetime.inSeconds,
            );
        return NetworkImage(url);
      });
}

/// The image at [path] in [bucket], kept for a while so that every rebuild
/// does not ask the server for a new link.
///
/// Released a little before the signed URL expires: the next use then asks
/// for a fresh one.
@riverpod
Future<ImageProvider> storageImage(
  Ref ref,
  StorageBucket bucket,
  String path,
) async {
  final keepAlive = ref.keepAlive();
  final expiry = Timer(
    BusinessRules.signedUrlLifetime - const Duration(minutes: 10),
    keepAlive.close,
  );
  ref.onDispose(expiry.cancel);
  return ref.watch(storageImagesProvider).fetch(bucket, path);
}
