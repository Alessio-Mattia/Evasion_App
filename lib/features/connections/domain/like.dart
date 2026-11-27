import 'package:freezed_annotation/freezed_annotation.dart';

part 'like.freezed.dart';

/// A friend the signed-in user liked, who did not like them back yet. Only
/// the user's own likes are ever known: never the ones they received.
@freezed
abstract class PendingLike with _$PendingLike {
  const factory PendingLike({
    required String userId,
    required String displayName,
    required int age,
    required bool isStudentVerified,
    required DateTime likedAt,

    /// Path in the `avatars` bucket.
    String? avatarPath,

    /// The user's message, revealed to the friend only at a match.
    String? message,
  }) = _PendingLike;
}

/// A friend who liked the signed-in user back.
@freezed
abstract class MatchedFriend with _$MatchedFriend {
  const factory MatchedFriend({
    required String userId,
    required String displayName,
    required int age,
    required bool isStudentVerified,
    required DateTime matchedAt,

    /// Path in the `avatars` bucket.
    String? avatarPath,

    /// The friend's message for the user, revealed by the match.
    String? theirMessage,

    /// The user's own message.
    String? myMessage,
  }) = _MatchedFriend;
}

/// Reads a row of `my_likes`, or returns null for one this version of the
/// app cannot show, such as one without a name.
PendingLike? pendingLikeFromRow(Map<String, dynamic> row) {
  final (:userId, :displayName, :age) = _person(row);
  if (userId == null || displayName == null || age == null) return null;
  return PendingLike(
    userId: userId,
    displayName: displayName,
    age: age,
    isStudentVerified: row['is_student_verified'] as bool? ?? false,
    likedAt: DateTime.parse(row['liked_at'] as String),
    avatarPath: row['avatar_path'] as String?,
    message: row['message'] as String?,
  );
}

/// Reads a row of `my_matches`, or returns null for one this version of the
/// app cannot show, such as one without a name.
MatchedFriend? matchedFriendFromRow(Map<String, dynamic> row) {
  final (:userId, :displayName, :age) = _person(row);
  if (userId == null || displayName == null || age == null) return null;
  return MatchedFriend(
    userId: userId,
    displayName: displayName,
    age: age,
    isStudentVerified: row['is_student_verified'] as bool? ?? false,
    matchedAt: DateTime.parse(row['matched_at'] as String),
    avatarPath: row['avatar_path'] as String?,
    theirMessage: row['their_message'] as String?,
    myMessage: row['my_message'] as String?,
  );
}

({String? userId, String? displayName, int? age}) _person(
  Map<String, dynamic> row,
) => (
  userId: row['user_id'] as String?,
  displayName: row['display_name'] as String?,
  age: row['age'] as int?,
);
