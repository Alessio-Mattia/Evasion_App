import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_progress.freezed.dart';

/// Which required profile fields are already filled.
@freezed
abstract class OnboardingProgress with _$OnboardingProgress {
  const factory OnboardingProgress({
    required bool hasDisplayName,
    required bool hasBirthDate,
    required bool hasGender,
    required bool hasPhoto,
  }) = _OnboardingProgress;
}

enum OnboardingStep { intro, displayName, birthDate, gender, photo }

/// Steps still to do, in order. The introduction only shows to someone who has
/// not started yet, and filled fields are skipped: a saved birth date must not
/// be asked again, since it can only be corrected once.
List<OnboardingStep> stepsFor(OnboardingProgress progress) => [
  if (!progress.hasDisplayName && !progress.hasBirthDate && !progress.hasGender)
    OnboardingStep.intro,
  if (!progress.hasDisplayName) OnboardingStep.displayName,
  if (!progress.hasBirthDate) OnboardingStep.birthDate,
  if (!progress.hasGender) OnboardingStep.gender,
  OnboardingStep.photo,
];
