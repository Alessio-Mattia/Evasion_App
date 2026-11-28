import 'package:evasion/features/encounters/domain/crossing_groups.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_encounters_repository.dart';

void main() {
  test('splits today from the earlier crossings, keeping the order', () {
    final now = DateTime(2026, 11, 28, 15);
    final crossings = [
      testCrossing(id: 'a', crossedAt: DateTime(2026, 11, 28, 14, 30)),
      testCrossing(id: 'b', crossedAt: DateTime(2026, 11, 28, 0, 30)),
      testCrossing(id: 'c', crossedAt: DateTime(2026, 11, 27, 23, 30)),
      testCrossing(id: 'd', crossedAt: DateTime(2026, 11, 24, 18)),
    ];

    final (:today, :earlier) = groupCrossingsByDay(crossings, now);

    expect(today.map((crossing) => crossing.id), ['a', 'b']);
    expect(earlier.map((crossing) => crossing.id), ['c', 'd']);
  });

  test('uses the phone time zone, not UTC', () {
    // The server sends UTC; compared in local time like the user sees it.
    final now = DateTime(2026, 11, 28, 10);
    final justAfterMidnight = DateTime(2026, 11, 28, 0, 30).toUtc();

    final (:today, earlier: _) = groupCrossingsByDay([
      testCrossing(crossedAt: justAfterMidnight),
    ], now);

    expect(today, hasLength(1));
  });

  test('nothing to split', () {
    final (:today, :earlier) = groupCrossingsByDay([], DateTime(2026));

    expect(today, isEmpty);
    expect(earlier, isEmpty);
  });
}
