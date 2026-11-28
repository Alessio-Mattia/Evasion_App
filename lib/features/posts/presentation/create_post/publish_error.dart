import 'dart:async';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Shows why a post could not be published. A location refused for good
/// offers the phone settings, through [onOpenSettings].
void showPublishError(
  BuildContext context,
  Object error, {
  required bool placeChosen,
  required VoidCallback onOpenSettings,
}) {
  final l10n = AppLocalizations.of(context);
  final (message, canOpenSettings) = switch (error) {
    LocationAccessDenied(permanently: true) => (
      l10n.locationDeniedForever,
      true,
    ),
    LocationAccessDenied() => (l10n.locationDenied, false),
    LocationServiceDisabled() => (l10n.locationDisabled, false),
    TimeoutException() => (l10n.locationTimeout, false),
    // The server refuses a chosen place too far from the phone.
    InvalidInputFailure() when placeChosen => (
      l10n.createPostPlaceTooFar(
        BusinessRules.postChosenLocationMaxDistanceMeters ~/ 1000,
      ),
      false,
    ),
    _ => (failureMessage(context, error), false),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: canOpenSettings
            ? SnackBarAction(
                label: l10n.locationOpenSettings,
                onPressed: onOpenSettings,
              )
            : null,
      ),
    );
}
