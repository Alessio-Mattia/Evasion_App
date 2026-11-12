import 'package:evasion/core/config/business_rules.dart';

/// Where a page sits in the carousel, whatever its type. Pages this version of
/// the app cannot show still take a position, so positions are computed from
/// slots, never from the pages shown.
typedef PageSlot = ({String id, int position});

/// How to add a page at the end of the carousel.
sealed class NewPagePlacement {
  const NewPagePlacement();
}

/// Already [BusinessRules.profilePagesMax] pages.
final class PagesFull extends NewPagePlacement {
  const PagesFull();
}

final class AppendPage extends NewPagePlacement {
  const AppendPage(this.position);

  final int position;
}

/// A gap left by a deletion fills the last position: close the gaps with
/// [order] first, then add the page at [position].
final class CompactThenAppend extends NewPagePlacement {
  const CompactThenAppend({required this.order, required this.position});

  final List<String> order;
  final int position;
}

NewPagePlacement placeNewPage(List<PageSlot> slots) {
  if (slots.length >= BusinessRules.profilePagesMax) return const PagesFull();
  final last = slots.fold(
    0,
    (max, slot) => slot.position > max ? slot.position : max,
  );
  if (last < BusinessRules.profilePagesMax) return AppendPage(last + 1);
  return CompactThenAppend(
    order: _sortedIds(slots),
    position: slots.length + 1,
  );
}

/// The order that closes the gaps between positions, or null when there are
/// none: positions then run from 1 without holes.
List<String>? compactedOrder(List<PageSlot> slots) {
  final sorted = [...slots]..sort((a, b) => a.position.compareTo(b.position));
  for (final (index, slot) in sorted.indexed) {
    if (slot.position != index + 1) return [for (final slot in sorted) slot.id];
  }
  return null;
}

/// The full order to send after the user moved the pages shown into
/// [shownOrder]. Pages this version of the app cannot show are not in it, yet
/// the server needs every page: they keep their order, after the others.
List<String> reorderedIds(List<String> shownOrder, List<PageSlot> slots) => [
  ...shownOrder,
  for (final id in _sortedIds(slots))
    if (!shownOrder.contains(id)) id,
];

List<String> _sortedIds(List<PageSlot> slots) => [
  for (final slot in [
    ...slots,
  ]..sort((a, b) => a.position.compareTo(b.position)))
    slot.id,
];
