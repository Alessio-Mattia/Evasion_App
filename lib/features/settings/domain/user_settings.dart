import 'package:evasion/core/models/gender.dart';
import 'package:evasion/core/models/location_mode.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_settings.freezed.dart';
part 'user_settings.g.dart';

/// The signed-in user's settings, as stored in `user_settings`: visibility
/// and encounter criteria.
@freezed
abstract class UserSettings with _$UserSettings {
  const factory UserSettings({
    required LocationMode locationMode,
    required int detectionRadiusM,
    required List<Gender> prefGenders,
    required int prefAgeMin,

    /// Null means no maximum age.
    int? prefAgeMax,
  }) = _UserSettings;

  factory UserSettings.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsFromJson(json);
}
