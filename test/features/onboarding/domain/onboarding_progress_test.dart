import 'package:evasion/features/onboarding/domain/onboarding_progress.dart';
import 'package:evasion/features/onboarding/presentation/onboarding_controllers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OnboardingProgress progress({
    bool name = false,
    bool birthDate = false,
    bool gender = false,
  }) => OnboardingProgress(
    hasDisplayName: name,
    hasBirthDate: birthDate,
    hasGender: gender,
    hasPhoto: false,
  );

  group('stepsFor', () {
    test('a new user sees the introduction and every question', () {
      expect(stepsFor(progress()), OnboardingStep.values);
    });

    test('filled fields are skipped, and so is the introduction', () {
      expect(stepsFor(progress(birthDate: true)), [
        OnboardingStep.displayName,
        OnboardingStep.gender,
        OnboardingStep.photo,
      ]);
    });

    test('with every field filled, only the photo remains', () {
      expect(stepsFor(progress(name: true, birthDate: true, gender: true)), [
        OnboardingStep.photo,
      ]);
    });
  });

  group('savesOnNext', () {
    OnboardingState at(List<OnboardingStep> steps, OnboardingStep step) =>
        OnboardingState(steps: steps, index: steps.indexOf(step));

    test('only the last question saves, before the photo', () {
      final steps = stepsFor(progress());

      expect(at(steps, OnboardingStep.birthDate).savesOnNext, isFalse);
      expect(at(steps, OnboardingStep.gender).savesOnNext, isTrue);
    });

    test('the introduction never saves', () {
      final steps = [OnboardingStep.intro, OnboardingStep.photo];

      expect(at(steps, OnboardingStep.intro).savesOnNext, isFalse);
    });
  });
}
