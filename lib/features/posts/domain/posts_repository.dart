import 'package:evasion/core/models/geo_point.dart';
import 'package:evasion/features/posts/domain/post.dart';
import 'package:evasion/features/posts/domain/post_draft.dart';

/// Creates, changes and reads the signed-in user's posts, and their pins.
/// Every method throws an `AppFailure` on error.
abstract interface class PostsRepository {
  /// Uploads the photo of [draft], then creates the post of [userId], the
  /// signed-in user, and returns its id. If the post cannot be created, the
  /// photo is removed again.
  ///
  /// [devicePosition] is the phone's position: the server only uses it to
  /// check that a chosen place is close enough, and does not keep it.
  ///
  /// Fails with `InvalidInputFailure` if the draft is not valid (see
  /// [PostDraft.problems]) or the place is too far, and with
  /// `LimitReachedFailure` if the user already has the maximum of active
  /// posts.
  Future<String> createPost(
    String userId,
    PostDraft draft, {
    required GeoPoint devicePosition,
  });

  /// Changes who sees the post [postId] and/or how long it lasts, counted
  /// from its creation; null leaves a setting as it is. [audienceIds] lists
  /// the friends of a selected audience. Nothing else can change: delete the
  /// post and post again.
  ///
  /// Fails with `NotFoundFailure` if the post is not the user's, or has
  /// expired or been deleted.
  Future<void> updatePost(
    String postId, {
    PostAudience? audience,
    List<String>? audienceIds,
    Duration? lifetime,
  });

  /// Deletes [post], then its photo. A post already deleted counts as
  /// deleted.
  Future<void> deletePost(Post post);

  /// The live posts of [userId], the signed-in user, the most recent first.
  Future<List<Post>> fetchOwnPosts(String userId);

  /// The posts the signed-in user can see in [area], the most recent first,
  /// with their author's name and photo and whether the user pinned them: at
  /// most `BusinessRules.mapFeedMaxPosts`.
  ///
  /// Fails with `InvalidInputFailure`, without calling the server, if [area]
  /// is not valid (see `isValidMapArea`).
  Future<List<Post>> fetchMapFeed(GeoBounds area);

  /// Pins the post [postId] for the signed-in user. Pinning a post twice
  /// does nothing. Fails with `NotFoundFailure` if the post expired, was
  /// deleted or can no longer be seen.
  Future<void> pin(String postId);

  /// Unpins the post [postId]. Unpinning a post that is not pinned does
  /// nothing.
  Future<void> unpin(String postId);
}
