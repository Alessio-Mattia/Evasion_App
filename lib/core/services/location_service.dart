import 'package:evasion/core/models/geo_point.dart';
import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_service.g.dart';

/// The user refused access to their position, possibly for good: then only
/// the phone's settings can grant it again ([LocationService.openSettings]).
class LocationAccessDenied implements Exception {
  const LocationAccessDenied({required this.permanently});

  final bool permanently;
}

/// Location is turned off on the phone.
class LocationServiceDisabled implements Exception {
  const LocationServiceDisabled();
}

/// A position read from the phone, with how precise it is: the radius, in
/// metres, within which the phone is likely to be.
typedef LocationFix = ({GeoPoint position, double accuracyMeters});

/// The phone's position, read once, while the app is open: never in the
/// background, and never stored by the app.
abstract interface class LocationService {
  /// Asks for the permission the first time, then reads the position. Throws
  /// [LocationServiceDisabled] or [LocationAccessDenied], and a
  /// `TimeoutException` when no position comes in time.
  Future<GeoPoint> currentPosition();

  /// The same as [currentPosition], with the accuracy of the position, which
  /// crossings need: a position too imprecise, such as an approximate one
  /// the user chose in the phone settings, creates no crossing.
  Future<LocationFix> currentFix();

  /// Opens the app's page of the phone settings, where a permission refused
  /// for good can be granted again.
  Future<void> openSettings();
}

@Riverpod(keepAlive: true)
LocationService locationService(Ref ref) => DeviceLocationService();

/// Uses the phone's location services, through geolocator.
class DeviceLocationService implements LocationService {
  /// Long enough for a first fix outdoors, short enough not to leave the
  /// user waiting.
  static const _timeLimit = Duration(seconds: 15);

  @override
  Future<GeoPoint> currentPosition() async => (await currentFix()).position;

  @override
  Future<LocationFix> currentFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceDisabled();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
        throw const LocationAccessDenied(permanently: false);
      case LocationPermission.deniedForever:
        throw const LocationAccessDenied(permanently: true);
      case LocationPermission.whileInUse ||
          LocationPermission.always ||
          LocationPermission.unableToDetermine:
        break;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(timeLimit: _timeLimit),
    );
    return (
      position: (latitude: position.latitude, longitude: position.longitude),
      accuracyMeters: position.accuracy,
    );
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();
}
