import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/models/geo_point.dart';

/// Whether a post can be placed at [place] while the phone is at [device]:
/// at most `BusinessRules.postChosenLocationMaxDistanceMeters` away, as the
/// server checks too. It keeps anyone from posting in a town they are not in.
///
/// The server measures on the ellipsoid, this on a sphere (up to 0.3 %
/// apart): a 1 % margin keeps a place accepted here from being refused there.
bool isWithinPostRadius(GeoPoint place, GeoPoint device) =>
    distanceMeters(place, device) <=
    BusinessRules.postChosenLocationMaxDistanceMeters * 0.99;
