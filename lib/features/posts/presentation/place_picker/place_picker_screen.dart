import 'dart:async';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/map/map_view.dart';
import 'package:evasion/core/models/geo_point.dart';
import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/features/posts/domain/post_place.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Picks the place of a post: the user moves the map under a fixed pin, within
/// `BusinessRules.postChosenLocationMaxDistanceMeters` of the phone, drawn as
/// a circle. Pops the place chosen, or nothing.
class PlacePickerScreen extends ConsumerStatefulWidget {
  const PlacePickerScreen({this.initialPlace, super.key});

  /// The place chosen before, if any: the map opens there.
  final GeoPoint? initialPlace;

  @override
  ConsumerState<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends ConsumerState<PlacePickerScreen> {
  GeoPoint? _device;
  bool _locationFailed = false;

  /// The point under the pin.
  GeoPoint? _center;

  @override
  void initState() {
    super.initState();
    unawaited(_locate());
  }

  Future<void> _locate() async {
    try {
      final device = await ref.read(locationServiceProvider).currentPosition();
      if (mounted) setState(() => _device = device);
    } on Exception {
      // Without the phone's position, no place can be checked.
      if (mounted) setState(() => _locationFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final device = _device;
    final center = _center;
    final isWithin =
        device != null && center != null && isWithinPostRadius(center, device);
    const maxKm = BusinessRules.postChosenLocationMaxDistanceMeters ~/ 1000;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.placePickerTitle)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ref.watch(mapViewBuilderProvider)(
            MapViewProps(
              initialCenter:
                  widget.initialPlace ?? BusinessRules.mapDefaultCenter,
              initialZoom: BusinessRules.mapInitialZoom,
              // Without a place chosen before, the phone's position once known.
              focus: widget.initialPlace == null ? device : null,
              showUserLocation: device != null,
              markers: [
                if (device != null)
                  (
                    id: 'allowed-area',
                    position: device,
                    shape: const MapArea(
                      BusinessRules.postChosenLocationMaxDistanceMeters * 1.0,
                    ),
                  ),
              ],
              onAreaChanged: (area) => setState(() => _center = centerOf(area)),
              // Only the circle can be tapped: nothing to do.
              onMarkerTapped: (_) {},
              onEmptyTapped: () {},
              markerColor: colors.primary,
              selectedColor: colors.primary,
              outlineColor: colors.surface,
            ),
          ),
          // The pin's tip on the centre of the map.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 44),
                child: Icon(Icons.place, size: 44, color: colors.secondary),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(switch ((_locationFailed, device, isWithin)) {
                        (true, _, _) => l10n.placePickerNeedsLocation,
                        (_, null, _) => l10n.placePickerHint,
                        (_, _, true) => l10n.placePickerHint,
                        _ => l10n.placePickerTooFar(maxKm),
                      }, textAlign: TextAlign.center),
                    ),
                  ),
                  FilledButton(
                    onPressed: isWithin ? () => context.pop(center) : null,
                    child: Text(l10n.placePickerConfirm),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
