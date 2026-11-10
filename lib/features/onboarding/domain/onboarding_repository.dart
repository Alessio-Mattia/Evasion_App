import 'package:evasion/core/models/gender.dart';
import 'package:evasion/features/onboarding/domain/onboarding_progress.dart';

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
}
