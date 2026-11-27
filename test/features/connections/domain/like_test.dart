import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/features/connections/domain/like.dart';
import 'package:evasion/features/connections/domain/likes_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads a row of my_likes', () {
    final like = pendingLikeFromRow({
      'user_id': 'user-2',
      'display_name': 'Noah',
      'age': 23,
      'avatar_path': 'user-2/a.jpg',
      'is_student_verified': true,
      'message': 'Un café ?',
      'liked_at': '2026-11-27T14:00:00+00:00',
    })!;

    expect(like.userId, 'user-2');
    expect(like.displayName, 'Noah');
    expect(like.message, 'Un café ?');
    expect(like.likedAt, DateTime.utc(2026, 11, 27, 14));
  });

  test('reads a row of my_matches, with both messages', () {
    final match = matchedFriendFromRow({
      'user_id': 'user-2',
      'display_name': 'Noah',
      'age': 23,
      'avatar_path': null,
      'is_student_verified': false,
      'their_message': 'Avec plaisir',
      'my_message': null,
      'matched_at': '2026-11-27T15:00:00+00:00',
    })!;

    expect(match.theirMessage, 'Avec plaisir');
    expect(match.myMessage, isNull);
    expect(match.matchedAt, DateTime.utc(2026, 11, 27, 15));
  });

  test('skips a row without a name', () {
    expect(
      pendingLikeFromRow({
        'user_id': 'u',
        'display_name': null,
        'age': 20,
        'liked_at': '2026-11-27T14:00:00+00:00',
      }),
      isNull,
    );
    expect(
      matchedFriendFromRow({
        'user_id': 'u',
        'display_name': 'A',
        'age': null,
        'matched_at': '2026-11-27T14:00:00+00:00',
      }),
      isNull,
    );
  });

  group('isValidLikeMessage', () {
    test('accepts no message and a blank one', () {
      expect(isValidLikeMessage(null), isTrue);
      expect(isValidLikeMessage('   '), isTrue);
    });

    test('counts code points, as the server does', () {
      const max = BusinessRules.likeMessageMaxLength;
      expect(isValidLikeMessage('👍' * max), isTrue);
      expect(isValidLikeMessage('👍' * (max + 1)), isFalse);
    });
  });
}
