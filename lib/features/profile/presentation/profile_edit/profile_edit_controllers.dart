import 'dart:async';
import 'dart:typed_data';

import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/features/profile/data/supabase_profile_repository.dart';
import 'package:evasion/features/profile/domain/profile_details.dart';
import 'package:evasion/features/profile/presentation/own_profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_edit_controllers.g.dart';

/// Saves the texts of the profile of [userId]. The state is loading during
/// the save, then an error holding an `AppFailure`, or data.
@riverpod
class SaveDetailsController extends _$SaveDetailsController {
  @override
  FutureOr<void> build(String userId) {}

  /// Returns whether the details were saved.
  Future<bool> save(ProfileDetails details) => _run(
    ref,
    userId,
    () => ref.read(profileRepositoryProvider).updateDetails(userId, details),
    isRunning: () => state.isLoading,
    setState: (value) => state = value,
  );
}

/// Replaces the profile photo of [userId]. The state is loading during the
/// upload, then an error holding an `AppFailure`, or data.
@riverpod
class ReplaceAvatarController extends _$ReplaceAvatarController {
  @override
  FutureOr<void> build(String userId) {}

  /// Returns whether the photo was replaced.
  Future<bool> replace(Uint8List bytes, PhotoFormat format) => _run(
    ref,
    userId,
    () => ref
        .read(profileRepositoryProvider)
        .replaceAvatar(userId, bytes, format),
    isRunning: () => state.isLoading,
    setState: (value) => state = value,
  );
}

/// Uses the only birth date correction of [userId]. The state is loading
/// during the save, then an error holding an `AppFailure`, or data.
@riverpod
class CorrectBirthDateController extends _$CorrectBirthDateController {
  @override
  FutureOr<void> build(String userId) {}

  /// Returns whether the birth date was corrected.
  Future<bool> correct(DateTime birthDate) => _run(
    ref,
    userId,
    () =>
        ref.read(profileRepositoryProvider).correctBirthDate(userId, birthDate),
    isRunning: () => state.isLoading,
    setState: (value) => state = value,
  );
}

/// Runs [change] once at a time, then reads the profile again, so that the
/// screens show what the server saved.
///
/// The state stays loading until the profile is read again: the edit screen
/// then already shows the new photo or birth date, and cannot send the same
/// change twice.
Future<bool> _run(
  Ref ref,
  String userId,
  Future<void> Function() change, {
  required bool Function() isRunning,
  required void Function(AsyncValue<void>) setState,
}) async {
  if (isRunning()) return false;
  setState(const AsyncLoading());
  final result = await AsyncValue.guard(change);
  if (!ref.mounted) return false;
  // Also after a failure: the profile may have changed meanwhile, for example
  // a birth date already corrected from another phone.
  ref.invalidate(ownProfileProvider(userId));
  try {
    await ref.read(ownProfileProvider(userId).future);
  } on Object {
    // Shown by the screens themselves; the profile loaded before stays.
  }
  if (!ref.mounted) return false;
  setState(result);
  return !result.hasError;
}
