import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Asks before using the only birth date correction, which makes [birthDate]
/// final. Returns whether the user confirmed.
Future<bool> confirmBirthDateCorrection(
  BuildContext context,
  DateTime birthDate,
) => _confirm(
  context,
  title: (l10n) => l10n.profileEditBirthDateConfirmTitle,
  body: (l10n) => l10n.profileEditBirthDateConfirmBody(
    MaterialLocalizations.of(context).formatFullDate(birthDate),
  ),
  cancel: (l10n) => l10n.cancel,
  confirm: (l10n) => l10n.profileEditBirthDateCorrect,
);

/// Asks before leaving the edit screen with unsaved changes. Returns whether
/// the user chose to leave.
Future<bool> confirmDiscardChanges(BuildContext context) => _confirm(
  context,
  title: (l10n) => l10n.profileEditDiscardTitle,
  body: (l10n) => l10n.profileEditDiscardBody,
  cancel: (l10n) => l10n.profileEditKeepEditing,
  confirm: (l10n) => l10n.profileEditDiscardConfirm,
);

Future<bool> _confirm(
  BuildContext context, {
  required String Function(AppLocalizations) title,
  required String Function(AppLocalizations) body,
  required String Function(AppLocalizations) cancel,
  required String Function(AppLocalizations) confirm,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title(l10n)),
      content: Text(body(l10n)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancel(l10n)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm(l10n)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
