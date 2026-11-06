import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/errors/app_failure_message.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Shows the user-facing message of [error] at the bottom of the screen.
///
/// Controllers store an `AppFailure` in their error state; anything else is
/// shown as an unexpected error.
void showFailureSnackBar(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  final message = error is AppFailure
      ? error.message(l10n)
      : l10n.errorUnexpected;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
