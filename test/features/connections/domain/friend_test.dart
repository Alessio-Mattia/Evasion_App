import 'package:evasion/features/connections/domain/friend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads a row of my_friends', () {
    final friend = friendFromRow({
      'user_id': 'user-2',
      'display_name': 'Noah',
      'age': 23,
      'avatar_path': 'user-2/a.jpg',
      'is_student_verified': true,
      'friends_since': '2026-11-26T14:00:00+00:00',
    })!;

    expect(friend.userId, 'user-2');
    expect(friend.displayName, 'Noah');
    expect(friend.age, 23);
    expect(friend.avatarPath, 'user-2/a.jpg');
    expect(friend.isStudentVerified, isTrue);
    expect(friend.friendsSince, DateTime.utc(2026, 11, 26, 14));
  });

  test('reads a row of connection_token_scan, without a date', () {
    final friend = friendFromRow({
      'friend_id': 'user-3',
      'display_name': 'Léa',
      'age': 21,
      'avatar_path': null,
      'is_student_verified': false,
    })!;

    expect(friend.userId, 'user-3');
    expect(friend.friendsSince, isNull);
    expect(friend.avatarPath, isNull);
  });

  test('skips a row without a name or an age', () {
    expect(
      friendFromRow({'user_id': 'u', 'display_name': null, 'age': 20}),
      isNull,
    );
    expect(
      friendFromRow({'user_id': 'u', 'display_name': 'A', 'age': null}),
      isNull,
    );
  });
}
