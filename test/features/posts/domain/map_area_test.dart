import 'package:evasion/core/models/geo_point.dart';
import 'package:evasion/features/posts/domain/map_area.dart';
import 'package:flutter_test/flutter_test.dart';

GeoBounds area(double minLat, double minLng, double maxLat, double maxLng) => (
  southWest: (latitude: minLat, longitude: minLng),
  northEast: (latitude: maxLat, longitude: maxLng),
);

void main() {
  test('accepts the area around the EPFL', () {
    expect(isValidMapArea(area(46.51, 6.555, 46.53, 6.58)), isTrue);
  });

  test('refuses corners out of order', () {
    expect(isValidMapArea(area(46.53, 6.555, 46.51, 6.58)), isFalse);
    expect(isValidMapArea(area(46.51, 6.58, 46.53, 6.555)), isFalse);
    expect(isValidMapArea(area(46.51, 6.555, 46.51, 6.58)), isFalse);
  });

  // The server, which measures exactly, accepts 46.3–46.74 and 6.3–6.9
  // (about 49 by 46 km) and refuses 0.46 degree of latitude (51 km) or
  // 0.7 of longitude here (54 km): see supabase/tests/database/map_feed.
  test('agrees with the server on its test areas', () {
    expect(isValidMapArea(area(46.3, 6.3, 46.74, 6.9)), isTrue);
    expect(isValidMapArea(area(46.3, 6.3, 46.76, 6.6)), isFalse);
    expect(isValidMapArea(area(46.5, 6.0, 46.6, 6.7)), isFalse);
  });

  test('a degree of longitude is narrower far from the equator', () {
    // 0.6 degree is about 74 km at the equator, 39 km at 60 degrees north.
    expect(isValidMapArea(area(0, 6, 0.1, 6.6)), isFalse);
    expect(isValidMapArea(area(60, 6, 60.1, 6.6)), isTrue);
  });
}
