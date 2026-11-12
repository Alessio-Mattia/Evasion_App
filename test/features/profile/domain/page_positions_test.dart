import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/features/profile/domain/page_positions.dart';
import 'package:flutter_test/flutter_test.dart';

/// Slots `p1`, `p2`... at [positions].
List<PageSlot> slotsAt(List<int> positions) => [
  for (final position in positions) (id: 'p$position', position: position),
];

void main() {
  group('placeNewPage', () {
    test('the first page goes to position 1', () {
      expect(
        placeNewPage([]),
        isA<AppendPage>().having((p) => p.position, 'position', 1),
      );
    });

    test('a new page goes after the last one', () {
      expect(
        placeNewPage(slotsAt([1, 2, 3])),
        isA<AppendPage>().having((p) => p.position, 'position', 4),
      );
    });

    test('a gap in the middle does not matter while the end is free', () {
      expect(
        placeNewPage(slotsAt([1, 3])),
        isA<AppendPage>().having((p) => p.position, 'position', 4),
      );
    });

    test('closes the gaps first when the last position is taken', () {
      final placement = placeNewPage(slotsAt([5, 1, 3]));

      expect(
        placement,
        isA<CompactThenAppend>()
            .having((p) => p.order, 'order', ['p1', 'p3', 'p5'])
            .having((p) => p.position, 'position', 4),
      );
    });

    test('refuses a page beyond the maximum', () {
      expect(
        placeNewPage(
          slotsAt([for (var i = 1; i <= BusinessRules.profilePagesMax; i++) i]),
        ),
        isA<PagesFull>(),
      );
    });
  });

  group('compactedOrder', () {
    test('is null when positions run from 1 without holes', () {
      expect(compactedOrder([]), isNull);
      expect(compactedOrder(slotsAt([2, 1, 3])), isNull);
    });

    test('lists the pages by position when there is a hole', () {
      expect(compactedOrder(slotsAt([3, 1])), ['p1', 'p3']);
      expect(compactedOrder(slotsAt([2, 3])), ['p2', 'p3']);
    });
  });
}
