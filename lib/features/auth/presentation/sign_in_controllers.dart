import 'dart:async';

import 'package:evasion/features/auth/data/supabase_auth_repository.dart';
import 'package:evasion/features/auth/domain/auth_validators.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sign_in_controllers.g.dart';

/// Sends the sign-in code. The state is loading during the call, then an
/// error holding an `AppFailure`, or data.
@riverpod
class SendCodeController extends _$SendCodeController {
  @override
  FutureOr<void> build() {}

  /// Returns whether the code was sent.
  Future<bool> sendCode(String email) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).sendCode(normalizeEmail(email)),
    );
    if (!ref.mounted) return false;
    state = result;
    return !result.hasError;
  }
}

/// Checks the sign-in code. On success the session changes, and the router
/// leaves the sign-in screens on its own.
@riverpod
class VerifyCodeController extends _$VerifyCodeController {
  @override
  FutureOr<void> build() {}

  Future<void> verifyCode({required String email, required String code}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .verifyCode(email: normalizeEmail(email), code: code.trim()),
    );
    if (ref.mounted) state = result;
  }
}

@riverpod
class SignOutController extends _$SignOutController {
  @override
  FutureOr<void> build() {}

  Future<void> signOut() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signOut(),
    );
    if (ref.mounted) state = result;
  }
}
