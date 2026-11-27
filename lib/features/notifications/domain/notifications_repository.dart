import 'package:evasion/features/notifications/domain/app_notification.dart';

/// The in-app notifications of the signed-in user. Every method throws an
/// `AppFailure` on error.
abstract interface class NotificationsRepository {
  /// The latest notifications, the most recent first.
  Future<List<AppNotification>> fetchNotifications();

  /// Marks the notifications of [ids] as read, or all of them when null.
  Future<void> markRead({List<String>? ids});
}
