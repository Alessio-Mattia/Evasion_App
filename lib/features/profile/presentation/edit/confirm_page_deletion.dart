import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Asks before deleting a page, which cannot be undone. Returns whether the
/// user confirmed.
Future<bool> confirmPageDeletion(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.pageDeleteTitle),
      content: Text(l10n.pageDeleteBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l10n.pageDeleteConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
