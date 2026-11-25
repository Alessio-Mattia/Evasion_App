import 'dart:async';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/features/posts/data/supabase_posts_repository.dart';
import 'package:evasion/features/posts/domain/post_draft.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_post_controller.g.dart';

/// Publishes a post of [userId]: reads the phone's position once, then
/// creates the post. The state is loading meanwhile, then data, or an error
/// holding an `AppFailure`, a `LocationAccessDenied`, a
/// `LocationServiceDisabled` or a `TimeoutException`.
@riverpod
class CreatePostController extends _$CreatePostController {
  @override
  FutureOr<void> build(String userId) {}

  /// Returns whether the post was published.
  Future<bool> publish(PostDraft draft) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      // Checked before asking for the position: the app never reads it for
      // nothing.
      if (!draft.isValid) throw const InvalidInputFailure();
      final position = await ref
          .read(locationServiceProvider)
          .currentPosition();
      await ref
          .read(postsRepositoryProvider)
          .createPost(userId, draft, devicePosition: position);
    });
    if (!ref.mounted) return false;
    state = result;
    return !result.hasError;
  }
}
