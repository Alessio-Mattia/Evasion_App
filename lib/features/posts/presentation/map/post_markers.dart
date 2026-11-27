import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/map/map_view.dart';
import 'package:evasion/features/posts/domain/post.dart';

/// The markers of [posts]: a blurred post is an area covering its whole
/// cell, never a pin; an exact post is a point.
List<MapMarker> postMarkers(List<Post> posts) => [
  for (final post in posts)
    (
      id: post.id,
      position: (latitude: post.latitude, longitude: post.longitude),
      shape: switch (post.precision) {
        PostPrecision.fuzzy => const MapArea(
          BusinessRules.mapFuzzyAreaRadiusMeters,
        ),
        PostPrecision.exact => const MapPoint(),
      },
    ),
];
