import 'dart:async';

import 'package:evasion/core/models/gender.dart';
import 'package:evasion/features/settings/domain/settings_rules.dart';
import 'package:evasion/features/settings/domain/user_settings.dart';
import 'package:evasion/features/settings/presentation/settings_section.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Genders of the people to encounter; at least one stays selected.
class GendersSection extends ConsumerWidget {
  const GendersSection({required this.settings, super.key});

  final UserSettings settings;

  void _toggle(BuildContext context, WidgetRef ref, Gender gender) {
    final genders = toggleGender(settings.prefGenders, gender);
    if (genders == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).settingsGendersAtLeastOne,
            ),
          ),
        );
      return;
    }
    unawaited(
      changeSettings(
        context,
        ref,
        (current) => current.copyWith(prefGenders: genders),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsGendersTitle,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final gender in Gender.values)
              FilterChip(
                label: Text(gender.label(l10n)),
                selected: settings.prefGenders.contains(gender),
                onSelected: (_) => _toggle(context, ref, gender),
              ),
          ],
        ),
      ],
    );
  }
}
