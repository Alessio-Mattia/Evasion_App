import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/settings/data/supabase_settings_repository.dart';
import 'package:evasion/features/settings/domain/user_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_controller.g.dart';

/// The settings shown on screen. Each change is shown at once, saved, and
/// undone if saving fails, so that the screen always matches the server.
@riverpod
class SettingsController extends _$SettingsController {
  /// Last settings the server confirmed: where a failed change goes back to.
  late UserSettings _confirmed;

  @override
  Future<UserSettings> build() async {
    _confirmed = await ref.watch(settingsRepositoryProvider).fetchSettings();
    return _confirmed;
  }

  /// Applies [change] and saves it. Returns the failure if saving failed.
  Future<AppFailure?> change(
    UserSettings Function(UserSettings current) change,
  ) async {
    final current = state.value;
    if (current == null) return null;
    final next = change(current);
    if (next == current) return null;

    state = AsyncData(next);
    try {
      await ref.read(settingsRepositoryProvider).saveSettings(next);
      _confirmed = next;
      return null;
    } on AppFailure catch (failure) {
      // Back to what the server holds, not to the state before this change:
      // that state may hold an earlier change that failed too. If a newer
      // change replaced this one, its own outcome decides what is shown.
      if (ref.mounted && state.value == next) state = AsyncData(_confirmed);
      return failure;
    }
  }
}
