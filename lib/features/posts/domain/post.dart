import 'package:freezed_annotation/freezed_annotation.dart';

part 'post.freezed.dart';

/// How precisely a post shows its place, chosen by its author.
enum PostPrecision {
  /// At the centre of a grid cell of about
  /// `BusinessRules.postFuzzyCellSizeMeters`: draw an area, never a pin.
  fuzzy('fuzzy'),

  /// At its exact point.
  exact('exact');

  const PostPrecision(this.code);

  /// Value in the database.
  final String code;

  static PostPrecision? fromCode(Object? code) {
    for (final precision in values) {
      if (precision.code == code) return precision;
    }
    return null;
  }
}

/// Who can see a post, chosen by its author.
enum PostAudience {
  everyone('everyone'),
  friends('friends'),

  /// A list of friends picked by the author.
  selected('selected');

  const PostAudience(this.code);

  /// Value in the database.
  final String code;

  static PostAudience? fromCode(Object? code) {
    for (final audience in values) {
      if (audience.code == code) return audience;
    }
    return null;
  }
}

/// A post as other users may see it: never its exact place when it is fuzzy,
/// only the displayed one.
@freezed
abstract class Post with _$Post {
  const factory Post({
    required String id,
    required String authorId,

    /// Path in the `post-photos` bucket.
    required String imagePath,

    /// The displayed position: the exact point, or the centre of the cell of
    /// a fuzzy post.
    required double latitude,
    required double longitude,
    required PostPrecision precision,
    required DateTime createdAt,
    required DateTime expiresAt,
    String? caption,

    /// Known to the author; null when the server does not send it.
    PostAudience? audience,

    /// Sent with the posts of the map only.
    String? authorName,
    String? authorAvatarPath,
    @Default(false) bool isPinned,
  }) = _Post;
}

/// Reads a row of `posts_public` or of `map_feed`, or returns null for a post
/// this version of the app cannot show, such as a precision added later: an
/// older app then shows one post less instead of failing.
Post? postFromRow(Map<String, dynamic> row) {
  final precision = PostPrecision.fromCode(row['location_precision']);
  if (precision == null) return null;
  return Post(
    id: row['id'] as String,
    authorId: row['author_id'] as String,
    imagePath: row['image_path'] as String,
    latitude: (row['latitude'] as num).toDouble(),
    longitude: (row['longitude'] as num).toDouble(),
    precision: precision,
    createdAt: DateTime.parse(row['created_at'] as String),
    expiresAt: DateTime.parse(row['expires_at'] as String),
    caption: row['caption'] as String?,
    audience: PostAudience.fromCode(row['audience']),
    authorName: row['author_name'] as String?,
    authorAvatarPath: row['author_avatar_path'] as String?,
    isPinned: row['is_pinned'] as bool? ?? false,
  );
}
