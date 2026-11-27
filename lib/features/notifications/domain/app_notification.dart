import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_notification.freezed.dart';

/// What a notification is about.
enum NotificationKind {
  /// The user and [AppNotification.userId] liked each other.
  match('match'),

  /// [AppNotification.userId] cancelled their match with the user.
  matchCancelled('match_cancelled');

  const NotificationKind(this.code);

  /// Value in the database.
  final String code;

  static NotificationKind? fromCode(Object? code) {
    for (final kind in values) {
      if (kind.code == code) return kind;
    }
    return null;
  }
}

/// Something that happened to the signed-in user, kept by the server: a
/// match notification stays even if the match is cancelled.
@freezed
abstract class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    required NotificationKind kind,

    /// The other person concerned.
    required String userId,
    required String displayName,
    required DateTime createdAt,

    /// Path in the `avatars` bucket.
    String? avatarPath,

    /// Null while unread.
    DateTime? readAt,
  }) = _AppNotification;
}

/// Reads a row of `my_notifications`, or returns null for one this version
/// of the app cannot show, such as a kind added later.
AppNotification? notificationFromRow(Map<String, dynamic> row) {
  final kind = NotificationKind.fromCode(row['kind']);
  final displayName = row['display_name'];
  if (kind == null || displayName is! String) return null;
  final readAt = row['read_at'];
  return AppNotification(
    id: row['id'] as String,
    kind: kind,
    userId: row['user_id'] as String,
    displayName: displayName,
    createdAt: DateTime.parse(row['created_at'] as String),
    avatarPath: row['avatar_path'] as String?,
    readAt: readAt is String ? DateTime.parse(readAt) : null,
  );
}
