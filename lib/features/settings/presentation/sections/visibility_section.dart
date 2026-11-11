import 'dart:async';

import 'package:evasion/core/models/location_mode.dart';
import 'package:evasion/features/settings/domain/user_settings.dart';
import 'package:evasion/features/settings/presentation/settings_section.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How the position is shared. Background sharing is planned after the MVP.
class VisibilitySection extends ConsumerWidget {
  const VisibilitySection({required this.settings, super.key});

  final UserSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsVisibilityTitle,
      children: [
        RadioGroup<LocationMode>(
          groupValue: settings.locationMode,
          onChanged: (mode) {
            if (mode == null) return;
            unawaited(
              changeSettings(
                context,
                ref,
                (current) => current.copyWith(locationMode: mode),
              ),
            );
          },
          child: Column(
            children: [
              RadioListTile(
                value: LocationMode.invisible,
                title: Text(l10n.settingsVisibilityInvisible),
                subtitle: Text(l10n.settingsVisibilityInvisibleHint),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile(
                value: LocationMode.foreground,
                title: Text(l10n.settingsVisibilityForeground),
                subtitle: Text(l10n.settingsVisibilityForegroundHint),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile(
                value: LocationMode.background,
                enabled: false,
                title: Text(l10n.settingsVisibilityBackground),
                subtitle: Text(l10n.settingsVisibilityBackgroundHint),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        Text(
          l10n.settingsVisibilityPrivacy,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
