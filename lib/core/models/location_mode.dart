import 'package:json_annotation/json_annotation.dart';

/// How a user shares their position for encounters.
///
/// The JSON values match the `location_mode` enum in SQL. A position is never
/// shown precisely to others, whatever the mode.
enum LocationMode {
  /// No position is used: nobody is encountered.
  @JsonValue('invisible')
  invisible,

  /// The position is used while the app is open.
  @JsonValue('foreground')
  foreground,

  /// The position is also used in the background. Planned after the MVP.
  @JsonValue('background')
  background;

  /// Value stored in the database.
  String get databaseValue => name;
}
