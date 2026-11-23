import 'dart:async';
import 'dart:io';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/errors/failure_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final stackTrace = StackTrace.current;

  AppFailure map(Object error) => toAppFailure(error, stackTrace);

  group('toAppFailure', () {
    test('keeps an AppFailure unchanged', () {
      const failure = NotFoundFailure();

      expect(map(failure), same(failure));
    });

    test('maps network errors to NetworkFailure', () {
      expect(map(const SocketException('offline')), isA<NetworkFailure>());
      expect(map(TimeoutException('slow')), isA<NetworkFailure>());
      expect(
        map(AuthRetryableFetchException(message: 'offline')),
        isA<NetworkFailure>(),
      );
    });

    test('maps session errors to UnauthenticatedFailure', () {
      expect(map(AuthSessionMissingException()), isA<UnauthenticatedFailure>());
      for (final code in [
        'session_expired',
        'session_not_found',
        'session_missing',
        'refresh_token_not_found',
        'refresh_token_already_used',
        'no_authorization',
        'bad_jwt',
      ]) {
        expect(
          map(AuthException('session', statusCode: '401', code: code)),
          isA<UnauthenticatedFailure>(),
          reason: code,
        );
      }
    });

    test('maps other auth errors to UnexpectedFailure, not to a session '
        'error, since they also happen while signing in', () {
      for (final code in [
        'email_address_not_authorized',
        'email_address_invalid',
        'validation_failed',
        'unexpected_failure',
        null,
      ]) {
        expect(
          map(AuthException('error', statusCode: '400', code: code)),
          isA<UnexpectedFailure>(),
          reason: code,
        );
      }
    });

    test('maps a wrong or expired sign-in code to InvalidCodeFailure', () {
      expect(
        map(
          const AuthException(
            'expired',
            statusCode: '403',
            code: 'otp_expired',
          ),
        ),
        isA<InvalidCodeFailure>(),
      );
    });

    test('maps rate limits to TooManyRequestsFailure', () {
      for (final code in [
        'over_email_send_rate_limit',
        'over_request_rate_limit',
      ]) {
        expect(
          map(AuthException('slow down', statusCode: '429', code: code)),
          isA<TooManyRequestsFailure>(),
          reason: code,
        );
      }
      expect(
        map(const AuthException('slow down', statusCode: '429')),
        isA<TooManyRequestsFailure>(),
      );
    });

    group('PostgrestException', () {
      AppFailure mapCode(String? code) =>
          map(PostgrestException(message: 'error', code: code));

      test('42501 is a permission error', () {
        expect(mapCode('42501'), isA<PermissionDeniedFailure>());
      });

      test('23505 is a conflict', () {
        expect(mapCode('23505'), isA<ConflictFailure>());
      });

      test('23514 is a refused value', () {
        expect(mapCode('23514'), isA<InvalidInputFailure>());
      });

      test('54000 is a reached limit', () {
        expect(mapCode('54000'), isA<LimitReachedFailure>());
      });

      test('P0002 is not found', () {
        expect(mapCode('P0002'), isA<NotFoundFailure>());
      });

      test('PGRST116 is not found', () {
        expect(mapCode('PGRST116'), isA<NotFoundFailure>());
      });

      test('JWT errors are unauthenticated', () {
        for (final code in ['PGRST301', 'PGRST302', 'PGRST303']) {
          expect(mapCode(code), isA<UnauthenticatedFailure>(), reason: code);
        }
      });

      test('other codes are unexpected', () {
        expect(mapCode('P0001'), isA<UnexpectedFailure>());
        expect(mapCode(null), isA<UnexpectedFailure>());
      });
    });

    group('StorageException', () {
      AppFailure mapStatus(String? statusCode) =>
          map(StorageException('error', statusCode: statusCode));

      test('maps HTTP statuses', () {
        expect(mapStatus('401'), isA<UnauthenticatedFailure>());
        expect(mapStatus('403'), isA<PermissionDeniedFailure>());
        expect(mapStatus('404'), isA<NotFoundFailure>());
        expect(mapStatus('409'), isA<ConflictFailure>());
        expect(mapStatus('429'), isA<TooManyRequestsFailure>());
        expect(mapStatus('500'), isA<UnexpectedFailure>());
      });
    });

    group('FunctionException', () {
      test('a call that never reached the function is a network failure', () {
        expect(
          map(const FunctionsFetchException(details: 'offline')),
          isA<NetworkFailure>(),
        );
      });

      test('maps HTTP statuses', () {
        AppFailure mapStatus(int status) =>
            map(FunctionException(status: status));

        expect(mapStatus(401), isA<UnauthenticatedFailure>());
        expect(mapStatus(429), isA<TooManyRequestsFailure>());
        expect(mapStatus(500), isA<UnexpectedFailure>());
      });
    });

    test('maps unknown errors to UnexpectedFailure', () {
      expect(map(const FormatException('bad')), isA<UnexpectedFailure>());
    });

    test('keeps the original error and stack trace for logs', () {
      const error = SocketException('offline');

      final failure = map(error);

      expect(failure.cause, same(error));
      expect(failure.stackTrace, same(stackTrace));
    });
  });

  group('guard', () {
    test('returns the result of a successful call', () async {
      expect(await guard(() async => 42), 42);
    });

    test('rethrows errors as AppFailure', () async {
      await expectLater(
        guard<void>(() async => throw const SocketException('offline')),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
