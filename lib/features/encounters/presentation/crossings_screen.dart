import 'package:evasion/core/widgets/tab_placeholder.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// The crossings tab, until the crossings screen comes.
class CrossingsScreen extends StatelessWidget {
  const CrossingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabPlaceholder(title: AppLocalizations.of(context).tabCrossings);
  }
}
