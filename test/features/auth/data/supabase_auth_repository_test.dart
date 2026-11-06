import 'dart:async';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/auth/data/supabase_auth_repository.dart';
import 'package:evasion/features/auth/domain/app_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockGoTrueClient extends Mock implements GoTrueClient {}

User _user({String id = 'user-1', String? email = 'alex@epfl.ch'}) => User(
  id: id,
  email: email,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-11-06T00:00:00Z',
);

void main() {
  late _MockGoTrueClient auth;
  late SupabaseAuthRepository repository;

  setUp(() {
    auth = _MockGoTrueClient();
    repository = SupabaseAuthRepository(auth);
  });

  group('currentUser', () {
    test('is null when signed out', () {
      when(() => auth.currentUser).thenReturn(null);

      expect(repository.currentUser, isNull);
    });

    test('exposes the id and email of the session user', () {
      when(() => auth.currentUser).thenReturn(_user());

      expect(
        repository.currentUser,
        const AppUser(id: 'user-1', email: 'alex@epfl.ch'),
      );
    });
  });

  test('authStateChanges follows sign-ins and sign-outs', () async {
    final events = StreamController<AuthState>();
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
    final session = Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: _user(),
    );

    final users = repository.authStateChanges();
    events
      ..add(AuthState(AuthChangeEvent.signedIn, session))
      ..add(const AuthState(AuthChangeEvent.signedOut, null));
    unawaited(events.close());

    expect(await users.toList(), [
      const AppUser(id: 'user-1', email: 'alex@epfl.ch'),
      null,
    ]);
  });

  group('sendCode', () {
    test('asks Supabase for a code, creating the account if needed', () async {
      when(
        () => auth.signInWithOtp(
          email: any(named: 'email'),
          shouldCreateUser: any(named: 'shouldCreateUser'),
        ),
      ).thenAnswer((_) async {});

      await repository.sendCode('alex@epfl.ch');

      verify(
        () => auth.signInWithOtp(email: 'alex@epfl.ch', shouldCreateUser: true),
      ).called(1);
    });

    test('turns a rate limit into TooManyRequestsFailure', () async {
      when(
        () => auth.signInWithOtp(
          email: any(named: 'email'),
          shouldCreateUser: any(named: 'shouldCreateUser'),
        ),
      ).thenThrow(
        const AuthException(
          'Too many emails',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
      );

      await expectLater(
        repository.sendCode('alex@epfl.ch'),
        throwsA(isA<TooManyRequestsFailure>()),
      );
    });
  });

  group('verifyCode', () {
    test('checks the code as an email code', () async {
      when(
        () => auth.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: OtpType.email,
        ),
      ).thenAnswer((_) async => AuthResponse());

      await repository.verifyCode(email: 'alex@epfl.ch', code: '123456');

      verify(
        () => auth.verifyOTP(
          email: 'alex@epfl.ch',
          token: '123456',
          type: OtpType.email,
        ),
      ).called(1);
    });

    test('turns a wrong or expired code into InvalidCodeFailure', () async {
      when(
        () => auth.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: OtpType.email,
        ),
      ).thenThrow(
        const AuthException(
          'Token has expired or is invalid',
          statusCode: '403',
          code: 'otp_expired',
        ),
      );

      await expectLater(
        repository.verifyCode(email: 'alex@epfl.ch', code: '000000'),
        throwsA(isA<InvalidCodeFailure>()),
      );
    });
  });

  test('signOut signs out of Supabase', () async {
    when(() => auth.signOut()).thenAnswer((_) async {});

    await repository.signOut();

    verify(() => auth.signOut()).called(1);
  });
}
