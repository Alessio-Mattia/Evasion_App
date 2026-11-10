import 'package:evasion/features/auth/domain/app_user.dart';

/// Signs users in and out with a code sent by email.
///
/// The same flow signs in an existing user and creates a new account. Every
/// method throws an `AppFailure` on error.
abstract interface class AuthRepository {
  /// The signed-in user, restored from the saved session at startup.
  AppUser? get currentUser;

  /// Emits the user on every sign-in, and null on every sign-out.
  Stream<AppUser?> authStateChanges();

  /// Sends a sign-in code to [email], creating the account if needed.
  Future<void> sendCode(String email);

  /// Checks the [code] received by [email] and signs the user in.
  Future<void> verifyCode({required String email, required String code});

  Future<void> signOut();
}
