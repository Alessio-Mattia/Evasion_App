import 'dart:async';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/models/gender.dart';
import 'package:evasion/core/models/location_mode.dart';
import 'package:evasion/features/settings/domain/settings_repository.dart';
import 'package:evasion/features/settings/domain/user_settings.dart';

/// Settings of a new user, as created by the server.
const defaultSettings = UserSettings(
  locationMode: LocationMode.invisible,
  detectionRadiusM: 100,
  prefGenders: Gender.values,
  prefAgeMin: 18,
);

/// In-memory `user_settings` row of the signed-in user.
///
/// Set [saveFailure] to make the next saves fail, or [pendingSave] to keep
/// them running until it completes.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([this.settings = defaultSettings]);

  UserSettings settings;
  AppFailure? saveFailure;
  Completer<void>? pendingSave;
  final List<UserSettings> saved = [];

  @override
  Future<UserSettings> fetchSettings() async => settings;

  @override
  Future<void> saveSettings(UserSettings settings) async {
    await pendingSave?.future;
    if (saveFailure case final failure?) throw failure;
    saved.add(settings);
    this.settings = settings;
  }
}
