import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/features/encounters/domain/crossing.dart';

/// Sends the phone's position for crossing detection, and reads the
/// crossings of the signed-in user. Every method throws an `AppFailure` on
/// error.
abstract interface class EncountersRepository {
  /// Sends [fix] as the signed-in user's latest position; the server then
  /// records the crossings it makes. Returns whether the position was kept:
  /// not when it is less precise than
  /// `BusinessRules.locationMaxAccuracyMeters` (then not even sent), or
  /// comes less than `BusinessRules.locationReportMinInterval` after the
  /// previous one.
  ///
  /// Send it only while the app is open and the user is not invisible: it
  /// fails with `PermissionDeniedFailure` when the user does not share their
  /// location.
  Future<bool> reportLocation(LocationFix fix);

  /// The crossings of the last `BusinessRules.crossingHistory`, the most
  /// recent first. People the user can no longer see, blocked for example,
  /// are left out.
  Future<List<Crossing>> fetchCrossings();
}
