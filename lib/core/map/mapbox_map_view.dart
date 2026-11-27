import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:evasion/core/map/map_config.dart';
import 'package:evasion/core/map/map_view.dart';
import 'package:evasion/core/models/geo_point.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mapbox_map_view.g.dart';

/// The Mapbox settings, read once from the environment.
@Riverpod(keepAlive: true)
MapConfig mapConfig(Ref ref) => MapConfig.fromEnvironment();

/// The map, drawn by Mapbox with the project's style.
///
/// Markers go in one GeoJSON source and three circle layers: blurred areas,
/// their centres, and precise points. An area keeps its size in metres at
/// every zoom.
class MapboxMapView extends ConsumerStatefulWidget {
  const MapboxMapView({required this.props, super.key});

  final MapViewProps props;

  @override
  ConsumerState<MapboxMapView> createState() => _MapboxMapViewState();
}

class _MapboxMapViewState extends ConsumerState<MapboxMapView> {
  static const _source = 'markers';
  static const _areas = 'marker-areas';
  static const _centres = 'marker-centres';
  static const _points = 'marker-points';

  /// Metres per pixel at zoom 0 on the equator, with Mapbox's 512 px tiles.
  static const _metersPerPixelAtZoom0 = 78271.517;

  MapboxMap? _map;
  bool _styleReady = false;

  /// Waits for the camera to stop before reporting the area. Mapbox's idle
  /// event is not used: an animation, such as the user's position, keeps the
  /// map from ever being idle.
  Timer? _settle;
  static const _settleDelay = Duration(milliseconds: 400);

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  void _onCameraChanged(CameraChangedEventData _) {
    _settle?.cancel();
    _settle = Timer(_settleDelay, () => unawaited(_reportArea()));
  }

  /// The first camera, built once: a new viewport, even an equal one, makes
  /// Mapbox move the camera back there at each rebuild. Later moves go
  /// through [_flyTo].
  late final ViewportState _viewport = _cameraAt(
    _props.focus ?? _props.initialCenter,
    zoom: _props.initialZoom,
  );

  MapViewProps get _props => widget.props;

  static CameraViewportState _cameraAt(GeoPoint point, {double? zoom}) =>
      CameraViewportState(
        center: Point(coordinates: Position(point.longitude, point.latitude)),
        zoom: zoom,
      );

  @override
  void didUpdateWidget(MapboxMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a real change: every update redraws the map, which then reports
    // its area again.
    if (!listEquals(oldWidget.props.markers, _props.markers) ||
        oldWidget.props.selectedId != _props.selectedId) {
      unawaited(_updateMarkers());
    }
    if (oldWidget.props.showUserLocation != _props.showUserLocation) {
      unawaited(_updateUserLocation());
    }
    final focus = _props.focus;
    if (focus != null && focus != oldWidget.props.focus) {
      unawaited(_flyTo(focus));
    }
  }

  /// Moves the camera to [point]; the map then reports its new area.
  Future<void> _flyTo(GeoPoint point) async {
    await _map?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(point.longitude, point.latitude)),
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  Future<void> _updateUserLocation() async {
    await _map?.location.updateSettings(
      LocationComponentSettings(
        enabled: _props.showUserLocation,
        // A pulse redraws the map without end, for no information.
        pulsingEnabled: false,
      ),
    );
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    // A position known before the map was ready.
    if (_props.focus case final focus?) unawaited(_flyTo(focus));
    for (final layer in [_areas, _centres, _points]) {
      map.addInteraction(
        TapInteraction(FeaturesetDescriptor(layerId: layer), (feature, _) {
          final id = feature.properties['id'];
          if (id is String) _props.onMarkerTapped(id);
        }),
        interactionID: 'tap-$layer',
      );
    }
    map.addInteraction(
      TapInteraction.onMap((_) => _props.onEmptyTapped()),
      interactionID: 'tap-map',
    );
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await _updateUserLocation();
  }

  /// A style load removes what the style itself does not hold: the source
  /// and layers are added again each time.
  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null) return;
    _styleReady = false;
    final marker = _props.markerColor.toARGB32();
    final outline = _props.outlineColor.toARGB32();
    final colour = <Object>[
      'case',
      ['get', 'selected'],
      _hex(_props.selectedColor),
      _hex(_props.markerColor),
    ];

    await map.addSource(GeoJsonSource(id: _source, data: _geoJson()));
    await map.addLayer(
      CircleLayer(
        id: _areas,
        sourceId: _source,
        filter: const [
          '==',
          ['get', 'kind'],
          'area',
        ],
        circleRadiusExpression: const [
          'interpolate',
          ['exponential', 2],
          ['zoom'],
          0,
          ['get', 'radius0'],
          22,
          [
            '*',
            ['get', 'radius0'],
            4194304,
          ],
        ],
        circleColorExpression: colour,
        circleOpacity: 0.16,
        circleStrokeColor: marker,
        circleStrokeWidth: 1.5,
        circleStrokeOpacity: 0.7,
      ),
    );
    await map.addLayer(
      CircleLayer(
        id: _centres,
        sourceId: _source,
        filter: const [
          '==',
          ['get', 'kind'],
          'area',
        ],
        circleRadius: 4,
        circleColorExpression: colour,
      ),
    );
    await map.addLayer(
      CircleLayer(
        id: _points,
        sourceId: _source,
        filter: const [
          '==',
          ['get', 'kind'],
          'point',
        ],
        circleRadiusExpression: const [
          'case',
          ['get', 'selected'],
          10,
          7,
        ],
        circleColorExpression: colour,
        circleStrokeColor: outline,
        circleStrokeWidth: 3,
      ),
    );
    _styleReady = true;
    await _reportArea();
  }

  Future<void> _updateMarkers() async {
    final map = _map;
    if (map == null || !_styleReady) return;
    await map.setStyleSourceProperty(_source, 'data', _geoJson());
  }

  Future<void> _reportArea() async {
    final map = _map;
    if (map == null) return;
    final camera = await map.getCameraState();
    final bounds = await map.coordinateBoundsForCamera(
      camera.toCameraOptions(),
    );
    if (!mounted) return;
    final southWest = bounds.southwest.coordinates;
    final northEast = bounds.northeast.coordinates;
    _props.onAreaChanged((
      southWest: (
        latitude: southWest.lat.toDouble(),
        longitude: southWest.lng.toDouble(),
      ),
      northEast: (
        latitude: northEast.lat.toDouble(),
        longitude: northEast.lng.toDouble(),
      ),
    ));
  }

  String _geoJson() => jsonEncode({
    'type': 'FeatureCollection',
    'features': [
      for (final (:id, :position, :shape) in _props.markers)
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [position.longitude, position.latitude],
          },
          'properties': {
            'id': id,
            'selected': id == _props.selectedId,
            ...switch (shape) {
              MapArea(:final radiusMeters) => {
                'kind': 'area',
                // The radius in pixels at zoom 0, doubled at each zoom level.
                'radius0':
                    radiusMeters /
                    (_metersPerPixelAtZoom0 *
                        cos(position.latitude * pi / 180)),
              },
              MapPoint() => {'kind': 'point'},
            },
          },
        },
    ],
  });

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      styleUri: ref.watch(mapConfigProvider).styleUrl,
      viewport: _viewport,
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
      onCameraChangeListener: _onCameraChanged,
    );
  }
}
