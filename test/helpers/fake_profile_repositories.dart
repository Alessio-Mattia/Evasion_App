import 'dart:typed_data';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/models/gender.dart';
import 'package:evasion/features/onboarding/domain/onboarding_progress.dart';
import 'package:evasion/features/onboarding/domain/onboarding_repository.dart';
import 'package:evasion/features/onboarding/domain/profile_photo.dart';
import 'package:evasion/features/profile/domain/profile.dart';
import 'package:evasion/features/profile/domain/profile_repository.dart';

/// Profile with every required field, as after onboarding.
Profile completeProfile(String userId) => Profile(
  id: userId,
  isComplete: true,
  isStudentVerified: false,
  displayName: 'Alex',
  birthDate: DateTime(2000),
  gender: Gender.other,
  avatarPath: '$userId/avatar.jpg',
);

/// Profile right after sign-up.
Profile emptyProfile(String userId) =>
    Profile(id: userId, isComplete: false, isStudentVerified: false);

/// In-memory `profiles` table holding the profile of a single user.
///
/// [isComplete] is recomputed from the fields, as the server does.
class FakeProfileStore implements ProfileRepository, OnboardingRepository {
  FakeProfileStore(this.profile);

  Profile profile;

  /// Set to make the next profile reads fail.
  AppFailure? fetchFailure;

  /// Set to make the next saves fail.
  AppFailure? saveFailure;

  /// Set to make the next onboarding progress reads fail.
  AppFailure? progressFailure;
  int fetchCount = 0;
  final List<Map<String, Object?>> savedChanges = [];
  final List<PhotoFormat> savedPhotoFormats = [];

  @override
  Future<Profile> fetchOwnProfile(String userId) async {
    fetchCount++;
    if (fetchFailure case final failure?) throw failure;
    return profile;
  }

  @override
  Future<OnboardingProgress> fetchProgress() async {
    if (progressFailure case final failure?) throw failure;
    return OnboardingProgress(
      hasDisplayName: profile.displayName != null,
      hasBirthDate: profile.birthDate != null,
      hasGender: profile.gender != null,
      hasPhoto: profile.avatarPath != null,
    );
  }

  @override
  Future<void> saveBasics({
    String? displayName,
    DateTime? birthDate,
    Gender? gender,
  }) async {
    if (saveFailure case final failure?) throw failure;
    savedChanges.add({
      'display_name': ?displayName,
      'birth_date': ?birthDate,
      'gender': ?gender,
    });
    _update(
      profile.copyWith(
        displayName: displayName ?? profile.displayName,
        birthDate: birthDate ?? profile.birthDate,
        gender: gender ?? profile.gender,
      ),
    );
  }

  @override
  Future<void> savePhoto(Uint8List bytes, PhotoFormat format) async {
    if (saveFailure case final failure?) throw failure;
    savedPhotoFormats.add(format);
    _update(
      profile.copyWith(
        avatarPath: avatarPath(
          userId: profile.id,
          fileName: 'photo-${savedPhotoFormats.length}',
          format: format,
        ),
      ),
    );
  }

  void _update(Profile updated) {
    profile = updated.copyWith(
      isComplete:
          updated.displayName != null &&
          updated.birthDate != null &&
          updated.gender != null &&
          updated.avatarPath != null,
    );
  }
}
