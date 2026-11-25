import 'dart:math';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/models/geo_point.dart';

/// An upper bound of the metres in a degree, of latitude anywhere and of
/// longitude at the equator (the Earth is slightly flattened: from about
/// 110.6 to 111.7 km). The estimates below are thus a little larger than the
/// real distances, so an area this file accepts is never refused by the
/// server.
const double _metersPerDegree = 111700;

/// Whether the map may ask for the posts of [area]: its corners are in
/// order, and it is at most `BusinessRules.mapFeedMaxAreaSideMeters` on each
/// side, as the server requires. Zoomed out further, the map shows no posts.
bool isValidMapArea(GeoBounds area) {
  final (:southWest, :northEast) = area;
  if (southWest.latitude >= northEast.latitude ||
      southWest.longitude >= northEast.longitude) {
    return false;
  }
  final height = (northEast.latitude - southWest.latitude) * _metersPerDegree;
  // The edge closer to the equator is the wider one.
  final widestLatitude = min(
    southWest.latitude.abs(),
    northEast.latitude.abs(),
  );
  final width =
      (northEast.longitude - southWest.longitude) *
      _metersPerDegree *
      cos(widestLatitude * pi / 180);
  return height <= BusinessRules.mapFeedMaxAreaSideMeters &&
      width <= BusinessRules.mapFeedMaxAreaSideMeters;
}
