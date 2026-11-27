import 'package:evasion/features/notifications/domain/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row([Map<String, dynamic> changes = const {}]) => {
  'id': 'notification-1',
  'kind': 'match',
  'user_id': 'user-2',
  'display_name': 'Noah',
  'avatar_path': 'user-2/a.jpg',
  'created_at': '2026-11-27T14:00:00+00:00',
  'read_at': null,
  ...changes,
};

void main() {
  test('reads a match notification', () {
    final notification = notificationFromRow(row())!;

    expect(notification.kind, NotificationKind.match);
    expect(notification.userId, 'user-2');
    expect(notification.displayName, 'Noah');
    expect(notification.createdAt, DateTime.utc(2026, 11, 27, 14));
    expect(notification.readAt, isNull);
  });

  test('reads a cancelled match, already read', () {
    final notification = notificationFromRow(
      row({'kind': 'match_cancelled', 'read_at': '2026-11-27T15:00:00+00:00'}),
    )!;

    expect(notification.kind, NotificationKind.matchCancelled);
    expect(notification.readAt, DateTime.utc(2026, 11, 27, 15));
  });

  test('skips a kind this app does not know', () {
    expect(notificationFromRow(row({'kind': 'new_message'})), isNull);
  });
}
