import 'dart:math';

/// A position on Earth, in degrees: latitude from -90 to 90, longitude from
/// -180 to 180.
///
/// Shared by the features that place things on the map, such as posts, and
/// by the location service that will give the phone's position.
typedef GeoPoint = ({double latitude, double longitude});

/// A rectangle on the map, such as the area shown on screen: its south-west
/// and north-east corners.
typedef GeoBounds = ({GeoPoint southWest, GeoPoint northEast});

/// Mean radius of the Earth, in metres.
const double _earthRadiusMeters = 6371008.8;

/// Distance between [a] and [b] along the Earth's surface, in metres, by the
/// haversine formula: accurate to a few metres at the distances of the app.
double distanceMeters(GeoPoint a, GeoPoint b) {
  double radians(double degrees) => degrees * pi / 180;
  final latitudeA = radians(a.latitude);
  final latitudeB = radians(b.latitude);
  final halfLatitude = radians(b.latitude - a.latitude) / 2;
  final halfLongitude = radians(b.longitude - a.longitude) / 2;
  final h =
      sin(halfLatitude) * sin(halfLatitude) +
      cos(latitudeA) * cos(latitudeB) * sin(halfLongitude) * sin(halfLongitude);
  return 2 * _earthRadiusMeters * asin(sqrt(min(1, h)));
}

/// The centre of [bounds], such as the point under the middle of the map.
GeoPoint centerOf(GeoBounds bounds) => (
  latitude: (bounds.southWest.latitude + bounds.northEast.latitude) / 2,
  longitude: (bounds.southWest.longitude + bounds.northEast.longitude) / 2,
);
