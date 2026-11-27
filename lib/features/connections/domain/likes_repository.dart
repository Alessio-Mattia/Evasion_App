import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/features/connections/domain/like.dart';

/// Whether the server accepts [message] for a like: none, or at most
/// `BusinessRules.likeMessageMaxLength` code points once trimmed.
bool isValidLikeMessage(String? message) =>
    (message?.trim() ?? '').runes.length <= BusinessRules.likeMessageMaxLength;

/// Secret likes between friends, and their matches. Liking is meant to be
/// deliberate: a like is revealed to the friend only by a match, a match
/// notifies both and cannot be erased, and a removed like cannot be given
/// again for `BusinessRules.likeCooldownAfterRemoval`. Every method throws
/// an `AppFailure` on error.
abstract interface class LikesRepository {
  /// Likes [friendId], with an optional [message] revealed only at a match,
  /// and returns whether it makes a match. Liking again before a match
  /// replaces the message.
  ///
  /// Fails with:
  /// - `InvalidInputFailure`, without calling the server, for a message too
  ///   long (see [isValidLikeMessage]);
  /// - `PermissionDeniedFailure` if [friendId] is not a friend;
  /// - `LimitReachedFailure` if the user removed their like to them less
  ///   than `BusinessRules.likeCooldownAfterRemoval` ago.
  Future<bool> likeFriend(String friendId, {String? message});

  /// Removes the user's like to [friendId], before any match: the friend
  /// never learns of it. Fails with `InvalidInputFailure` once matched:
  /// cancel the match instead.
  Future<void> removeLike(String friendId);

  /// Cancels the match with [friendId]: both likes disappear, and the friend
  /// is told the match was cancelled.
  Future<void> cancelMatch(String friendId);

  /// The friends the user liked, still waiting for a like back, the most
  /// recent first.
  Future<List<PendingLike>> fetchPendingLikes();

  /// The user's matches, the most recent first.
  Future<List<MatchedFriend>> fetchMatches();
}
