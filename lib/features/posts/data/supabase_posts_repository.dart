import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/errors/failure_mapper.dart';
import 'package:evasion/core/models/geo_point.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/core/supabase/supabase_client_provider.dart';
import 'package:evasion/features/posts/domain/map_area.dart';
import 'package:evasion/features/posts/domain/post.dart';
import 'package:evasion/features/posts/domain/post_draft.dart';
import 'package:evasion/features/posts/domain/posts_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_posts_repository.g.dart';

@Riverpod(keepAlive: true)
PostsRepository postsRepository(Ref ref) =>
    SupabasePostsRepository(ref.watch(supabaseClientProvider));

class SupabasePostsRepository implements PostsRepository {
  SupabasePostsRepository(this._client);

  final SupabaseClient _client;

  /// Every column of the `posts_public` view.
  static const _columns =
      'id, author_id, image_path, caption, latitude, longitude, '
      'location_precision, audience, created_at, expires_at';

  StorageFileApi get _photos => _client.storage.from('post-photos');

  @override
  Future<String> createPost(
    String userId,
    PostDraft draft, {
    required GeoPoint devicePosition,
  }) => guard(() async {
    if (!draft.isValid) throw const InvalidInputFailure();

    // A photo in use cannot be overwritten: always a new file name.
    final path = userPhotoPath(
      userId: userId,
      fileName: uniquePhotoFileName(),
      format: draft.format,
    );
    await _photos.uploadBinary(
      path,
      draft.photo,
      fileOptions: FileOptions(contentType: draft.format.mimeType),
    );

    try {
      return await _client.rpc<String>(
        'create_post',
        params: {
          'image_path': path,
          'device_latitude': devicePosition.latitude,
          'device_longitude': devicePosition.longitude,
          'place_latitude': ?draft.place?.latitude,
          'place_longitude': ?draft.place?.longitude,
          'location_precision': draft.precision.code,
          'lifetime_minutes': draft.lifetime.inMinutes,
          'audience': draft.audience.code,
          if (draft.audience == PostAudience.selected)
            'audience_ids': draft.sentAudienceIds,
          'caption': ?draft.trimmedCaption,
        },
      );
    } on Object {
      // Without its post, the photo would wait a day for the cleanup job.
      await _removeQuietly(path);
      rethrow;
    }
  });

  @override
  Future<void> updatePost(
    String postId, {
    PostAudience? audience,
    List<String>? audienceIds,
    Duration? lifetime,
  }) => guard(() async {
    if (lifetime != null && !isValidPostLifetime(lifetime)) {
      throw const InvalidInputFailure();
    }
    await _client.rpc<void>(
      'update_post',
      params: {
        'post_id': postId,
        'audience': ?audience?.code,
        'audience_ids': ?audienceIds?.toSet().toList(),
        'lifetime_minutes': ?lifetime?.inMinutes,
      },
    );
  });

  @override
  Future<void> deletePost(Post post) => guard(() async {
    await _client.from('posts').delete().eq('id', post.id);
    // The photo can only be deleted once no post uses it.
    await _removeQuietly(post.imagePath);
  });

  @override
  Future<List<Post>> fetchOwnPosts(String userId) => guard(() async {
    final rows = await _client
        .from('posts_public')
        .select(_columns)
        .eq('author_id', userId)
        // Most recent first: said explicitly, though the client's default.
        .order('created_at', ascending: false);
    return [for (final row in rows) ?postFromRow(row)];
  });

  @override
  Future<List<Post>> fetchMapFeed(GeoBounds area) => guard(() async {
    if (!isValidMapArea(area)) throw const InvalidInputFailure();
    final (:southWest, :northEast) = area;
    final rows = await _client.rpc<List<dynamic>>(
      'map_feed',
      params: {
        'min_latitude': southWest.latitude,
        'min_longitude': southWest.longitude,
        'max_latitude': northEast.latitude,
        'max_longitude': northEast.longitude,
      },
    );
    // Already sorted by the server, most recent first.
    return [
      for (final row in rows.cast<Map<String, dynamic>>()) ?postFromRow(row),
    ];
  });

  @override
  Future<void> pin(String postId) => guard(() async {
    try {
      await _client.from('pins').insert({'post_id': postId});
    } on PostgrestException catch (error) {
      // unique_violation: already pinned, which is what the user wants.
      if (error.code != '23505') rethrow;
    }
  });

  @override
  Future<void> unpin(String postId) => guard(
    // The policies limit the deletion to the user's own pin.
    () => _client.from('pins').delete().eq('post_id', postId),
  );

  Future<void> _removeQuietly(String path) async {
    try {
      await _photos.remove([path]);
    } on Object {
      // The cleanup job removes post photos that no post uses.
    }
  }
}
