import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/errors/failure_mapper.dart';
import 'package:evasion/core/supabase/supabase_client_provider.dart';
import 'package:evasion/features/connections/domain/like.dart';
import 'package:evasion/features/connections/domain/likes_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_likes_repository.g.dart';

@Riverpod(keepAlive: true)
LikesRepository likesRepository(Ref ref) =>
    SupabaseLikesRepository(ref.watch(supabaseClientProvider));

class SupabaseLikesRepository implements LikesRepository {
  SupabaseLikesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> likeFriend(String friendId, {String? message}) =>
      guard(() async {
        if (!isValidLikeMessage(message)) throw const InvalidInputFailure();
        final trimmed = message?.trim();
        return _client.rpc<bool>(
          'like_friend',
          params: {
            'friend_id': friendId,
            if (trimmed != null && trimmed.isNotEmpty) 'message': trimmed,
          },
        );
      });

  @override
  Future<void> removeLike(String friendId) => guard(
    () => _client.rpc<void>('remove_like', params: {'friend_id': friendId}),
  );

  @override
  Future<void> cancelMatch(String friendId) => guard(
    () => _client.rpc<void>('cancel_match', params: {'friend_id': friendId}),
  );

  @override
  Future<List<PendingLike>> fetchPendingLikes() => guard(() async {
    final rows = await _client.rpc<List<dynamic>>('my_likes');
    // Already sorted by the server, most recent first.
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        ?pendingLikeFromRow(row),
    ];
  });

  @override
  Future<List<MatchedFriend>> fetchMatches() => guard(() async {
    final rows = await _client.rpc<List<dynamic>>('my_matches');
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        ?matchedFriendFromRow(row),
    ];
  });
}
