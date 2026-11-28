import 'package:evasion/features/encounters/domain/crossing.dart';

/// [crossings] split into those of today and the earlier ones, in the
/// phone's time zone, each keeping its order (the most recent first).
({List<Crossing> today, List<Crossing> earlier}) groupCrossingsByDay(
  List<Crossing> crossings,
  DateTime now,
) {
  bool isToday(Crossing crossing) => isSameLocalDay(crossing.crossedAt, now);

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

/// Whether [time] is on the same day as [now], in the phone's time zone.
bool isSameLocalDay(DateTime time, DateTime now) {
  final local = time.toLocal();
  final localNow = now.toLocal();
  return local.year == localNow.year &&
      local.month == localNow.month &&
      local.day == localNow.day;
}
