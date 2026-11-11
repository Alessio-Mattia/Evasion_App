import 'package:evasion/features/settings/domain/user_settings.dart';

/// Reads and saves the signed-in user's settings. Every method throws an
/// `AppFailure` on error.
abstract interface class SettingsRepository {
  Future<UserSettings> fetchSettings();

  /// Saves every editable setting at once, so that the server always holds
  /// the state shown on screen.
  Future<void> saveSettings(UserSettings settings);
}
