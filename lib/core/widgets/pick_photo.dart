import 'dart:typed_data';

import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/core/services/photo_picker.dart';
import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets the user take or choose a photo, crops it to [shape], and checks that
/// the server will accept it.
///
/// Returns the photo, or null when the user cancelled or the photo cannot be
/// used; the reason is then shown at the bottom of the screen.
Future<Uint8List?> pickCheckedPhoto(
  BuildContext context,
  WidgetRef ref, {
  required PhotoSource source,
  required PhotoShape shape,
  required String cropTitle,
}) async {
  final l10n = AppLocalizations.of(context);
  final colors = Theme.of(context).colorScheme;
  void showMessage(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  final Uint8List? picked;
  try {
    picked = await ref
        .read(photoPickerProvider)
        .pickPhoto(
          source,
          shape,
          CropAppearance(
            title: cropTitle,
            toolbarColor: colors.surface,
            toolbarForeground: colors.onSurface,
            backgroundColor: colors.surface,
            accentColor: colors.primary,
          ),
        );
  } on PhotoAccessDenied {
    if (context.mounted) showMessage(l10n.photoAccessDenied);
    return null;
  } on Object catch (error) {
    if (context.mounted) showFailureSnackBar(context, error);
    return null;
  }
  if (picked == null || !context.mounted) return null;

  switch (checkPhoto(picked)) {
    case PhotoProblem.unsupportedFormat:
      showMessage(l10n.photoUnsupportedFormat);
      return null;
    case PhotoProblem.tooLarge:
      showMessage(l10n.photoTooLarge);
      return null;
    case null:
      return picked;
  }
}
