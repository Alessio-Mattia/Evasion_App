import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/errors/app_failure_message.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// User-facing text of [error]. Controllers store an `AppFailure` in their
/// error state; anything else is shown as an unexpected error.
String failureMessage(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  return error is AppFailure ? error.message(l10n) : l10n.errorUnexpected;
}

/// Shows the user-facing message of [error] at the bottom of the screen.
void showFailureSnackBar(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(failureMessage(context, error))));
}
