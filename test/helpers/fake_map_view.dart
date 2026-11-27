import 'package:evasion/core/map/map_view.dart';
import 'package:evasion/core/models/geo_point.dart';
import 'package:flutter/material.dart';

/// Stands in for the native Mapbox map in widget tests: it remembers what the
/// screen asked to show, and lets tests report areas and taps.
class FakeMapView {
  /// Finds the fake map in the widget tree.
  static const key = Key('fake-map');

  /// The last properties the screen built the map with.
  MapViewProps? props;

  MapViewProps get _props => props ?? (throw StateError('No map built yet'));

  List<MapMarker> get markers => _props.markers;

  MapViewBuilder get builder => (props) {
    this.props = props;
    return const ColoredBox(
      key: key,
      color: Colors.transparent,
      child: SizedBox.expand(),
    );
  };

  /// As if the map stopped moving over [area].
  void showArea(GeoBounds area) => _props.onAreaChanged(area);

  void tapMarker(String id) => _props.onMarkerTapped(id);

  void tapEmpty() => _props.onEmptyTapped();
}
