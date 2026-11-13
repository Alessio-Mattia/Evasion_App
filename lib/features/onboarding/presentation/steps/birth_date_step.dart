import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/utils/server_date.dart';
import 'package:evasion/core/validation/profile_validators.dart';
import 'package:evasion/core/widgets/form_page_layout.dart';
import 'package:evasion/features/onboarding/presentation/onboarding_app_bar.dart';
import 'package:evasion/features/onboarding/presentation/onboarding_controllers.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks for the birth date, limited to the allowed ages by the date picker.
class BirthDateStep extends ConsumerWidget {
  const BirthDateStep({required this.onContinue, super.key});

  final Future<void> Function() onContinue;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final today = serverToday();
    final latest = latestAllowedBirthDate(today);
    final picked = await showDatePicker(
      context: context,
      firstDate: earliestAllowedBirthDate(today),
      lastDate: latest,
      initialDate:
          ref.read(onboardingControllerProvider).value?.birthDate ?? latest,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      ref.read(onboardingControllerProvider.notifier).setBirthDate(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final birthDate = ref.watch(
      onboardingControllerProvider.select((s) => s.value?.birthDate),
    );
    final isSaving = ref.watch(saveOnboardingControllerProvider).isLoading;
    final canContinue =
        birthDate != null && isAllowedBirthDate(birthDate, serverToday());

    return FormPageLayout(
      appBar: const OnboardingAppBar(),
      title: l10n.onboardingBirthDateTitle,
      subtitle: l10n.onboardingBirthDateSubtitle(BusinessRules.minimumAge),
      children: [
        if (birthDate != null)
          Text(
            MaterialLocalizations.of(context).formatFullDate(birthDate),
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        OutlinedButton(
          onPressed: () => _pick(context, ref),
          child: Text(
            birthDate == null
                ? l10n.onboardingBirthDateChoose
                : l10n.onboardingBirthDateChange,
          ),
        ),
        Text(l10n.onboardingBirthDateWarning, style: textTheme.bodySmall),
        LoadingButton(
          label: l10n.onboardingContinue,
          isLoading: isSaving,
          onPressed: canContinue ? onContinue : null,
        ),
      ],
    );
  }
}
