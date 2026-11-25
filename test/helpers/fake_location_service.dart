import 'package:evasion/core/models/geo_point.dart';
import 'package:evasion/core/services/location_service.dart';

/// Lausanne, a little north of the lake.
const GeoPoint testPosition = (latitude: 46.52, longitude: 6.63);

/// Returns [position] instead of asking the phone. Set [error] to make the
/// next reads fail, for example with `LocationAccessDenied`.
class FakeLocationService implements LocationService {
  GeoPoint position = testPosition;
  Exception? error;
  int reads = 0;
  int settingsOpened = 0;

  @override
  Future<GeoPoint> currentPosition() async {
    reads++;
    if (error case final error?) throw error;
    return position;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}
