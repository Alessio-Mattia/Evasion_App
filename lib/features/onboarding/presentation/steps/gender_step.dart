import 'package:evasion/core/models/gender.dart';
import 'package:evasion/core/widgets/form_page_layout.dart';
import 'package:evasion/features/onboarding/presentation/onboarding_app_bar.dart';
import 'package:evasion/features/onboarding/presentation/onboarding_controllers.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GenderStep extends ConsumerWidget {
  const GenderStep({required this.onContinue, super.key});

  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final gender = ref.watch(
      onboardingControllerProvider.select((s) => s.value?.gender),
    );
    final isSaving = ref.watch(saveOnboardingControllerProvider).isLoading;

    return FormPageLayout(
      appBar: const OnboardingAppBar(),
      title: l10n.onboardingGenderTitle,
      subtitle: l10n.onboardingGenderSubtitle,
      children: [
        SegmentedButton<Gender>(
          segments: [
            for (final option in Gender.values)
              ButtonSegment(value: option, label: Text(option.label(l10n))),
          ],
          selected: {?gender},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (selection) => ref
              .read(onboardingControllerProvider.notifier)
              .setGender(selection.single),
        ),
        LoadingButton(
          label: l10n.onboardingContinue,
          isLoading: isSaving,
          onPressed: gender == null ? null : onContinue,
        ),
      ],
    );
  }
}
