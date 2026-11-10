import 'package:evasion/core/widgets/tab_placeholder.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({this.signOutButton, super.key});

  /// Provided by the router, so that this feature does not depend on auth.
  final Widget? signOutButton;

  @override
  Widget build(BuildContext context) {
    return TabPlaceholder(
      title: AppLocalizations.of(context).tabProfile,
      action: signOutButton,
    );
  }
}
