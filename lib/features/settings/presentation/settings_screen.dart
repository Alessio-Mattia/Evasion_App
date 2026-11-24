import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/features/settings/presentation/sections/age_section.dart';
import 'package:evasion/features/settings/presentation/sections/genders_section.dart';
import 'package:evasion/features/settings/presentation/sections/radius_section.dart';
import 'package:evasion/features/settings/presentation/sections/visibility_section.dart';
import 'package:evasion/features/settings/presentation/settings_controller.dart';
import 'package:evasion/features/settings/presentation/settings_section.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Visibility, encounter criteria and account. Every change is saved at once.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({
    required this.signOutButton,
    required this.deleteAccountButton,
    super.key,
  });

  /// Provided by the router, so that this feature does not depend on auth.
  final Widget signOutButton;
  final Widget deleteAccountButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: switch (ref.watch(settingsControllerProvider)) {
        AsyncValue(:final value?) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            VisibilitySection(settings: value),
            const Divider(),
            RadiusSection(settings: value),
            const Divider(),
            GendersSection(settings: value),
            const Divider(),
            AgeSection(settings: value),
            const Divider(),
            SettingsSection(
              title: l10n.settingsAccountTitle,
              children: [signOutButton, deleteAccountButton],
            ),
          ],
        ),
        AsyncValue(:final error?) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Text(failureMessage(context, error), textAlign: TextAlign.center),
              FilledButton(
                onPressed: () => ref.invalidate(settingsControllerProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
