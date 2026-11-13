import 'dart:typed_data';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/errors/failure_mapper.dart';
import 'package:evasion/core/models/gender.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/core/storage/avatar_upload.dart';
import 'package:evasion/core/supabase/supabase_client_provider.dart';
import 'package:evasion/core/utils/server_date.dart';
import 'package:evasion/features/onboarding/domain/onboarding_progress.dart';
import 'package:evasion/features/onboarding/domain/onboarding_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_onboarding_repository.g.dart';

@Riverpod(keepAlive: true)
OnboardingRepository onboardingRepository(Ref ref) =>
    SupabaseOnboardingRepository(ref.watch(supabaseClientProvider));

class SupabaseOnboardingRepository implements OnboardingRepository {
  SupabaseOnboardingRepository(this._client);

  final SupabaseClient _client;

  String get _userId =>
      _client.auth.currentUser?.id ?? (throw const UnauthenticatedFailure());

  @override
  Future<OnboardingProgress> fetchProgress() => guard(() async {
    final row = await _client
        .from('profiles')
        .select('display_name, birth_date, gender, avatar_path')
        .eq('id', _userId)
        .single();
    return OnboardingProgress(
      hasDisplayName: row['display_name'] != null,
      hasBirthDate: row['birth_date'] != null,
      hasGender: row['gender'] != null,
      hasPhoto: row['avatar_path'] != null,
    );
  });

  @override
  Future<void> saveBasics({
    String? displayName,
    DateTime? birthDate,
    Gender? gender,
  }) => guard(() async {
    final changes = {
      'display_name': ?displayName,
      'birth_date': ?(birthDate == null ? null : toSqlDate(birthDate)),
      'gender': ?gender?.databaseValue,
    };
    if (changes.isEmpty) return;
    // Selecting the row makes an update that matched nothing fail, instead of
    // silently doing nothing.
    await _client
        .from('profiles')
        .update(changes)
        .eq('id', _userId)
        .select('id')
        .single();
  });

  @override
  Future<void> savePhoto(Uint8List bytes, PhotoFormat format) =>
      guard(() => replaceAvatar(_client, _userId, bytes, format));
}
