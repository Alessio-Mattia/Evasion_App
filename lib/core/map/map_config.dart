import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Mapbox settings of the current environment, from `env/<environment>.json`
/// through `--dart-define-from-file`.
class MapConfig {
  /// Throws a [StateError] when the token is missing or is a secret one,
  /// which must never ship in the app.
  factory MapConfig({required String accessToken, required String styleUrl}) {
    if (accessToken.isEmpty) {
      throw StateError(
        'MAPBOX_ACCESS_TOKEN is required: '
        'run with --dart-define-from-file=env/<environment>.json.',
      );
    }
    if (!accessToken.startsWith('pk.')) {
      throw StateError(
        'MAPBOX_ACCESS_TOKEN must be a public token (pk.), never a secret '
        'one.',
      );
    }
    return MapConfig._(
      accessToken,
      // The Mapbox dark style until the project's own style is set.
      styleUrl.isEmpty ? MapboxStyles.DARK : styleUrl,
    );
  }

  /// Reads the values injected at build time by `--dart-define-from-file`.
  factory MapConfig.fromEnvironment() => MapConfig(
    accessToken: const String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
    styleUrl: const String.fromEnvironment('MAPBOX_STYLE_URL'),
  );

  const MapConfig._(this.accessToken, this.styleUrl);

  final String accessToken;

  /// Edited in Mapbox Studio: a published change shows at the next launch,
  /// without changing the app.
  final String styleUrl;

  /// Gives the token to Mapbox, once, before any map is shown.
  void apply() => MapboxOptions.setAccessToken(accessToken);
}
