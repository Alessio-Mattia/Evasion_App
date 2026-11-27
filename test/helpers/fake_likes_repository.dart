import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/connections/domain/like.dart';
import 'package:evasion/features/connections/domain/likes_repository.dart';

/// In-memory likes of the signed-in user, for tests of controllers and
/// screens. Like the server, it accepts friends only, refuses to remove a
/// matched like, and keeps a removed like out for
/// `BusinessRules.likeCooldownAfterRemoval`.
class FakeLikesRepository implements LikesRepository {
  FakeLikesRepository({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Ids of the user's friends, by id: their name.
  final Map<String, String> friends = {};

  /// Friends who liked the user: liking them back makes a match. Never shown
  /// to the user, as on the server.
  final Set<String> likedByFriends = {};

  /// The user's likes waiting for a like back, by friend id: the message.
  final Map<String, String?> pending = {};

  /// The user's matches, by friend id.
  final Map<String, MatchedFriend> matches = {};

  /// When the user removed a like, by friend id.
  final Map<String, DateTime> removedAt = {};

  /// Friends told that the user cancelled their match.
  final List<String> cancelledMatchesTold = [];

  /// Set to make the next calls fail.
  AppFailure? failure;

  @override
  Future<bool> likeFriend(String friendId, {String? message}) async {
    _throwIfFailing();
    if (!isValidLikeMessage(message)) throw const InvalidInputFailure();
    final name = friends[friendId];
    if (name == null) throw const PermissionDeniedFailure();
    if (matches.containsKey(friendId)) return true;
    final removed = removedAt[friendId];
    if (removed != null &&
        _now().difference(removed) < BusinessRules.likeCooldownAfterRemoval) {
      throw const LimitReachedFailure();
    }
    final trimmed = message?.trim();
    final kept = trimmed == null || trimmed.isEmpty ? null : trimmed;
    if (!likedByFriends.contains(friendId)) {
      pending[friendId] = kept;
      return false;
    }
    pending.remove(friendId);
    matches[friendId] = MatchedFriend(
      userId: friendId,
      displayName: name,
      age: 23,
      isStudentVerified: false,
      matchedAt: _now(),
      myMessage: kept,
    );
    return true;
  }

  @override
  Future<void> removeLike(String friendId) async {
    _throwIfFailing();
    if (matches.containsKey(friendId)) throw const InvalidInputFailure();
    if (pending.containsKey(friendId)) {
      pending.remove(friendId);
      removedAt[friendId] = _now();
    }
  }

  @override
  Future<void> cancelMatch(String friendId) async {
    _throwIfFailing();
    if (matches.remove(friendId) != null) {
      likedByFriends.remove(friendId);
      cancelledMatchesTold.add(friendId);
    }
  }

  @override
  Future<List<PendingLike>> fetchPendingLikes() async {
    _throwIfFailing();
    return [
      for (final MapEntry(key: id, value: message) in pending.entries)
        PendingLike(
          userId: id,
          displayName: friends[id] ?? '',
          age: 23,
          isStudentVerified: false,
          likedAt: _now(),
          message: message,
        ),
    ];
  }

  @override
  Future<List<MatchedFriend>> fetchMatches() async {
    _throwIfFailing();
    return [...matches.values];
  }

  void _throwIfFailing() {
    if (failure case final failure?) throw failure;
  }
}
