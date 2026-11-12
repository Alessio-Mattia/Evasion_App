import 'dart:async';
import 'dart:typed_data';

import 'package:evasion/core/models/gender.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/features/onboarding/data/supabase_onboarding_repository.dart';
import 'package:evasion/features/onboarding/domain/onboarding_progress.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_controllers.freezed.dart';
part 'onboarding_controllers.g.dart';

/// Where the user is in the onboarding, and the answers not saved yet.
@freezed
abstract class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    required List<OnboardingStep> steps,
    @Default(0) int index,
    String? displayName,
    DateTime? birthDate,
    Gender? gender,
  }) = _OnboardingState;

  const OnboardingState._();

  OnboardingStep get step => steps[index];

  /// The answers are saved together when leaving the last question, so that
  /// going back and changing the birth date does not use its only correction.
  bool get savesOnNext =>
      step != OnboardingStep.intro &&
      index + 1 < steps.length &&
      steps[index + 1] == OnboardingStep.photo;
}

@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  Future<OnboardingState> build() async {
    final progress = await ref
        .watch(onboardingRepositoryProvider)
        .fetchProgress();
    return OnboardingState(steps: stepsFor(progress));
  }

  void setDisplayName(String value) =>
      _update((s) => s.copyWith(displayName: value.trim()));

  void setBirthDate(DateTime value) =>
      _update((s) => s.copyWith(birthDate: value));

  void setGender(Gender value) => _update((s) => s.copyWith(gender: value));

  void next() => _update(
    (s) => s.index + 1 < s.steps.length ? s.copyWith(index: s.index + 1) : s,
  );

  void back() =>
      _update((s) => s.index > 0 ? s.copyWith(index: s.index - 1) : s);

  void _update(OnboardingState Function(OnboardingState) change) {
    if (state case AsyncData(:final value)) state = AsyncData(change(value));
  }
}

/// Saves the answers. The state is loading during the call, then an error
/// holding an `AppFailure`, or data.
@riverpod
class SaveOnboardingController extends _$SaveOnboardingController {
  @override
  FutureOr<void> build() {}

  /// Returns whether the answers were saved.
  Future<bool> save(OnboardingState answers) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(onboardingRepositoryProvider)
          .saveBasics(
            displayName: answers.displayName,
            birthDate: answers.birthDate,
            gender: answers.gender,
          ),
    );
    if (!ref.mounted) return false;
    state = result;
    return !result.hasError;
  }
}

/// Uploads the profile photo. The state is loading during the upload, then an
/// error holding an `AppFailure`, or data.
@riverpod
class SavePhotoController extends _$SavePhotoController {
  @override
  FutureOr<void> build() {}

  /// Returns whether the photo was saved.
  Future<bool> save(Uint8List bytes, PhotoFormat format) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(onboardingRepositoryProvider).savePhoto(bytes, format),
    );
    if (!ref.mounted) return false;
    state = result;
    return !result.hasError;
  }
}
