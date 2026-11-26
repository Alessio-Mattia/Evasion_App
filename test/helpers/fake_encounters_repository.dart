import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/features/encounters/domain/crossing.dart';
import 'package:evasion/features/encounters/domain/encounters_repository.dart';

/// A crossing with [name], for tests of controllers and screens.
Crossing testCrossing({
  String id = 'crossing-1',
  String name = 'Noah',
  DateTime? crossedAt,
}) => Crossing(
  id: id,
  userId: 'user-$id',
  displayName: name,
  age: 23,
  isStudentVerified: true,
  crossedAt: crossedAt ?? DateTime.utc(2026, 11, 26, 14),
  latitude: 46.5191,
  longitude: 6.5668,
);

/// In-memory crossings of the signed-in user, for tests of controllers and
/// screens. Like the server, it ignores a position less precise than
/// `BusinessRules.locationMaxAccuracyMeters`.
class FakeEncountersRepository implements EncountersRepository {
  /// Returned by [fetchCrossings], in this order.
  List<Crossing> crossings = [];

  /// Every position sent to [reportLocation] and kept.
  final List<LocationFix> reports = [];

  /// Set to make the next calls fail, for example with
  /// `PermissionDeniedFailure` for a user who turned invisible.
  AppFailure? failure;

  @override
  Future<bool> reportLocation(LocationFix fix) async {
    if (failure case final failure?) throw failure;
    if (fix.accuracyMeters > BusinessRules.locationMaxAccuracyMeters) {
      return false;
    }
    reports.add(fix);
    return true;
  }

  @override
  Future<List<Crossing>> fetchCrossings() async {
    if (failure case final failure?) throw failure;
    return [...crossings];
  }
}
