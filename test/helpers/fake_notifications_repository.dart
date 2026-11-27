import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/notifications/domain/app_notification.dart';
import 'package:evasion/features/notifications/domain/notifications_repository.dart';

/// A notification about [name], for tests of controllers and screens.
AppNotification testNotification({
  String id = 'notification-1',
  NotificationKind kind = NotificationKind.match,
  String name = 'Noah',
  DateTime? readAt,
}) => AppNotification(
  id: id,
  kind: kind,
  userId: 'user-$id',
  displayName: name,
  createdAt: DateTime.utc(2026, 11, 27, 14),
  readAt: readAt,
);

/// In-memory notifications of the signed-in user, for tests of controllers
/// and screens.
class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Returned by [fetchNotifications], in this order.
  List<AppNotification> notifications = [];

  /// Set to make the next calls fail.
  AppFailure? failure;

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    if (failure case final failure?) throw failure;
    return [...notifications];
  }

  @override
  Future<void> markRead({List<String>? ids}) async {
    if (failure case final failure?) throw failure;
    notifications = [
      for (final notification in notifications)
        notification.readAt == null &&
                (ids == null || ids.contains(notification.id))
            ? notification.copyWith(readAt: _now())
            : notification,
    ];
  }
}
