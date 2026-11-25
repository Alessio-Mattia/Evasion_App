import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/models/geo_point.dart';
import 'package:evasion/features/posts/domain/map_area.dart';
import 'package:evasion/features/posts/domain/post.dart';
import 'package:evasion/features/posts/domain/post_draft.dart';
import 'package:evasion/features/posts/domain/posts_repository.dart';

/// In-memory posts of the signed-in user, for tests of controllers and
/// screens. It applies the main rules of the server: valid drafts, the quota
/// of active posts, and pins that ignore repeats.
class FakePostsRepository implements PostsRepository {
  FakePostsRepository({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// The user's posts, in any order.
  final List<Post> posts = [];

  /// Posts of other users the signed-in user can see, shown on the map with
  /// [posts].
  final List<Post> othersPosts = [];

  /// Every area sent to [fetchMapFeed].
  final List<GeoBounds> requestedAreas = [];

  /// Ids of the pinned posts.
  final Set<String> pins = {};

  /// Every draft sent to [createPost], with the phone's position.
  final List<(PostDraft, GeoPoint)> createdDrafts = [];

  /// Set to make the next calls fail.
  AppFailure? failure;

  int _nextId = 1;

  @override
  Future<String> createPost(
    String userId,
    PostDraft draft, {
    required GeoPoint devicePosition,
  }) async {
    _throwIfFailing();
    if (!draft.isValid) throw const InvalidInputFailure();
    final now = _now();
    if (posts.where((post) => post.expiresAt.isAfter(now)).length >=
        BusinessRules.activePostsMax) {
      throw const LimitReachedFailure();
    }
    createdDrafts.add((draft, devicePosition));
    final place = draft.place ?? devicePosition;
    final id = 'post-${_nextId++}';
    final post = Post(
      id: id,
      authorId: userId,
      imagePath: '$userId/$id.${draft.format.extension}',
      latitude: place.latitude,
      longitude: place.longitude,
      precision: draft.precision,
      createdAt: now,
      expiresAt: now.add(draft.lifetime),
      caption: draft.trimmedCaption,
      audience: draft.audience,
    );
    posts.add(post);
    return post.id;
  }

  @override
  Future<void> updatePost(
    String postId, {
    PostAudience? audience,
    List<String>? audienceIds,
    Duration? lifetime,
  }) async {
    _throwIfFailing();
    final index = posts.indexWhere((post) => post.id == postId);
    if (index == -1) throw const NotFoundFailure();
    if (lifetime != null && !isValidPostLifetime(lifetime)) {
      throw const InvalidInputFailure();
    }
    final post = posts[index];
    posts[index] = post.copyWith(
      audience: audience ?? post.audience,
      expiresAt: lifetime == null
          ? post.expiresAt
          : post.createdAt.add(lifetime),
    );
  }

  @override
  Future<void> deletePost(Post post) async {
    _throwIfFailing();
    posts.removeWhere((existing) => existing.id == post.id);
    pins.remove(post.id);
  }

  @override
  Future<List<Post>> fetchOwnPosts(String userId) async {
    _throwIfFailing();
    final now = _now();
    return posts
        .where((post) => post.authorId == userId && post.expiresAt.isAfter(now))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Post>> fetchMapFeed(GeoBounds area) async {
    _throwIfFailing();
    if (!isValidMapArea(area)) throw const InvalidInputFailure();
    requestedAreas.add(area);
    final now = _now();
    final (:southWest, :northEast) = area;
    return [...posts, ...othersPosts]
        .where(
          (post) =>
              post.expiresAt.isAfter(now) &&
              post.latitude >= southWest.latitude &&
              post.latitude <= northEast.latitude &&
              post.longitude >= southWest.longitude &&
              post.longitude <= northEast.longitude,
        )
        .map((post) => post.copyWith(isPinned: pins.contains(post.id)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> pin(String postId) async {
    _throwIfFailing();
    pins.add(postId);
  }

  @override
  Future<void> unpin(String postId) async {
    _throwIfFailing();
    pins.remove(postId);
  }

  void _throwIfFailing() {
    if (failure case final failure?) throw failure;
  }
}
