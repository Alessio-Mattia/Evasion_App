import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Counter and error of a text limited to [max] code points, like the server
/// counts them.
InputDecoration limitedTextDecoration(
  BuildContext context, {
  required String label,
  required String text,
  required int max,
}) {
  final l10n = AppLocalizations.of(context);
  final length = text.trim().runes.length;
  return InputDecoration(
    labelText: label,
    alignLabelWithHint: true,
    counterText: l10n.lengthCounter(length, max),
    errorText: length > max ? l10n.pageTextTooLong(max) : null,
  );
}
