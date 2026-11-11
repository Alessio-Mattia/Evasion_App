import 'package:evasion/core/widgets/tab_placeholder.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({this.settingsButton, super.key});

  /// Provided by the router, so that this feature does not depend on
  /// settings.
  final Widget? settingsButton;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(actions: [?settingsButton]),
      body: TabPlaceholder(title: l10n.tabProfile),
    );
  }
}
