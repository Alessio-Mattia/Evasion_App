import 'dart:async';
import 'dart:io';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Runs a backend call and rethrows any error as an [AppFailure].
///
/// Every repository method wraps its Supabase calls with it, so that no raw
/// exception reaches the controllers.
Future<T> guard<T>(Future<T> Function() body) async {
  try {
    return await body();
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(toAppFailure(error, stackTrace), stackTrace);
  }
}

/// Translates a Supabase, network or unknown error into an [AppFailure].
///
/// The only place that knows Supabase error codes.
AppFailure toAppFailure(Object error, StackTrace stackTrace) {
  return switch (error) {
    AppFailure() => error,
    // Checked before AuthException, of which it is a subtype.
    SocketException() || TimeoutException() || AuthRetryableFetchException() =>
      NetworkFailure(cause: error, stackTrace: stackTrace),
    AuthException() => UnauthenticatedFailure(
      cause: error,
      stackTrace: stackTrace,
    ),
    PostgrestException(:final code) => _fromPostgrestCode(
      code,
      error,
      stackTrace,
    ),
    StorageException(:final statusCode) => _fromHttpStatus(
      statusCode,
      error,
      stackTrace,
    ),
    _ => UnexpectedFailure(cause: error, stackTrace: stackTrace),
  };
}

/// Postgres codes (SQLSTATE) and PostgREST codes (PGRST...).
AppFailure _fromPostgrestCode(
  String? code,
  Object error,
  StackTrace stackTrace,
) {
  return switch (code) {
    // insufficient_privilege: refused by a Row Level Security policy.
    '42501' => PermissionDeniedFailure(cause: error, stackTrace: stackTrace),
    // unique_violation.
    '23505' => ConflictFailure(cause: error, stackTrace: stackTrace),
    // A single row was requested but none was found.
    'PGRST116' => NotFoundFailure(cause: error, stackTrace: stackTrace),
    // Missing, invalid or expired JWT.
    'PGRST301' ||
    'PGRST302' ||
    'PGRST303' => UnauthenticatedFailure(cause: error, stackTrace: stackTrace),
    _ => UnexpectedFailure(cause: error, stackTrace: stackTrace),
  };
}

AppFailure _fromHttpStatus(
  String? statusCode,
  Object error,
  StackTrace stackTrace,
) {
  return switch (statusCode) {
    '401' => UnauthenticatedFailure(cause: error, stackTrace: stackTrace),
    '403' => PermissionDeniedFailure(cause: error, stackTrace: stackTrace),
    '404' => NotFoundFailure(cause: error, stackTrace: stackTrace),
    '409' => ConflictFailure(cause: error, stackTrace: stackTrace),
    _ => UnexpectedFailure(cause: error, stackTrace: stackTrace),
  };
}
