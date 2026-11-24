/// Error type that reaches controllers and screens, instead of raw exceptions.
///
/// Repositories throw it (see `guard`), controllers catch it with
/// `AsyncValue.guard`, and screens turn it into a message with
/// `AppFailureMessage.message`. The hierarchy is sealed so that every
/// `switch` on a failure handles all cases.
sealed class AppFailure implements Exception {
  const AppFailure({this.cause, this.stackTrace});

  /// Original error, kept for logs only: never shown to the user.
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType(cause: $cause)';
}

/// No connection, or the server did not answer in time.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.cause, super.stackTrace});
}

/// No valid session: the user must sign in again.
final class UnauthenticatedFailure extends AppFailure {
  const UnauthenticatedFailure({super.cause, super.stackTrace});
}

/// Refused by the server, usually by a Row Level Security policy.
final class PermissionDeniedFailure extends AppFailure {
  const PermissionDeniedFailure({super.cause, super.stackTrace});
}

/// The requested item does not exist, or no longer exists.
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({super.cause, super.stackTrace});
}

/// The item already exists, for example a like sent twice.
final class ConflictFailure extends AppFailure {
  const ConflictFailure({super.cause, super.stackTrace});
}

/// The verification code sent by email is wrong or expired.
final class InvalidCodeFailure extends AppFailure {
  const InvalidCodeFailure({super.cause, super.stackTrace});
}

/// A sensitive action, such as deleting the account, needs a code entered a
/// few minutes ago at most: the user must ask for a new one.
final class ReauthenticationRequiredFailure extends AppFailure {
  const ReauthenticationRequiredFailure({super.cause, super.stackTrace});
}

/// A maximum set by the product rules is reached, for example the number of
/// profile pages.
final class LimitReachedFailure extends AppFailure {
  const LimitReachedFailure({super.cause, super.stackTrace});
}

/// Too many attempts in a short time: the server asks to wait.
final class TooManyRequestsFailure extends AppFailure {
  const TooManyRequestsFailure({super.cause, super.stackTrace});
}

/// The server refused a value, for example a birth date under the minimum age.
///
/// The app checks values before sending them: this only shows when a rule was
/// missed on the app side.
final class InvalidInputFailure extends AppFailure {
  const InvalidInputFailure({super.cause, super.stackTrace});
}

/// Anything not covered above.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({super.cause, super.stackTrace});
}
