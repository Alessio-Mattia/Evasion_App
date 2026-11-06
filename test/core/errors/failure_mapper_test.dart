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

    test('maps auth errors to UnauthenticatedFailure', () {
      expect(map(AuthSessionMissingException()), isA<UnauthenticatedFailure>());
      expect(
        map(const AuthException('invalid', statusCode: '400')),
        isA<UnauthenticatedFailure>(),
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
        expect(mapStatus('500'), isA<UnexpectedFailure>());
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
