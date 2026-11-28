import 'package:evasion/features/encounters/domain/crossing.dart';

/// [crossings] split into those of today and the earlier ones, in the
/// phone's time zone, each keeping its order (the most recent first).
({List<Crossing> today, List<Crossing> earlier}) groupCrossingsByDay(
  List<Crossing> crossings,
  DateTime now,
) {
  final localNow = now.toLocal();
  bool isToday(Crossing crossing) {
    final local = crossing.crossedAt.toLocal();
    return local.year == localNow.year &&
        local.month == localNow.month &&
        local.day == localNow.day;
  }

  return (
    today: [
      for (final crossing in crossings)
        if (isToday(crossing)) crossing,
    ],
    earlier: [
      for (final crossing in crossings)
        if (!isToday(crossing)) crossing,
    ],
  );
}
