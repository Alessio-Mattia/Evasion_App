import 'package:evasion/core/models/geo_point.dart';
import 'package:evasion/features/posts/domain/post_place.dart';
import 'package:flutter_test/flutter_test.dart';

const GeoPoint lausanneStation = (latitude: 46.5167, longitude: 6.6291);
const GeoPoint genevaStation = (latitude: 46.2102, longitude: 6.1426);

/// [meters] north of [from]: a degree of latitude is about 111.2 km.
GeoPoint northOf(GeoPoint from, double meters) =>
    (latitude: from.latitude + meters / 111195, longitude: from.longitude);

void main() {
  group('distanceMeters', () {
    test('Lausanne to Geneva, as the crow flies, is about 51 km', () {
      expect(
        distanceMeters(lausanneStation, genevaStation),
        closeTo(51000, 1000),
      );
    });

    test('is zero for the same point, and the same both ways', () {
      expect(distanceMeters(lausanneStation, lausanneStation), 0);
      expect(
        distanceMeters(genevaStation, lausanneStation),
        distanceMeters(lausanneStation, genevaStation),
      );
    });

    test('a degree of latitude is about 111 km', () {
      expect(
        distanceMeters(lausanneStation, northOf(lausanneStation, 1000)),
        closeTo(1000, 5),
      );
    });
  });

  test('centerOf is the middle of an area', () {
    final center = centerOf((
      southWest: (latitude: 46.50, longitude: 6.60),
      northEast: (latitude: 46.54, longitude: 6.66),
    ));

    expect(center.latitude, closeTo(46.52, 1e-9));
    expect(center.longitude, closeTo(6.63, 1e-9));
  });

  group('isWithinPostRadius', () {
    test('accepts a place 4.9 km away', () {
      expect(
        isWithinPostRadius(northOf(lausanneStation, 4900), lausanneStation),
        isTrue,
      );
    });

    test('refuses a place 5.1 km away', () {
      expect(
        isWithinPostRadius(northOf(lausanneStation, 5100), lausanneStation),
        isFalse,
      );
    });

    test('keeps a margin below the server limit', () {
      // 4,990 m passes the server (5,000 m) but not the app's 1 % margin.
      expect(
        isWithinPostRadius(northOf(lausanneStation, 4990), lausanneStation),
        isFalse,
      );
    });
  });
}
