import 'package:evasion/core/models/geo_point.dart';
import 'package:evasion/core/services/location_service.dart';

/// Lausanne, a little north of the lake.
const GeoPoint testPosition = (latitude: 46.52, longitude: 6.63);

/// Returns [position] instead of asking the phone. Set [error] to make the
/// next reads fail, for example with `LocationAccessDenied`.
class FakeLocationService implements LocationService {
  GeoPoint position = testPosition;

  /// Precise enough for crossings by default, as a phone outdoors.
  double accuracyMeters = 10;
  Exception? error;
  int reads = 0;
  int settingsOpened = 0;

  @override
  Future<GeoPoint> currentPosition() async => (await currentFix()).position;

  @override
  Future<LocationFix> currentFix() async {
    reads++;
    if (error case final error?) throw error;
    return (position: position, accuracyMeters: accuracyMeters);
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  int preciseLocationAsked = 0;

  @override
  Future<void> askForPreciseLocation() async => preciseLocationAsked++;
}
