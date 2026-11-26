import 'package:freezed_annotation/freezed_annotation.dart';

part 'friend.freezed.dart';

/// Someone met in person: a friend, or the person who just scanned the
/// user's QR code.
@freezed
abstract class Friend with _$Friend {
  const factory Friend({
    required String userId,
    required String displayName,
    required int age,
    required bool isStudentVerified,

    /// Path in the `avatars` bucket.
    String? avatarPath,

    /// When the two connected; null for the person who just scanned.
    DateTime? friendsSince,
  }) = _Friend;
}

/// Reads a row of `my_friends` or of `connection_token_scan` (whose person is
/// in `friend_id`), or returns null for a row this version of the app cannot
/// show, such as one without a name: an older app then shows one friend less
/// instead of failing.
Friend? friendFromRow(Map<String, dynamic> row) {
  final userId = row['user_id'] ?? row['friend_id'];
  final displayName = row['display_name'];
  final age = row['age'];
  if (userId is! String || displayName is! String || age is! int) return null;
  final friendsSince = row['friends_since'];
  return Friend(
    userId: userId,
    displayName: displayName,
    age: age,
    isStudentVerified: row['is_student_verified'] as bool? ?? false,
    avatarPath: row['avatar_path'] as String?,
    friendsSince: friendsSince is String ? DateTime.parse(friendsSince) : null,
  );
}
