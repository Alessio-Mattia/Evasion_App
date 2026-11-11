import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/errors/failure_mapper.dart';
import 'package:evasion/core/supabase/supabase_client_provider.dart';
import 'package:evasion/features/settings/domain/settings_repository.dart';
import 'package:evasion/features/settings/domain/user_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_settings_repository.g.dart';

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SupabaseSettingsRepository(ref.watch(supabaseClientProvider));

class SupabaseSettingsRepository implements SettingsRepository {
  SupabaseSettingsRepository(this._client);

  final SupabaseClient _client;

  String get _userId =>
      _client.auth.currentUser?.id ?? (throw const UnauthenticatedFailure());

  @override
  Future<UserSettings> fetchSettings() => guard(() async {
    final row = await _client
        .from('user_settings')
        .select(
          'location_mode, detection_radius_m, pref_genders, pref_age_min, '
          'pref_age_max',
        )
        .eq('user_id', _userId)
        .single();
    return UserSettings.fromJson(row);
  });

  @override
  Future<void> saveSettings(UserSettings settings) => guard(() async {
    // Selecting the row makes an update that matched nothing fail, instead of
    // silently doing nothing.
    await _client
        .from('user_settings')
        .update({
          'location_mode': settings.locationMode.databaseValue,
          'detection_radius_m': settings.detectionRadiusM,
          'pref_genders': [
            for (final gender in settings.prefGenders) gender.databaseValue,
          ],
          'pref_age_min': settings.prefAgeMin,
          'pref_age_max': settings.prefAgeMax,
        })
        .eq('user_id', _userId)
        .select('user_id')
        .single();
  });
}
