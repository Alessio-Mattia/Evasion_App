import 'package:evasion/app/router/app_routes.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Opens the settings, from the profile tab.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: AppLocalizations.of(context).settingsTitle,
      onPressed: () => context.go(AppRoutes.settings),
    );
  }
}
