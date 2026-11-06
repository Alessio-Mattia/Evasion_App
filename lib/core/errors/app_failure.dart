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

/// Anything not covered above.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({super.cause, super.stackTrace});
}
