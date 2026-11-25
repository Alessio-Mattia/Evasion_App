import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/errors/failure_mapper.dart';
import 'package:evasion/core/supabase/supabase_client_provider.dart';
import 'package:evasion/features/auth/domain/app_user.dart';
import 'package:evasion/features/auth/domain/auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_auth_repository.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(client.auth, client.functions);
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth, this._functions);

  final GoTrueClient _auth;
  final FunctionsClient _functions;

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() => _auth.onAuthStateChange
      .map((state) => _toAppUser(state.session?.user))
      .handleError(
        (Object error, StackTrace stackTrace) => Error.throwWithStackTrace(
          toAppFailure(error, stackTrace),
          stackTrace,
        ),
      );

  @override
  Future<void> sendCode(String email) =>
      guard(() => _auth.signInWithOtp(email: email, shouldCreateUser: true));

  @override
  Future<void> verifyCode({required String email, required String code}) =>
      guard(() async {
        await _auth.verifyOTP(email: email, token: code, type: OtpType.email);
      });

  @override
  Future<void> signOut() => guard(_auth.signOut);

  @override
  Future<void> sendReauthenticationCode() => guard(() async {
    final email = _auth.currentUser?.email;
    if (email == null) throw const UnauthenticatedFailure();
    await _auth.signInWithOtp(email: email, shouldCreateUser: false);
  });

  @override
  Future<void> deleteAccount() => guard(() async {
    // The function checks the code entry itself, in the session token.
    await _functions.invoke('delete-account');
    try {
      // The account no longer exists on the server: only this phone's
      // session is left to forget.
      await _auth.signOut();
    } on Object {
      // Deleted anyway; the session expires on its own.
    }
  });

  AppUser? _toAppUser(User? user) =>
      user == null ? null : AppUser(id: user.id, email: user.email);
}
