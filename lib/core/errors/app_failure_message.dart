import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';

/// User-facing text of a failure, from the translation files.
extension AppFailureMessage on AppFailure {
  String message(AppLocalizations l10n) {
    return switch (this) {
      NetworkFailure() => l10n.errorNetwork,
      UnauthenticatedFailure() => l10n.errorUnauthenticated,
      PermissionDeniedFailure() => l10n.errorPermissionDenied,
      NotFoundFailure() => l10n.errorNotFound,
      ConflictFailure() => l10n.errorConflict,
      InvalidCodeFailure() => l10n.errorInvalidCode,
      LimitReachedFailure() => l10n.errorLimitReached,
      TooManyRequestsFailure() => l10n.errorTooManyRequests,
      InvalidInputFailure() => l10n.errorInvalidInput,
      UnexpectedFailure() => l10n.errorUnexpected,
    };
  }
}
