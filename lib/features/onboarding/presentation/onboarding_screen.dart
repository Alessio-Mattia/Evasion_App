import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/features/onboarding/domain/onboarding_progress.dart';
import 'package:evasion/features/onboarding/presentation/onboarding_controllers.dart';
import 'package:evasion/features/onboarding/presentation/steps/birth_date_step.dart';
import 'package:evasion/features/onboarding/presentation/steps/display_name_step.dart';
import 'package:evasion/features/onboarding/presentation/steps/gender_step.dart';
import 'package:evasion/features/onboarding/presentation/steps/intro_step.dart';
import 'package:evasion/features/onboarding/presentation/steps/photo_step.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Explains the concept, then asks for the required profile fields.
///
/// The router shows it as long as the profile is incomplete.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({required this.onProfileSaved, super.key});

  /// Called after the answers are saved, so that the app reads the profile
  /// again. Provided by the router, so that this feature does not depend on
  /// the profile feature.
  final VoidCallback onProfileSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(saveOnboardingControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        showFailureSnackBar(context, error);
      }
    });

    return switch (ref.watch(onboardingControllerProvider)) {
      AsyncData(:final value) => _buildStep(value, ref),
      AsyncError(:final error) => _LoadError(
        error: error,
        onRetry: () => ref.invalidate(onboardingControllerProvider),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }

  Widget _buildStep(OnboardingState state, WidgetRef ref) {
    Future<void> onContinue() => _continue(ref);
    return switch (state.step) {
      OnboardingStep.intro => IntroStep(onContinue: onContinue),
      OnboardingStep.displayName => DisplayNameStep(onContinue: onContinue),
      OnboardingStep.birthDate => BirthDateStep(onContinue: onContinue),
      OnboardingStep.gender => GenderStep(onContinue: onContinue),
      OnboardingStep.photo => const PhotoStep(),
    };
  }

  Future<void> _continue(WidgetRef ref) async {
    final state = ref.read(onboardingControllerProvider).requireValue;
    if (state.savesOnNext) {
      if (ref.read(saveOnboardingControllerProvider).isLoading) return;
      final saved = await ref
          .read(saveOnboardingControllerProvider.notifier)
          .save(state);
      if (!saved) return;
      onProfileSaved();
      // Reloading the progress drops the saved questions from the steps, so
      // that going back cannot change the birth date and use its only
      // correction without the user knowing.
      ref.invalidate(onboardingControllerProvider);
      return;
    }
    ref.read(onboardingControllerProvider.notifier).next();
  }
}

/// Shown when the progress could not be loaded. The message is part of the
/// page, so that rebuilding the screen does not show it again.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(failureMessage(context, error), textAlign: TextAlign.center),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}
