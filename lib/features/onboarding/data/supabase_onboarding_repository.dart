import 'dart:math';
import 'dart:typed_data';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/errors/failure_mapper.dart';
import 'package:evasion/core/models/gender.dart';
import 'package:evasion/core/supabase/supabase_client_provider.dart';
import 'package:evasion/features/onboarding/domain/onboarding_progress.dart';
import 'package:evasion/features/onboarding/domain/onboarding_repository.dart';
import 'package:evasion/features/onboarding/domain/profile_photo.dart';
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
      'birth_date': ?_toSqlDate(birthDate),
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
      guard(() async {
        final userId = _userId;
        final row = await _client
            .from('profiles')
            .select('avatar_path')
            .eq('id', userId)
            .single();
        final previousPath = row['avatar_path'] as String?;

        // The current photo cannot be overwritten: always a new file name.
        final path = avatarPath(
          userId: userId,
          fileName: _uniqueFileName(),
          format: format,
        );
        await _avatars.uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: format.mimeType),
        );
        await _client
            .from('profiles')
            .update({'avatar_path': path})
            .eq('id', userId)
            .select('id')
            .single();

        if (previousPath != null) {
          try {
            await _avatars.remove([previousPath]);
          } on Object {
            // The new photo is saved: a leftover file stays in the user's
            // private folder until the account is deleted, which is harmless.
          }
        }
      });

  StorageFileApi get _avatars => _client.storage.from('avatars');

  static final _random = Random();

  static String _uniqueFileName() =>
      '${DateTime.now().millisecondsSinceEpoch}-${_random.nextInt(1 << 32)}';

  static String? _toSqlDate(DateTime? date) => date == null
      ? null
      : '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
}
