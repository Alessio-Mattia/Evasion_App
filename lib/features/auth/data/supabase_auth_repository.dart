import 'package:evasion/core/errors/failure_mapper.dart';
import 'package:evasion/core/supabase/supabase_client_provider.dart';
import 'package:evasion/features/auth/domain/app_user.dart';
import 'package:evasion/features/auth/domain/auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_auth_repository.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    SupabaseAuthRepository(ref.watch(supabaseClientProvider).auth);

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final GoTrueClient _auth;

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

  AppUser? _toAppUser(User? user) =>
      user == null ? null : AppUser(id: user.id, email: user.email);
}
