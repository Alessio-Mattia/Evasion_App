import 'package:evasion/core/widgets/tab_placeholder.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabPlaceholder(title: AppLocalizations.of(context).tabProfile);
  }
}
