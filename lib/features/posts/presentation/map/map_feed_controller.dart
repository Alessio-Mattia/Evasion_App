import 'dart:async';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/models/geo_point.dart';
import 'package:evasion/features/posts/data/supabase_posts_repository.dart';
import 'package:evasion/features/posts/domain/map_area.dart';
import 'package:evasion/features/posts/domain/post.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'map_feed_controller.g.dart';

/// The posts of the area shown on the map. [areaTooLarge] when zoomed out
/// too far to ask for posts; [failure] when the last action failed, shown
/// once by the screen.
typedef MapFeed = ({List<Post> posts, bool areaTooLarge, AppFailure? failure});

/// Loads the posts of the visible area each time the map stops moving, and
/// pins them. The posts stay while a new area loads or when a call fails, so
/// that markers neither flash nor vanish.
///
/// Disposed with the map tab, at sign-out: the next account never sees the
/// posts the previous one could see.
@riverpod
class MapFeedController extends _$MapFeedController {
  GeoBounds? _area;

  /// Counts the requests, so that an older answer arriving last is ignored.
  int _request = 0;

  @override
  MapFeed build() => (posts: const [], areaTooLarge: false, failure: null);

  Future<void> showArea(GeoBounds area) async {
    _area = area;
    final request = ++_request;
    if (!isValidMapArea(area)) {
      // Zoomed out too far: no request at all.
      state = (posts: const [], areaTooLarge: true, failure: null);
      return;
    }
    try {
      final posts = await ref.read(postsRepositoryProvider).fetchMapFeed(area);
      if (!ref.mounted || request != _request) return;
      state = (posts: posts, areaTooLarge: false, failure: null);
    } on AppFailure catch (failure) {
      if (!ref.mounted || request != _request) return;
      state = (posts: state.posts, areaTooLarge: false, failure: failure);
    }
  }

  /// Loads the current area again, after a new post for example.
  Future<void> refresh() async {
    if (_area case final area?) await showArea(area);
  }

  /// Pins or unpins [post] for the signed-in user, showing the change at
  /// once. Returns whether it worked; on failure, the post goes back to how
  /// it was, or leaves the map if it no longer exists.
  Future<bool> togglePin(Post post) async {
    final repository = ref.read(postsRepositoryProvider);
    final pinned = !post.isPinned;
    _setPinned(post.id, pinned);
    try {
      await (pinned ? repository.pin(post.id) : repository.unpin(post.id));
      return true;
    } on AppFailure catch (failure) {
      if (!ref.mounted) return false;
      state = (
        posts: [
          for (final other in state.posts)
            if (other.id != post.id)
              other
            // Expired, deleted or no longer visible: it leaves the map.
            else if (failure is! NotFoundFailure)
              post,
        ],
        areaTooLarge: state.areaTooLarge,
        failure: failure,
      );
      return false;
    }
  }

  void _setPinned(String id, bool isPinned) {
    state = (
      posts: [
        for (final post in state.posts)
          post.id == id ? post.copyWith(isPinned: isPinned) : post,
      ],
      areaTooLarge: state.areaTooLarge,
      failure: null,
    );
  }
}
