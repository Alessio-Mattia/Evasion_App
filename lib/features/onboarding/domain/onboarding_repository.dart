import 'dart:typed_data';

import 'package:evasion/core/models/gender.dart';
import 'package:evasion/features/onboarding/domain/onboarding_progress.dart';
import 'package:evasion/features/onboarding/domain/profile_photo.dart';

/// Fills the required fields of the signed-in user's profile. Every method
/// throws an `AppFailure` on error.
abstract interface class OnboardingRepository {
  Future<OnboardingProgress> fetchProgress();

  /// Saves the given fields in one update; null fields are left unchanged.
  Future<void> saveBasics({
    String? displayName,
    DateTime? birthDate,
    Gender? gender,
  });

  /// Uploads [bytes] as the profile photo, under a new file name, then points
  /// the profile to it and deletes the previous photo, if any.
  Future<void> savePhoto(Uint8List bytes, PhotoFormat format);
}
