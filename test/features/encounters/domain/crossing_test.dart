import 'package:evasion/features/encounters/domain/crossing.dart';
import 'package:flutter_test/flutter_test.dart';

/// A row of `my_crossings`, with [changes] applied.
Map<String, dynamic> row([Map<String, dynamic> changes = const {}]) => {
  'id': 'crossing-1',
  'user_id': 'user-2',
  'display_name': 'Noah',
  'age': 23,
  'avatar_path': 'user-2/a.jpg',
  'is_student_verified': true,
  'crossed_at': '2026-11-26T14:00:00+00:00',
  'latitude': 46.5194,
  'longitude': 6.5672,
  ...changes,
};

void main() {
  test('reads a row of my_crossings', () {
    final crossing = crossingFromRow(row())!;

    expect(crossing.id, 'crossing-1');
    expect(crossing.userId, 'user-2');
    expect(crossing.displayName, 'Noah');
    expect(crossing.age, 23);
    expect(crossing.avatarPath, 'user-2/a.jpg');
    expect(crossing.isStudentVerified, isTrue);
    expect(crossing.crossedAt, DateTime.utc(2026, 11, 26, 14));
    expect((crossing.latitude, crossing.longitude), (46.5194, 6.5672));
  });

  test('accepts whole numbers as coordinates, and no photo', () {
    final crossing = crossingFromRow(
      row({'latitude': 46, 'longitude': 6, 'avatar_path': null}),
    )!;

    expect((crossing.latitude, crossing.longitude), (46.0, 6.0));
    expect(crossing.avatarPath, isNull);
  });

  test('skips a row without a name or an age', () {
    expect(crossingFromRow(row({'display_name': null})), isNull);
    expect(crossingFromRow(row({'age': null})), isNull);
  });
}
