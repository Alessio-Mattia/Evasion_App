import 'package:evasion/core/utils/server_date.dart';
import 'package:evasion/core/validation/profile_validators.dart';
import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/features/profile/domain/profile.dart';
import 'package:evasion/features/profile/presentation/profile_edit/profile_edit_controllers.dart';
import 'package:evasion/features/profile/presentation/profile_edit/profile_edit_dialogs.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The birth date, with a button to use its only correction while it is
/// still available. The server enforces that limit too.
class BirthDateRow extends ConsumerWidget {
  const BirthDateRow({required this.profile, super.key});

  final Profile profile;

  Future<void> _correct(BuildContext context, WidgetRef ref) async {
    final current = profile.birthDate;
    final today = serverToday();
    final earliest = earliestAllowedBirthDate(today);
    final latest = latestAllowedBirthDate(today);
    final picked = await showDatePicker(
      context: context,
      firstDate: earliest,
      lastDate: latest,
      initialDate: current == null || current.isAfter(latest)
          ? latest
          : current.isBefore(earliest)
          ? earliest
          : current,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked == null || DateUtils.isSameDay(picked, current)) return;
    if (!context.mounted ||
        !await confirmBirthDateCorrection(context, picked)) {
      return;
    }
    await ref
        .read(correctBirthDateControllerProvider(profile.id).notifier)
        .correct(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = correctBirthDateControllerProvider(profile.id);
    ref.listen(provider, (_, next) {
      if (next case AsyncError(:final error)) {
        showFailureSnackBar(context, error);
      }
    });
    final isSaving = ref.watch(provider).isLoading;
    final birthDate = profile.birthDate;
    final corrected = profile.birthDateCorrected;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.profileEditBirthDateLabel),
      subtitle: Text(
        [
          if (birthDate != null)
            MaterialLocalizations.of(context).formatFullDate(birthDate),
          if (corrected)
            l10n.profileEditBirthDateLocked
          else
            l10n.profileEditBirthDateHelp,
        ].join('\n'),
      ),
      isThreeLine: birthDate != null,
      trailing: switch ((corrected, isSaving)) {
        (true, _) => null,
        (_, true) => const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(),
        ),
        _ => TextButton(
          onPressed: () => _correct(context, ref),
          child: Text(l10n.profileEditBirthDateCorrect),
        ),
      },
    );
  }
}
