import 'package:evasion/core/map/mapbox_map_view.dart';
import 'package:evasion/core/models/geo_point.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'map_view.g.dart';

/// How a marker is drawn on the map.
sealed class MapMarkerShape {
  const MapMarkerShape();
}

/// A blurred area of [radiusMeters] around the marker: the place is only
/// known roughly. Never drawn as a pin.
final class MapArea extends MapMarkerShape {
  const MapArea(this.radiusMeters);

  final double radiusMeters;
}

/// A precise point.
final class MapPoint extends MapMarkerShape {
  const MapPoint();
}

/// Something shown on the map, such as a post.
typedef MapMarker = ({String id, GeoPoint position, MapMarkerShape shape});

/// What a map shows and what it reports. Colours come from the theme, so
/// that the map follows it.
class MapViewProps {
  const MapViewProps({
    required this.initialCenter,
    required this.initialZoom,
    required this.markers,
    required this.onAreaChanged,
    required this.onMarkerTapped,
    required this.onEmptyTapped,
    required this.markerColor,
    required this.selectedColor,
    required this.outlineColor,
    this.selectedId,
    this.focus,
    this.showUserLocation = false,
  });

  final GeoPoint initialCenter;
  final double initialZoom;
  final List<MapMarker> markers;
  final String? selectedId;

  /// Where to move the camera when it changes, such as the phone's position
  /// once known.
  final GeoPoint? focus;

  /// Whether to show the user's own position, to them only.
  final bool showUserLocation;

  /// The visible area, each time the map stops moving.
  final ValueChanged<GeoBounds> onAreaChanged;
  final ValueChanged<String> onMarkerTapped;

  /// A tap beside every marker.
  final VoidCallback onEmptyTapped;

  final Color markerColor;
  final Color selectedColor;
  final Color outlineColor;
}

/// Builds the map widget. The Mapbox map is native, so widget tests replace
/// it with a fake that reports areas and taps on demand.
typedef MapViewBuilder = Widget Function(MapViewProps props);

@Riverpod(keepAlive: true)
MapViewBuilder mapViewBuilder(Ref ref) =>
    (props) => MapboxMapView(props: props);
