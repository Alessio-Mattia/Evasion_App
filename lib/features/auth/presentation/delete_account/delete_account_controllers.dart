import 'dart:async';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/auth/data/supabase_auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_account_controllers.g.dart';

/// Sends the code that confirms the account deletion. The state is loading
/// during the call, then an error holding an `AppFailure`, or data.
@riverpod
class SendDeletionCodeController extends _$SendDeletionCodeController {
  @override
  FutureOr<void> build() {}

  /// Returns whether the code was sent.
  Future<bool> send() async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).sendReauthenticationCode(),
    );
    if (!ref.mounted) return false;
    state = result;
    return !result.hasError;
  }
}

/// Checks the code, then deletes the account. The state is loading during
/// the calls, then an error holding an `AppFailure`, or data.
///
/// Once the code is accepted, a new attempt (after a network failure, for
/// example) deletes again without checking it: a code works only once. When
/// the server says the code is too old, the next attempt needs a new one.
@riverpod
class DeleteAccountController extends _$DeleteAccountController {
  bool _codeAccepted = false;

  @override
  FutureOr<void> build() {}

  /// Returns whether the account was deleted. The user is then signed out,
  /// and the router leaves the screen.
  Future<bool> delete(String code) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final repository = ref.read(authRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      if (!_codeAccepted) {
        final email = repository.currentUser?.email;
        if (email == null) throw const UnauthenticatedFailure();
        await repository.verifyCode(email: email, code: code.trim());
        _codeAccepted = true;
      }
      try {
        await repository.deleteAccount();
      } on ReauthenticationRequiredFailure {
        _codeAccepted = false;
        rethrow;
      }
    });
    // Signing out closes the screen, which may dispose this controller.
    if (ref.mounted) state = result;
    return !result.hasError;
  }
}
